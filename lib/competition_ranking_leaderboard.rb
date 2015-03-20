require 'leaderboard'

class CompetitionRankingLeaderboard < Leaderboard
  # Retrieve the rank for a member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  #
  # @return the rank for a member in the leaderboard.
  def rank_for_in(leaderboard_name, member)
    member_score = score_for_in(leaderboard_name, member)
    if @reverse
      return @redis_connection.zcount(leaderboard_name, '-inf', "(#{member_score}") + 1 rescue nil
    else
      return @redis_connection.zcount(leaderboard_name, "(#{member_score}", '+inf') + 1 rescue nil
    end
  end

  # Retrieve the score and rank for a member in the named leaderboard.
  #
  # @param leaderboard_name [String]Name of the leaderboard.
  # @param member [String] Member name.
  #
  # @return the score and rank for a member in the named leaderboard as a Hash.
  def score_and_rank_for_in(leaderboard_name, member)
    responses = @redis_connection.multi do |transaction|
      transaction.zscore(leaderboard_name, member)
      if @reverse
        transaction.zrank(leaderboard_name, member)
      else
        transaction.zrevrank(leaderboard_name, member)
      end
    end

    responses[0] = responses[0].to_f if responses[0]
    responses[1] =
      if @reverse
        @redis_connection.zcount(leaderboard_name, '-inf', "(#{responses[0]}") + 1 rescue nil
      else
        @redis_connection.zcount(leaderboard_name, "(#{responses[0]}", '+inf') + 1 rescue nil
      end

    {@member_key => member, @score_key => responses[0], @rank_key => responses[1]}
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
        if data[@score_key] == nil
          next unless leaderboard_options[:include_missing]
        end

        if @reverse
          data[@rank_key] = @redis_connection.zcount(leaderboard_name, '-inf', "(#{data[@score_key]}") + 1 rescue nil
        else
          data[@rank_key] = @redis_connection.zcount(leaderboard_name, "(#{data[@score_key]}", '+inf') + 1 rescue nil
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
end