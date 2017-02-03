require 'redis'
require 'leaderboard/version'

class Leaderboard
  # Default page size: 25
  DEFAULT_PAGE_SIZE = 25

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
    :global_member_data => false
  }

  # Default Redis host: localhost
  DEFAULT_REDIS_HOST = 'localhost'

  # Default Redis post: 6379
  DEFAULT_REDIS_PORT = 6379

  # Default Redis options when creating a connection to Redis. The
  # +DEFAULT_REDIS_HOST+ and +DEFAULT_REDIS_PORT+ will be passed.
  DEFAULT_REDIS_OPTIONS = {
    :host => DEFAULT_REDIS_HOST,
    :port => DEFAULT_REDIS_PORT
  }

  # Default options when requesting data from a leaderboard.
  # +:with_member_data+ false: Return member data along with the member names.
  # +:page_size+ nil: The default page size will be used.
  # +:members_only+ false: Only return the member name, not their score and rank.
  # +:sort_by+ :none: The default sort for a call to `ranked_in_list`.
  DEFAULT_LEADERBOARD_REQUEST_OPTIONS = {
    :with_member_data => false,
    :page_size => nil,
    :members_only => false,
    :sort_by => :none,
    :include_missing => true
  }

  # Name of the leaderboard.
  attr_reader :leaderboard_name

  # Page size to be used when paging through the leaderboard.
  attr_reader :page_size

  # Determines whether or not various leaderboard methods return their
  # data in highest-to-lowest (+:reverse+ false) or
  # lowest-to-highest (+:reverse+ true)
  attr_accessor :reverse

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
    leaderboard_options = DEFAULT_OPTIONS.dup
    leaderboard_options.merge!(options)

    @leaderboard_name = leaderboard_name

    @reverse   = leaderboard_options[:reverse]
    @page_size = leaderboard_options[:page_size]
    if @page_size.nil? || @page_size < 1
      @page_size = DEFAULT_PAGE_SIZE
    end
    @member_key = leaderboard_options[:member_key]
    @rank_key = leaderboard_options[:rank_key]
    @score_key = leaderboard_options[:score_key]
    @member_data_key = leaderboard_options[:member_data_key]
    @member_data_namespace = leaderboard_options[:member_data_namespace]
    @global_member_data = leaderboard_options[:global_member_data]

    @redis_connection = redis_options[:redis_connection]
    unless @redis_connection.nil?
      redis_options.delete(:redis_connection)
    end

    @redis_connection = Redis.new(redis_options) if @redis_connection.nil?
  end

  # Set the page size to be used when paging through the leaderboard. This method
  # also has the side effect of setting the page size to the +DEFAULT_PAGE_SIZE+
  # if the page size is less than 1.
  #
  # @param page_size [int] Page size.
  def page_size=(page_size)
    page_size = DEFAULT_PAGE_SIZE if page_size < 1

    @page_size = page_size
  end

  # Disconnect the Redis connection.
  def disconnect
    @redis_connection.client.disconnect
  end

  # Delete the current leaderboard.
  def delete_leaderboard
    delete_leaderboard_named(@leaderboard_name)
  end

  # Delete the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  def delete_leaderboard_named(leaderboard_name)
    @redis_connection.multi do |transaction|
      transaction.del(leaderboard_name)
      transaction.del(member_data_key(leaderboard_name))
    end
  end

  # Rank a member in the leaderboard.
  #
  # @param member [String] Member name.
  # @param score [float] Member score.
  # @param member_data [String] Optional member data.
  def rank_member(member, score, member_data = nil)
    rank_member_in(@leaderboard_name, member, score, member_data)
  end

  # Rank a member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param score [float] Member score.
  # @param member_data [String] Optional member data.
  def rank_member_in(leaderboard_name, member, score, member_data = nil)
    @redis_connection.multi do |transaction|
      transaction.zadd(leaderboard_name, score, member)
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
    @redis_connection.multi do |transaction|
      leaderboards.each do |leaderboard_name|
        transaction.zadd(leaderboard_name, score, member)
        transaction.hset(member_data_key(leaderboard_name), member, member_data) if member_data
      end
    end
  end

  # Rank a member in the leaderboard based on execution of the +rank_conditional+.
  #
  # The +rank_conditional+ is passed the following parameters:
  #   member: Member name.
  #   current_score: Current score for the member in the leaderboard.
  #   score: Member score.
  #   member_data: Optional member data.
  #   leaderboard_options: Leaderboard options, e.g. :reverse => Value of reverse option
  #
  # @param rank_conditional [lambda] Lambda which must return +true+ or +false+ that controls whether or not the member is ranked in the leaderboard.
  # @param member [String] Member name.
  # @param score [float] Member score.
  # @param member_data [String] Optional member_data.
  def rank_member_if(rank_conditional, member, score, member_data = nil)
    rank_member_if_in(@leaderboard_name, rank_conditional, member, score, member_data)
  end

  # Rank a member in the named leaderboard based on execution of the +rank_conditional+.
  #
  # The +rank_conditional+ is passed the following parameters:
  #   member: Member name.
  #   current_score: Current score for the member in the leaderboard.
  #   score: Member score.
  #   member_data: Optional member data.
  #   leaderboard_options: Leaderboard options, e.g. :reverse => Value of reverse option
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param rank_conditional [lambda] Lambda which must return +true+ or +false+ that controls whether or not the member is ranked in the leaderboard.
  # @param member [String] Member name.
  # @param score [float] Member score.
  # @param member_data [String] Optional member_data.
  def rank_member_if_in(leaderboard_name, rank_conditional, member, score, member_data = nil)
    current_score = @redis_connection.zscore(leaderboard_name, member)
    current_score = current_score.to_f if current_score

    if rank_conditional.call(member, current_score, score, member_data, {:reverse => @reverse})
      rank_member_in(leaderboard_name, member, score, member_data)
    end
  end

  # Retrieve the optional member data for a given member in the leaderboard.
  #
  # @param member [String] Member name.
  #
  # @return String of optional member data.
  def member_data_for(member)
    member_data_for_in(@leaderboard_name, member)
  end

  # Retrieve the optional member data for a given member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  #
  # @return String of optional member data.
  def member_data_for_in(leaderboard_name, member)
    @redis_connection.hget(member_data_key(leaderboard_name), member)
  end

  # Retrieve the optional member data for a given member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param members [Array] Member names.
  #
  # @return array of strings of optional member data.
  def members_data_for_in(leaderboard_name, members)
    return [] unless members.size > 0
    @redis_connection.hmget(member_data_key(leaderboard_name), *members)
  end

  # Retrieve the optional member data for the given members in the leaderboard.
  #
  # @param members [Array] Member names.
  #
  # @return array of strings of optional member data.
  def members_data_for(members)
    members_data_for_in(@leaderboard_name, members)
  end

  # Update the optional member data for a given member in the leaderboard.
  #
  # @param member [String] Member name.
  # @param member_data [String] Optional member data.
  def update_member_data(member, member_data)
    update_member_data_in(@leaderboard_name, member, member_data)
  end

  # Update the optional member data for a given member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param member_data [String] Optional member data.
  def update_member_data_in(leaderboard_name, member, member_data)
    @redis_connection.hset(member_data_key(leaderboard_name), member, member_data)
  end

  # Remove the optional member data for a given member in the leaderboard.
  #
  # @param member [String] Member name.
  def remove_member_data(member)
    remove_member_data_in(@leaderboard_name, member)
  end

  # Remove the optional member data for a given member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  def remove_member_data_in(leaderboard_name, member)
    @redis_connection.hdel(member_data_key(leaderboard_name), member)
  end

  # Rank an array of members in the leaderboard.
  #
  # @param members_and_scores [Splat or Array] Variable list of members and scores
  def rank_members(*members_and_scores)
    rank_members_in(@leaderboard_name, *members_and_scores)
  end

  # Rank an array of members in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param members_and_scores [Splat or Array] Variable list of members and scores
  def rank_members_in(leaderboard_name, *members_and_scores)
    if members_and_scores.is_a?(Array)
      members_and_scores.flatten!
    end

    @redis_connection.multi do |transaction|
      members_and_scores.each_slice(2) do |member_and_score|
        transaction.zadd(leaderboard_name, member_and_score[1], member_and_score[0])
      end
    end
  end

  # Remove a member from the leaderboard.
  #
  # @param member [String] Member name.
  def remove_member(member)
    remove_member_from(@leaderboard_name, member)
  end

  # Remove a member from the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  def remove_member_from(leaderboard_name, member)
    @redis_connection.multi do |transaction|
      transaction.zrem(leaderboard_name, member)
      transaction.hdel(member_data_key(leaderboard_name), member)
    end
  end

  # Retrieve the total number of members in the leaderboard.
  #
  # @return total number of members in the leaderboard.
  def total_members
    total_members_in(@leaderboard_name)
  end

  # Retrieve the total number of members in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  #
  # @return the total number of members in the named leaderboard.
  def total_members_in(leaderboard_name)
    @redis_connection.zcard(leaderboard_name)
  end

  # Retrieve the total number of pages in the leaderboard.
  #
  # @param page_size [int, nil] Page size to be used when calculating the total number of pages.
  #
  # @return the total number of pages in the leaderboard.
  def total_pages(page_size = nil)
    total_pages_in(@leaderboard_name, page_size)
  end

  # Retrieve the total number of pages in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param page_size [int, nil] Page size to be used when calculating the total number of pages.
  #
  # @return the total number of pages in the named leaderboard.
  def total_pages_in(leaderboard_name, page_size = nil)
    page_size ||= @page_size.to_f
    (total_members_in(leaderboard_name) / page_size.to_f).ceil
  end

  # Retrieve the total members in a given score range from the leaderboard.
  #
  # @param min_score [float] Minimum score.
  # @param max_score [float] Maximum score.
  #
  # @return the total members in a given score range from the leaderboard.
  def total_members_in_score_range(min_score, max_score)
    total_members_in_score_range_in(@leaderboard_name, min_score, max_score)
  end

  # Retrieve the total members in a given score range from the named leaderboard.
  #
  # @param leaderboard_name Name of the leaderboard.
  # @param min_score [float] Minimum score.
  # @param max_score [float] Maximum score.
  #
  # @return the total members in a given score range from the named leaderboard.
  def total_members_in_score_range_in(leaderboard_name, min_score, max_score)
    @redis_connection.zcount(leaderboard_name, min_score, max_score)
  end

  # Sum of scores for all members in leaderboard
  #
  # @return Sum of scores for all members in leaderboard
  def total_scores
    total_scores_in(@leaderboard_name)
  end

  # Sum of scores for all members in the named leaderboard
  #
  # @return Sum of scores for all members in named leaderboard
  def total_scores_in(leaderboard_name)
    all_leaders_from(leaderboard_name).map{|hash| hash[:score] }.inject(0, :+)
  end

  # Change the score for a member in the leaderboard by a score delta which can be positive or negative.
  #
  # @param member [String] Member name.
  # @param delta [float] Score change.
  # @param member_data [String] Optional member data.
  def change_score_for(member, delta, member_data = nil)
    change_score_for_member_in(@leaderboard_name, member, delta, member_data)
  end

  # Change the score for a member in the named leaderboard by a delta which can be positive or negative.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param delta [float] Score change.
  # @param member_data [String] Optional member data.
  def change_score_for_member_in(leaderboard_name, member, delta, member_data)
    @redis_connection.multi do |transaction|
      transaction.zincrby(leaderboard_name, delta, member)
      transaction.hset(member_data_key(leaderboard_name), member, member_data) if member_data
    end
  end

  # Retrieve the rank for a member in the leaderboard.
  #
  # @param member [String] Member name.
  #
  # @return the rank for a member in the leaderboard.
  def rank_for(member)
    rank_for_in(@leaderboard_name, member)
  end

  # Retrieve the rank for a member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  #
  # @return the rank for a member in the leaderboard.
  def rank_for_in(leaderboard_name, member)
    if @reverse
      return @redis_connection.zrank(leaderboard_name, member) + 1 rescue nil
    else
      return @redis_connection.zrevrank(leaderboard_name, member) + 1 rescue nil
    end
  end

  # Retrieve the score for a member in the leaderboard.
  #
  # @param member Member name.
  #
  # @return the score for a member in the leaderboard or +nil+ if the member is not in the leaderboard.
  def score_for(member)
    score_for_in(@leaderboard_name, member)
  end

  # Retrieve the score for a member in the named leaderboard.
  #
  # @param leaderboard_name Name of the leaderboard.
  # @param member [String] Member name.
  #
  # @return the score for a member in the leaderboard or +nil+ if the member is not in the leaderboard.
  def score_for_in(leaderboard_name, member)
    score = @redis_connection.zscore(leaderboard_name, member)
    score.to_f if score
  end

  # Check to see if a member exists in the leaderboard.
  #
  # @param member [String] Member name.
  #
  # @return +true+ if the member exists in the leaderboard, +false+ otherwise.
  def check_member?(member)
    check_member_in?(@leaderboard_name, member)
  end

  # Check to see if a member exists in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  #
  # @return +true+ if the member exists in the named leaderboard, +false+ otherwise.
  def check_member_in?(leaderboard_name, member)
    !@redis_connection.zscore(leaderboard_name, member).nil?
  end

  # Retrieve the score and rank for a member in the leaderboard.
  #
  # @param member [String] Member name.
  #
  # @return the score and rank for a member in the leaderboard as a Hash.
  def score_and_rank_for(member)
    score_and_rank_for_in(@leaderboard_name, member)
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
    responses[1] = responses[1] + 1 rescue nil

    {@member_key => member, @score_key => responses[0], @rank_key => responses[1]}
  end

  # Remove members from the leaderboard in a given score range.
  #
  # @param min_score [float] Minimum score.
  # @param max_score [float] Maximum score.
  def remove_members_in_score_range(min_score, max_score)
    remove_members_in_score_range_in(@leaderboard_name, min_score, max_score)
  end

  # Remove members from the named leaderboard in a given score range.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param min_score [float] Minimum score.
  # @param max_score [float] Maximum score.
  def remove_members_in_score_range_in(leaderboard_name, min_score, max_score)
    @redis_connection.zremrangebyscore(leaderboard_name, min_score, max_score)
  end

  # Remove members from the leaderboard outside a given rank.
  #
  # @param rank [int] The rank (inclusive) which we should keep.
  # @return the total number of members removed.
  def remove_members_outside_rank(rank)
    remove_members_outside_rank_in(@leaderboard_name, rank)
  end

  # Remove members from the leaderboard outside a given rank.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param rank [int] The rank (inclusive) which we should keep.
  # @return the total number of members removed.
  def remove_members_outside_rank_in(leaderboard_name, rank)
    if @reverse
      @redis_connection.zremrangebyrank(leaderboard_name, rank, -1)
    else
      @redis_connection.zremrangebyrank(leaderboard_name, 0, -(rank) - 1)
    end
  end

  # Retrieve the percentile for a member in the leaderboard.
  #
  # @param member [String] Member name.
  #
  # @return the percentile for a member in the leaderboard. Return +nil+ for a non-existent member.
  def percentile_for(member)
    percentile_for_in(@leaderboard_name, member)
  end

  # Retrieve the percentile for a member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  #
  # @return the percentile for a member in the named leaderboard.
  def percentile_for_in(leaderboard_name, member)
    return nil unless check_member_in?(leaderboard_name, member)

    responses = @redis_connection.multi do |transaction|
      transaction.zcard(leaderboard_name)
      transaction.zrevrank(leaderboard_name, member)
    end

    percentile = ((responses[0] - responses[1] - 1).to_f / responses[0].to_f * 100).ceil
    if @reverse
      100 - percentile
    else
      percentile
    end
  end

  # Calculate the score for a given percentile value in the leaderboard.
  #
  # @param percentile [float] Percentile value (0.0 to 100.0 inclusive)
  def score_for_percentile(percentile)
    score_for_percentile_in(@leaderboard_name, percentile)
  end

  # Calculate the score for a given percentile value in the named leaderboard.
  #
  # See http://www.itl.nist.gov/div898/handbook/prc/section2/prc252.htm for
  # implementation details (there are differing methods for calculating
  # percentile scores that do not fall directly upon a ranked item; we are
  # using the method specified by NIST, i.e. linear interpolation).
  #
  # @param percentile [float] Percentile value (0.0 to 100.0 inclusive)
  def score_for_percentile_in(leaderboard_name, percentile)
    return nil unless percentile.between?(0, 100)

    total_members = total_members_in(leaderboard_name)
    return nil if total_members < 1

    if @reverse
      percentile = 100 - percentile
    end

    index = (total_members - 1) * (percentile / 100.0)

    scores = @redis_connection.zrange(
      leaderboard_name, index.floor, index.ceil, :with_scores => true
    ).map{ |pair| pair.last }

    if index == index.floor
      scores[0]
    else
      interpolate_fraction = index - index.floor
      scores[0] + interpolate_fraction * (scores[1] - scores[0])
    end
  end

  # Determine the page where a member falls in the leaderboard.
  #
  # @param member [String] Member name.
  # @param page_size [int] Page size to be used in determining page location.
  #
  # @return the page where a member falls in the leaderboard.
  def page_for(member, page_size = DEFAULT_PAGE_SIZE)
    page_for_in(@leaderboard_name, member, page_size)
  end

  # Determine the page where a member falls in the named leaderboard.
  #
  # @param leaderboard [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param page_size [int] Page size to be used in determining page location.
  #
  # @return the page where a member falls in the leaderboard.
  def page_for_in(leaderboard_name, member, page_size = DEFAULT_PAGE_SIZE)
    rank_for_member = @reverse ?
      @redis_connection.zrank(leaderboard_name, member) :
      @redis_connection.zrevrank(leaderboard_name, member)

    if rank_for_member.nil?
      rank_for_member = 0
    else
      rank_for_member += 1
    end

    (rank_for_member.to_f / page_size.to_f).ceil
  end

  # Expire the current leaderboard in a set number of seconds. Do not use this with
  # leaderboards that utilize member data as there is no facility to cascade the
  # expiration out to the keys for the member data.
  #
  # @param seconds [int] Number of seconds after which the leaderboard will be expired.
  def expire_leaderboard(seconds)
    expire_leaderboard_for(@leaderboard_name, seconds)
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
      transaction.expire(member_data_key(leaderboard_name), seconds)
    end
  end

  # Expire the current leaderboard at a specific UNIX timestamp. Do not use this with
  # leaderboards that utilize member data as there is no facility to cascade the
  # expiration out to the keys for the member data.
  #
  # @param timestamp [int] UNIX timestamp at which the leaderboard will be expired.
  def expire_leaderboard_at(timestamp)
    expire_leaderboard_at_for(@leaderboard_name, timestamp)
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
      transaction.expireat(member_data_key(leaderboard_name), timestamp)
    end
  end

  # Retrieve a page of leaders from the leaderboard.
  #
  # @param current_page [int] Page to retrieve from the leaderboard.
  # @param options [Hash] Options to be used when retrieving the page from the leaderboard.
  #
  # @return a page of leaders from the leaderboard.
  def leaders(current_page, options = {})
    leaders_in(@leaderboard_name, current_page, options)
  end

  alias_method :members, :leaders

  # Retrieve a page of leaders from the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param current_page [int] Page to retrieve from the named leaderboard.
  # @param options [Hash] Options to be used when retrieving the page from the named leaderboard.
  #
  # @return a page of leaders from the named leaderboard.
  def leaders_in(leaderboard_name, current_page, options = {})
    leaderboard_options = DEFAULT_LEADERBOARD_REQUEST_OPTIONS.dup
    leaderboard_options.merge!(options)

    if current_page < 1
      current_page = 1
    end

    page_size = validate_page_size(leaderboard_options[:page_size]) || @page_size

    if current_page > total_pages_in(leaderboard_name, page_size)
      current_page = total_pages_in(leaderboard_name, page_size)
    end

    index_for_redis = current_page - 1

    starting_offset = (index_for_redis * page_size)
    if starting_offset < 0
      starting_offset = 0
    end

    ending_offset = (starting_offset + page_size) - 1

    if @reverse
      raw_leader_data = @redis_connection.zrange(leaderboard_name, starting_offset, ending_offset, :with_scores => false)
    else
      raw_leader_data = @redis_connection.zrevrange(leaderboard_name, starting_offset, ending_offset, :with_scores => false)
    end

    if raw_leader_data
      return ranked_in_list_in(leaderboard_name, raw_leader_data, leaderboard_options)
    else
      return []
    end
  end

  alias_method :members_in, :leaders_in

  # Retrieve all leaders from the leaderboard.
  #
  # @param options [Hash] Options to be used when retrieving the leaders from the leaderboard.
  #
  # @return the leaders from the leaderboard.
  def all_leaders(options = {})
    all_leaders_from(@leaderboard_name, options)
  end

  alias_method :all_members, :all_leaders

  # Retrieves all leaders from the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param options [Hash] Options to be used when retrieving the leaders from the named leaderboard.
  #
  # @return the named leaderboard.
  def all_leaders_from(leaderboard_name, options = {})
    leaderboard_options = DEFAULT_LEADERBOARD_REQUEST_OPTIONS.dup
    leaderboard_options.merge!(options)

    if @reverse
      raw_leader_data = @redis_connection.zrange(leaderboard_name, 0, -1, :with_scores => false)
    else
      raw_leader_data = @redis_connection.zrevrange(leaderboard_name, 0, -1, :with_scores => false)
    end

    if raw_leader_data
      return ranked_in_list_in(leaderboard_name, raw_leader_data, leaderboard_options)
    else
      return []
    end
  end

  alias_method :all_members_from, :all_leaders_from

  # Retrieve members from the leaderboard within a given score range.
  #
  # @param minimum_score [float] Minimum score (inclusive).
  # @param maximum_score [float] Maximum score (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
  #
  # @return members from the leaderboard that fall within the given score range.
  def members_from_score_range(minimum_score, maximum_score, options = {})
    members_from_score_range_in(@leaderboard_name, minimum_score, maximum_score, options)
  end

  # Retrieve members from the named leaderboard within a given score range.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param minimum_score [float] Minimum score (inclusive).
  # @param maximum_score [float] Maximum score (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
  #
  # @return members from the leaderboard that fall within the given score range.
  def members_from_score_range_in(leaderboard_name, minimum_score, maximum_score, options = {})
    leaderboard_options = DEFAULT_LEADERBOARD_REQUEST_OPTIONS.dup
    leaderboard_options.merge!(options)

    raw_leader_data = @reverse ?
      @redis_connection.zrangebyscore(leaderboard_name, minimum_score, maximum_score) :
      @redis_connection.zrevrangebyscore(leaderboard_name, maximum_score, minimum_score)

    if raw_leader_data
      return ranked_in_list_in(leaderboard_name, raw_leader_data, leaderboard_options)
    else
      return []
    end
  end

  # Retrieve members from the leaderboard within a given rank range.
  #
  # @param starting_rank [int] Starting rank (inclusive).
  # @param ending_rank [int] Ending rank (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
  #
  # @return members from the leaderboard that fall within the given rank range.
  def members_from_rank_range(starting_rank, ending_rank, options = {})
    members_from_rank_range_in(@leaderboard_name, starting_rank, ending_rank, options)
  end

  # Retrieve members from the named leaderboard within a given rank range.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param starting_rank [int] Starting rank (inclusive).
  # @param ending_rank [int] Ending rank (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
  #
  # @return members from the leaderboard that fall within the given rank range.
  def members_from_rank_range_in(leaderboard_name, starting_rank, ending_rank, options = {})
    leaderboard_options = DEFAULT_LEADERBOARD_REQUEST_OPTIONS.dup
    leaderboard_options.merge!(options)

    starting_rank -= 1
    if starting_rank < 0
      starting_rank = 0
    end

    ending_rank -= 1
    if ending_rank > total_members_in(leaderboard_name)
      ending_rank = total_members_in(leaderboard_name) - 1
    end

    if @reverse
      raw_leader_data = @redis_connection.zrange(leaderboard_name, starting_rank, ending_rank, :with_scores => false)
    else
      raw_leader_data = @redis_connection.zrevrange(leaderboard_name, starting_rank, ending_rank, :with_scores => false)
    end

    if raw_leader_data
      return ranked_in_list_in(leaderboard_name, raw_leader_data, leaderboard_options)
    else
      return []
    end
  end

  # Retrieve members from the leaderboard within a range from 1 to the number given.
  #
  # @param ending_rank [int] Ending rank (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
  #
  # @return number from the leaderboard that fall within the given rank range.
  def top(number, options = {})
    top_in(@leaderboard_name, number, options)
  end

  # Retrieve members from the named leaderboard within a range from 1 to the number given.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param starting_rank [int] Starting rank (inclusive).
  # @param ending_rank [int] Ending rank (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
  #
  # @return members from the leaderboard that fall within the given rank range.
  def top_in(leaderboard_name, number, options={})
    members_from_rank_range_in(leaderboard_name, 1, number, options)
  end

  # Retrieve a member at the specified index from the leaderboard.
  #
  # @param position [int] Position in leaderboard.
  # @param options [Hash] Options to be used when retrieving the member from the leaderboard.
  #
  # @return a member from the leaderboard.
  def member_at(position, options = {})
    member_at_in(@leaderboard_name, position, options)
  end

  # Retrieve a member at the specified index from the leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param position [int] Position in named leaderboard.
  # @param options [Hash] Options to be used when retrieving the member from the named leaderboard.
  #
  # @return a page of leaders from the named leaderboard.
  def member_at_in(leaderboard_name, position, options = {})
    if position > 0 && position <= total_members_in(leaderboard_name)
      leaderboard_options = DEFAULT_LEADERBOARD_REQUEST_OPTIONS.dup
      leaderboard_options.merge!(options)
      page_size = validate_page_size(leaderboard_options[:page_size]) || @page_size
      current_page = (position.to_f / page_size.to_f).ceil
      offset = (position - 1) % page_size

      leaders = leaders_in(leaderboard_name, current_page, options)
      leaders[offset] if leaders
    end
  end

  # Retrieve a page of leaders from the leaderboard around a given member.
  #
  # @param member [String] Member name.
  # @param options [Hash] Options to be used when retrieving the page from the leaderboard.
  #
  # @return a page of leaders from the leaderboard around a given member.
  def around_me(member, options = {})
    around_me_in(@leaderboard_name, member, options)
  end

  # Retrieve a page of leaders from the named leaderboard around a given member.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param options [Hash] Options to be used when retrieving the page from the named leaderboard.
  #
  # @return a page of leaders from the named leaderboard around a given member. Returns an empty array for a non-existent member.
  def around_me_in(leaderboard_name, member, options = {})
    leaderboard_options = DEFAULT_LEADERBOARD_REQUEST_OPTIONS.dup
    leaderboard_options.merge!(options)

    reverse_rank_for_member = @reverse ?
      @redis_connection.zrank(leaderboard_name, member) :
      @redis_connection.zrevrank(leaderboard_name, member)

    return [] unless reverse_rank_for_member

    page_size = validate_page_size(leaderboard_options[:page_size]) || @page_size

    starting_offset = reverse_rank_for_member - (page_size / 2)
    if starting_offset < 0
      starting_offset = 0
    end

    ending_offset = (starting_offset + page_size) - 1

    raw_leader_data = @reverse ?
      @redis_connection.zrange(leaderboard_name, starting_offset, ending_offset, :with_scores => false) :
      @redis_connection.zrevrange(leaderboard_name, starting_offset, ending_offset, :with_scores => false)

    if raw_leader_data
      return ranked_in_list_in(leaderboard_name, raw_leader_data, leaderboard_options)
    else
      return []
    end
  end

  # Retrieve a page of leaders from the leaderboard for a given list of members.
  #
  # @param members [Array] Member names.
  # @param options [Hash] Options to be used when retrieving the page from the leaderboard.
  #
  # @return a page of leaders from the leaderboard for a given list of members.
  def ranked_in_list(members, options = {})
    ranked_in_list_in(@leaderboard_name, members, options)
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
        data[@rank_key] = responses[index * 2] + 1 rescue nil
        if data[@rank_key] == nil
          next unless leaderboard_options[:include_missing]
        end
        data[@score_key] = responses[index * 2 + 1].to_f if responses[index * 2 + 1]
      end

      ranks_for_members << data
    end

    if leaderboard_options[:with_member_data]
      included_members = ranks_for_members.collect { |member| member[@member_key] }
      members_data_for_in(leaderboard_name, included_members).each_with_index do |member_data, index|
        ranks_for_members[index][@member_data_key] = member_data
      end
    end

    case leaderboard_options[:sort_by]
    when :rank
      ranks_for_members = ranks_for_members.sort_by { |member| member[@rank_key] }
    when :score
      ranks_for_members = ranks_for_members.sort_by { |member| member[@score_key] }
    end

    ranks_for_members
  end

  # Merge leaderboards given by keys with this leaderboard into a named destination leaderboard.
  #
  # @param destination [String] Destination leaderboard name.
  # @param keys [Array] Leaderboards to be merged with the current leaderboard.
  # @param options [Hash] Options for merging the leaderboards.
  def merge_leaderboards(destination, keys, options = {:aggregate => :sum})
    @redis_connection.zunionstore(destination, keys.insert(0, @leaderboard_name), options)
  end

  # Intersect leaderboards given by keys with this leaderboard into a named destination leaderboard.
  #
  # @param destination [String] Destination leaderboard name.
  # @param keys [Array] Leaderboards to be merged with the current leaderboard.
  # @param options [Hash] Options for intersecting the leaderboards.
  def intersect_leaderboards(destination, keys, options = {:aggregate => :sum})
    @redis_connection.zinterstore(destination, keys.insert(0, @leaderboard_name), options)
  end

  protected

  # Key for retrieving optional member data.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  #
  # @return a key in the form of +leaderboard_name:member_data+
  def member_data_key(leaderboard_name)
    @global_member_data == false ? "#{leaderboard_name}:#{@member_data_namespace}" : @member_data_namespace
  end

  # Validate and return the page size. Returns the +DEFAULT_PAGE_SIZE+ if the page size is less than 1.
  #
  # @param page_size [int] Page size.
  #
  # @return the page size. Returns the +DEFAULT_PAGE_SIZE+ if the page size is less than 1.
  def validate_page_size(page_size)
    if page_size && page_size < 1
      page_size = DEFAULT_PAGE_SIZE
    end

    page_size
  end
end
