require 'leaderboard'

class TieRankingLeaderboard < Leaderboard
  # Default options when creating a leaderboard. Page size is 25 and reverse
  # is set to false, meaning various methods will return results in
  # highest-to-lowest order.
  DEFAULT_OPTIONS = {
    :page_size => DEFAULT_PAGE_SIZE,
    :reverse => false,
    :member_key => :member,
    :rank_key => :rank,
    :score_key => :score,
    :member_data_key => :member_data,
    :member_data_namespace => 'member_data',
    :ties_namespace => 'ties'
  }

  # Create a new instance of a leaderboard.
  #
  # @param leaderboard [String] Name of the leaderboard.
  # @param options [Hash] Options for the leaderboard such as +:page_size+.
  # @param redis_options [Hash] Options for configuring Redis.
  #
  # Examples
  #
  #   leaderboard = Leaderboard.new('highscores')
  #   leaderboard = Leaderboard.new('highscores', {:page_size => 10})
  def initialize(leaderboard_name, options = DEFAULT_OPTIONS, redis_options = DEFAULT_REDIS_OPTIONS)
    super

    leaderboard_options = DEFAULT_OPTIONS.dup
    leaderboard_options.merge!(options)

    @ties_namespace = leaderboard_options[:ties_namespace]
  end

  # Delete the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  def delete_leaderboard_named(leaderboard_name)
    @redis_connection.multi do |transaction|
      transaction.del(leaderboard_name)
      transaction.del(member_data_key(leaderboard_name))
      transaction.del(ties_leaderboard_key(leaderboard_name))
    end
  end

  # Change the score for a member in the named leaderboard by a delta which can be positive or negative.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param delta [float] Score change.
  # @param member_data [String] Optional member data.
  def change_score_for_member_in(leaderboard_name, member, delta, member_data = nil)
    previous_score = score_for(member)
    new_score = (previous_score || 0) + delta

    total_members_at_previous_score = @redis_connection.zrevrangebyscore(leaderboard_name, previous_score, previous_score)

    @redis_connection.multi do |transaction|
      transaction.zadd(leaderboard_name, new_score, member)
      transaction.zadd(ties_leaderboard_key(leaderboard_name), new_score, new_score.to_f.to_s)
      transaction.hset(member_data_key(leaderboard_name), member, member_data) if member_data
    end

    if total_members_at_previous_score.length == 1
      @redis_connection.zrem(ties_leaderboard_key(leaderboard_name), previous_score.to_f.to_s)
    end
  end

  # Rank a member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param score [float] Member score.
  # @param member_data [String] Optional member data.
  def rank_member_in(leaderboard_name, member, score, member_data = nil)
    member_score = @redis_connection.zscore(leaderboard_name, member) || nil
    can_delete_score = member_score &&
      members_from_score_range_in(leaderboard_name, member_score, member_score).length == 1 &&
      member_score != score

    @redis_connection.multi do |transaction|
      transaction.zadd(leaderboard_name, score, member)
      transaction.zadd(ties_leaderboard_key(leaderboard_name), score, score.to_f.to_s)
      transaction.zrem(ties_leaderboard_key(leaderboard_name), member_score.to_f.to_s) if can_delete_score
      transaction.hset(member_data_key(leaderboard_name), member, member_data) if member_data
    end
  end

  # Rank a member across multiple leaderboards.
  #
  # @param leaderboards [Array] Leaderboard names.
  # @param member [String] Member name.
  # @param score [float] Member score.
  # @param member_data [String] Optional member data.
  def rank_member_across(leaderboards, member, score, member_data = nil)
    leaderboards.each do |leaderboard_name|
      rank_member_in(leaderboard_name, member, score, member_data)
    end
  end

  # Rank an array of members in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param members_and_scores [Splat or Array] Variable list of members and scores
  def rank_members_in(leaderboard_name, *members_and_scores)
    if members_and_scores.is_a?(Array)
      members_and_scores.flatten!
    end

    members_and_scores.each_slice(2) do |member_and_score|
      rank_member_in(leaderboard_name, member_and_score[0], member_and_score[1])
    end
  end

  # Remove a member from the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  def remove_member_from(leaderboard_name, member)
    member_score = @redis_connection.zscore(leaderboard_name, member) || nil
    can_delete_score = member_score && members_from_score_range_in(leaderboard_name, member_score, member_score).length == 1

    @redis_connection.multi do |transaction|
      transaction.zrem(leaderboard_name, member)
      transaction.zrem(ties_leaderboard_key(leaderboard_name), member_score.to_f.to_s) if can_delete_score
      transaction.hdel(member_data_key(leaderboard_name), member)
    end
  end

  # Retrieve the rank for a member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  #
  # @return the rank for a member in the leaderboard.
  def rank_for_in(leaderboard_name, member)
    member_score = score_for_in(leaderboard_name, member)
    if @reverse
      return @redis_connection.zrank(ties_leaderboard_key(leaderboard_name), member_score.to_f.to_s) + 1 rescue nil
    else
      return @redis_connection.zrevrank(ties_leaderboard_key(leaderboard_name), member_score.to_f.to_s) + 1 rescue nil
    end
  end

  # Retrieve the score and rank for a member in the named leaderboard.
  #
  # @param leaderboard_name [String]Name of the leaderboard.
  # @param member [String] Member name.
  #
  # @return the score and rank for a member in the named leaderboard as a Hash.
  def score_and_rank_for_in(leaderboard_name, member)
    member_score = @redis_connection.zscore(leaderboard_name, member)

    responses = @redis_connection.multi do |transaction|
      transaction.zscore(leaderboard_name, member)
      if @reverse
        transaction.zrank(ties_leaderboard_key(leaderboard_name), member_score.to_f.to_s)
      else
        transaction.zrevrank(ties_leaderboard_key(leaderboard_name), member_score.to_f.to_s)
      end
    end

    responses[0] = responses[0].to_f if responses[0]
    responses[1] = responses[1] + 1 rescue nil

    {@member_key => member, @score_key => responses[0], @rank_key => responses[1]}
  end

  # Remove members from the named leaderboard in a given score range.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param min_score [float] Minimum score.
  # @param max_score [float] Maximum score.
  def remove_members_in_score_range_in(leaderboard_name, min_score, max_score)
    @redis_connection.multi do |transaction|
      transaction.zremrangebyscore(leaderboard_name, min_score, max_score)
      transaction.zremrangebyscore(ties_leaderboard_key(leaderboard_name), min_score, max_score)
    end
  end

  # Expire the given leaderboard in a set number of seconds. Do not use this with
  # leaderboards that utilize member data as there is no facility to cascade the
  # expiration out to the keys for the member data.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param seconds [int] Number of seconds after which the leaderboard will be expired.
  def expire_leaderboard_for(leaderboard_name, seconds)
    @redis_connection.multi do |transaction|
      transaction.expire(leaderboard_name, seconds)
      transaction.expire(ties_leaderboard_key(leaderboard_name), seconds)
      transaction.expire(member_data_key(leaderboard_name), seconds)
    end
  end

  # Expire the given leaderboard at a specific UNIX timestamp. Do not use this with
  # leaderboards that utilize member data as there is no facility to cascade the
  # expiration out to the keys for the member data.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param timestamp [int] UNIX timestamp at which the leaderboard will be expired.
  def expire_leaderboard_at_for(leaderboard_name, timestamp)
    @redis_connection.multi do |transaction|
      transaction.expireat(leaderboard_name, timestamp)
      transaction.expireat(ties_leaderboard_key(leaderboard_name), timestamp)
      transaction.expireat(member_data_key(leaderboard_name), timestamp)
    end
  end

  # Retrieve a page of leaders from the named leaderboard for a given list of members.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param members [Array] Member names.
  # @param options [Hash] Options to be used when retrieving the page from the named leaderboard.
  #
  # @return a page of leaders from the named leaderboard for a given list of members.
  def ranked_in_list_in(leaderboard_name, members, options = {})
    leaderboard_options = DEFAULT_LEADERBOARD_REQUEST_OPTIONS.dup
    leaderboard_options.merge!(options)

    ranks_for_members = []

    responses = @redis_connection.multi do |transaction|
      members.each do |member|
        if @reverse
          transaction.zrank(leaderboard_name, member)
        else
          transaction.zrevrank(leaderboard_name, member)
        end
        transaction.zscore(leaderboard_name, member)
      end
    end unless leaderboard_options[:members_only]

    members.each_with_index do |member, index|
      data = {}
      data[@member_key] = member
      unless leaderboard_options[:members_only]
        data[@score_key] = responses[index * 2 + 1].to_f if responses[index * 2 + 1]

        if @reverse
          data[@rank_key] = @redis_connection.zrank(ties_leaderboard_key(leaderboard_name), data[@score_key].to_s) + 1 rescue nil
        else
          data[@rank_key] = @redis_connection.zrevrank(ties_leaderboard_key(leaderboard_name), data[@score_key].to_s) + 1 rescue nil
        end

        if data[@rank_key] == nil
          next unless leaderboard_options[:include_missing]
        end
      end

      if leaderboard_options[:with_member_data]
        data[@member_data_key] = member_data_for_in(leaderboard_name, member)
      end

      ranks_for_members << data
    end

    case leaderboard_options[:sort_by]
    when :rank
      ranks_for_members = ranks_for_members.sort_by { |member| member[@rank_key] }
    when :score
      ranks_for_members = ranks_for_members.sort_by { |member| member[@score_key] }
    end

    ranks_for_members
  end

  protected

  # Key for ties leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  #
  # @return a key in the form of +leaderboard_name:ties_namespace+
  def ties_leaderboard_key(leaderboard_name)
    "#{leaderboard_name}:#{@ties_namespace}"
  end
end