require 'redis'
require 'leaderboard/version'

class Leaderboard
  DEFAULT_PAGE_SIZE = 25
  
  DEFAULT_OPTIONS = {
    :page_size => DEFAULT_PAGE_SIZE,
    :reverse => false
  }

  DEFAULT_REDIS_HOST = 'localhost'
  
  DEFAULT_REDIS_PORT = 6379  
  
  DEFAULT_REDIS_OPTIONS = {
    :host => DEFAULT_REDIS_HOST,
    :port => DEFAULT_REDIS_PORT
  }
  
  DEFAULT_LEADERBOARD_REQUEST_OPTIONS = {
    :with_scores => true, 
    :with_rank => true, 
    :use_zero_index_for_rank => false,
    :page_size => nil
  }
  
  # Name of the leaderboard.
  attr_reader :leaderboard_name

  # Page size to be used when paging through the leaderboard. 
  attr_reader :page_size
  
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
    @leaderboard_name = leaderboard_name
    
    @reverse   = options[:reverse]
    @page_size = options[:page_size]
    if @page_size.nil? || @page_size < 1
      @page_size = DEFAULT_PAGE_SIZE
    end
    
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
    @redis_connection.del(leaderboard_name)
  end
      
  # Rank a member in the leaderboard.
  # 
  # @param member [String] Member name.
  # @param score [float] Member score.
  def rank_member(member, score)
    rank_member_in(@leaderboard_name, member, score)
  end

  # Rank a member in the named leaderboard.
  # 
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param score [float] Member score.
  def rank_member_in(leaderboard_name, member, score)
    @redis_connection.zadd(leaderboard_name, score, member)
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
    @redis_connection.zrem(leaderboard_name, member)
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
  # @return the total number of pages in the leaderboard.
  def total_pages
    total_pages_in(@leaderboard_name)
  end
  
  # Retrieve the total number of pages in the named leaderboard.
  # 
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param page_size [int] Page size to be used when paging through the leaderboard.
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
  
  # Change the score for a member in the leaderboard by a score delta which can be positive or negative.
  #
  # @param member [String] Member name.
  # @param delta [float] Score change.
  def change_score_for(member, delta)    
    change_score_for_member_in(@leaderboard_name, member, delta)
  end
  
  # Change the score for a member in the named leaderboard by a delta which can be positive or negative.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param delta [float] Score change.
  def change_score_for_member_in(leaderboard_name, member, delta)
    @redis_connection.zincrby(leaderboard_name, delta, member)
  end
  
  # Retrieve the rank for a member in the leaderboard.
  # 
  # @param member [String] Member name.
  # @param use_zero_index_for_rank [boolean, false] If the returned rank should be 0-indexed.
  # 
  # @return the rank for a member in the leaderboard.
  def rank_for(member, use_zero_index_for_rank = false)
    rank_for_in(@leaderboard_name, member, use_zero_index_for_rank)
  end
  
  # Retrieve the rank for a member in the named leaderboard.
  # 
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param use_zero_index_for_rank [boolean, false] If the returned rank should be 0-indexed.
  # 
  # @return the rank for a member in the leaderboard.
  def rank_for_in(leaderboard_name, member, use_zero_index_for_rank = false)
    if @reverse
      if use_zero_index_for_rank
        return @redis_connection.zrank(leaderboard_name, member)
      else
        return @redis_connection.zrank(leaderboard_name, member) + 1 rescue nil
      end
    else
      if use_zero_index_for_rank
        return @redis_connection.zrevrank(leaderboard_name, member)
      else
        return @redis_connection.zrevrank(leaderboard_name, member) + 1 rescue nil
      end
    end
  end
  
  # Retrieve the score for a member in the leaderboard.
  # 
  # @param member Member name.
  #
  # @return the score for a member in the leaderboard.
  def score_for(member)
    score_for_in(@leaderboard_name, member)
  end
  
  # Retrieve the score for a member in the named leaderboard.
  # 
  # @param leaderboard_name Name of the leaderboard.
  # @param member [String] Member name.
  #
  # @return the score for a member in the leaderboard.
  def score_for_in(leaderboard_name, member)
    @redis_connection.zscore(leaderboard_name, member).to_f
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
  # @param use_zero_index_for_rank [boolean, false] If the returned rank should be 0-indexed.
  #
  # @return the score and rank for a member in the leaderboard as a Hash.
  def score_and_rank_for(member, use_zero_index_for_rank = false)
    score_and_rank_for_in(@leaderboard_name, member, use_zero_index_for_rank)
  end

  # Retrieve the score and rank for a member in the named leaderboard.
  #
  # @param leaderboard_name [String]Name of the leaderboard.
  # @param member [String] Member name.
  # @param use_zero_index_for_rank [boolean, false] If the returned rank should be 0-indexed.
  #
  # @return the score and rank for a member in the named leaderboard as a Hash.
  def score_and_rank_for_in(leaderboard_name, member, use_zero_index_for_rank = false)
    responses = @redis_connection.multi do |transaction|
      transaction.zscore(leaderboard_name, member)
      if @reverse
        transaction.zrank(leaderboard_name, member)
      else
        transaction.zrevrank(leaderboard_name, member)
      end
    end
    
    responses[0] = responses[0].to_f
    if !use_zero_index_for_rank
      responses[1] = responses[1] + 1 rescue nil
    end
    
    {:member => member, :score => responses[0], :rank => responses[1]}    
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
    
  # Retrieve a page of leaders from the leaderboard.
  # 
  # @param current_page [int] Page to retrieve from the leaderboard.
  # @param options [Hash] Options to be used when retrieving the page from the leaderboard.
  # 
  # @return a page of leaders from the leaderboard.
  def leaders(current_page, options = {})
    leaders_in(@leaderboard_name, current_page, options)
  end

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
          transaction.zrank(leaderboard_name, member) if leaderboard_options[:with_rank]
        else
          transaction.zrevrank(leaderboard_name, member) if leaderboard_options[:with_rank]
        end
        transaction.zscore(leaderboard_name, member) if leaderboard_options[:with_scores]
      end
    end
    
    members.each_with_index do |member, index|
      data = {}
      data[:member] = member
      if leaderboard_options[:with_scores]
        if leaderboard_options[:with_rank]
          if leaderboard_options[:use_zero_index_for_rank]
            data[:rank] = responses[index * 2]
          else
            data[:rank] = responses[index * 2] + 1 rescue nil
          end
          
          data[:score] = responses[index * 2 + 1].to_f
        else
          data[:score] = responses[index].to_f          
        end
      else
        if leaderboard_options[:with_rank]
          if leaderboard_options[:use_zero_index_for_rank]
            data[:rank] = responses[index]
          else
            data[:rank] = responses[index] + 1 rescue nil
          end
        end
      end
      
      ranks_for_members << data
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
  
  private 
  
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