require 'redis'

class Leaderboard
  VERSION = '1.0.2'.freeze
  
  DEFAULT_PAGE_SIZE = 25
  DEFAULT_REDIS_HOST = 'localhost'
  DEFAULT_REDIS_PORT = 6379
  
  attr_reader :host
  attr_reader :port
  attr_reader :leaderboard_name
  attr_accessor :page_size
  
  def initialize(leaderboard_name, host = DEFAULT_REDIS_HOST, port = DEFAULT_REDIS_PORT, page_size = DEFAULT_PAGE_SIZE, redis_options = {})
    @leaderboard_name = leaderboard_name
    @host = host
    @port = port
    
    if page_size < 1
      page_size = DEFAULT_PAGE_SIZE
    end
    
    @page_size = page_size
    
    redis_options = redis_options.dup
    redis_options[:host] ||= @host
    redis_options[:port] ||= @port
    
    @redis_options = redis_options
    
    @redis_connection = Redis.new(@redis_options)
  end
      
  def add_member(member, score)
    add_member_to(@leaderboard_name, member, score)
  end

  def add_member_to(leaderboard_name, member, score)
    @redis_connection.zadd(leaderboard_name, score, member)
  end
  
  def remove_member(member)
    remove_member_from(@leaderboard_name, member)
  end
  
  def remove_member_from(leaderboard_name, member)
    @redis_connection.zrem(leaderboard_name, member)
  end
  
  def total_members
    total_members_in(@leaderboard_name)
  end
  
  def total_members_in(leaderboard_name)
    @redis_connection.zcard(leaderboard_name)
  end
  
  def total_pages
    total_pages_in(@leaderboard_name)
  end
  
  def total_pages_in(leaderboard_name)
    (total_members_in(leaderboard_name) / @page_size.to_f).ceil
  end
  
  def total_members_in_score_range(min_score, max_score)
    total_members_in_score_range_in(@leaderboard_name, min_score, max_score)
  end
  
  def total_members_in_score_range_in(leaderboard_name, min_score, max_score)
    @redis_connection.zcount(leaderboard_name, min_score, max_score)
  end
  
  def change_score_for(member, delta)    
    change_score_for_member_in(@leaderboard_name, member, delta)
  end
  
  def change_score_for_member_in(leaderboard_name, member, delta)
    @redis_connection.zincrby(leaderboard_name, delta, member)
  end
  
  def rank_for(member, use_zero_index_for_rank = false)
    rank_for_in(@leaderboard_name, member, use_zero_index_for_rank)
  end
  
  def rank_for_in(leaderboard_name, member, use_zero_index_for_rank = false)
    if use_zero_index_for_rank
      return @redis_connection.zrevrank(leaderboard_name, member)
    else
      return @redis_connection.zrevrank(leaderboard_name, member) + 1 rescue nil
    end
  end
  
  def score_for(member)
    score_for_in(@leaderboard_name, member)
  end
  
  def score_for_in(leaderboard_name, member)
    @redis_connection.zscore(leaderboard_name, member).to_f
  end

  def check_member?(member)
    check_member_in?(@leaderboard_name, member)
  end
  
  def check_member_in?(leaderboard_name, member)
    !@redis_connection.zscore(leaderboard_name, member).nil?
  end
  
  def score_and_rank_for(member, use_zero_index_for_rank = false)
    score_and_rank_for_in(@leaderboard_name, member, use_zero_index_for_rank)
  end

  def score_and_rank_for_in(leaderboard_name, member, use_zero_index_for_rank = false)
    {:member => member, :score => score_for_in(leaderboard_name, member), :rank => rank_for_in(leaderboard_name, member, use_zero_index_for_rank)}    
  end
  
  def remove_members_in_score_range(min_score, max_score)
    remove_members_in_score_range_in(@leaderboard_name, min_score, max_score)
  end
  
  def remove_members_in_score_range_in(leaderboard_name, min_score, max_score)
    @redis_connection.zremrangebyscore(leaderboard_name, min_score, max_score)
  end
  
  def leaders(current_page, with_scores = true, with_rank = true, use_zero_index_for_rank = false)
    leaders_in(@leaderboard_name, current_page, with_scores, with_rank, use_zero_index_for_rank)
  end

  def leaders_in(leaderboard_name, current_page, with_scores = true, with_rank = true, use_zero_index_for_rank = false)
    if current_page < 1
      current_page = 1
    end
    
    if current_page > total_pages
      current_page = total_pages
    end
    
    index_for_redis = current_page - 1

    starting_offset = (index_for_redis * @page_size)
    if starting_offset < 0
      starting_offset = 0
    end
    
    ending_offset = (starting_offset + @page_size) - 1
    
    raw_leader_data = @redis_connection.zrevrange(leaderboard_name, starting_offset, ending_offset, :with_scores => with_scores)
    if raw_leader_data
      massage_leader_data(leaderboard_name, raw_leader_data, with_rank, use_zero_index_for_rank)
    else
      return nil
    end
  end
  
  def around_me(member, with_scores = true, with_rank = true, use_zero_index_for_rank = false)
    around_me_in(@leaderboard_name, member, with_scores, with_rank, use_zero_index_for_rank)
  end
  
  def around_me_in(leaderboard_name, member, with_scores = true, with_rank = true, use_zero_index_for_rank = false)
    reverse_rank_for_member = @redis_connection.zrevrank(leaderboard_name, member)
    
    starting_offset = reverse_rank_for_member - (@page_size / 2)
    if starting_offset < 0
      starting_offset = 0
    end
    
    ending_offset = (starting_offset + @page_size) - 1
    
    raw_leader_data = @redis_connection.zrevrange(leaderboard_name, starting_offset, ending_offset, :with_scores => with_scores)
    if raw_leader_data
      massage_leader_data(leaderboard_name, raw_leader_data, with_rank, use_zero_index_for_rank)
    else
      return nil
    end
  end
  
  def ranked_in_list(members, with_scores = true, use_zero_index_for_rank = false)
    ranked_in_list_in(@leaderboard_name, members, with_scores, use_zero_index_for_rank)
  end
  
  def ranked_in_list_in(leaderboard_name, members, with_scores = true, use_zero_index_for_rank = false)
    ranks_for_members = []
    
    members.each do |member|
      data = {}
      data[:member] = member
      data[:rank] = rank_for_in(leaderboard_name, member, use_zero_index_for_rank)
      data[:score] = score_for_in(leaderboard_name, member) if with_scores
      
      ranks_for_members << data
    end
    
    ranks_for_members
  end
  
  private 
  
  def massage_leader_data(leaderboard_name, leaders, with_rank, use_zero_index_for_rank)
    member_attribute = true    
    leader_data = []
    
    data = {}        
    leaders.each do |leader_data_item|
      if member_attribute
        data[:member] = leader_data_item
      else
        data[:score] = leader_data_item.to_f
        data[:rank] = rank_for_in(leaderboard_name, data[:member], use_zero_index_for_rank) if with_rank
        leader_data << data
        data = {}     
      end
            
      member_attribute = !member_attribute
    end
    
    leader_data
  end
end