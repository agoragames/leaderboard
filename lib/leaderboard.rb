require 'redis'

class Leaderboard
  VERSION = '2.0.0'.freeze
  
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
    
    @redis_connection = redis_options[:redis_connection]
    unless @redis_connection.nil?
      redis_options.delete(:redis_connection)
    end
    
    redis_options = redis_options.dup
    redis_options[:host] ||= @host
    redis_options[:port] ||= @port    
    
    @redis_options = redis_options
    
    @redis_connection = Redis.new(@redis_options) if @redis_connection.nil?
  end
      
  def page_size=(page_size)
    page_size = DEFAULT_PAGE_SIZE if page_size < 1

    @page_size = page_size
  end
  
  def disconnect
    @redis_connection.client.disconnect
  end
  
  def delete_leaderboard
    delete_leaderboard_named(@leaderboard_name)
  end
  
  def delete_leaderboard_named(leaderboard_name)
    @redis_connection.del(leaderboard_name)
  end
      
  def rank_member(member, score)
    rank_member_in(@leaderboard_name, member, score)
  end

  def rank_member_in(leaderboard_name, member, score)
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
  
  def total_pages_in(leaderboard_name, page_size = nil)
    page_size ||= @page_size.to_f
    (total_members_in(leaderboard_name) / page_size.to_f).ceil
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
    result = @redis_connection.multi do |transaction|
      transaction.zscore(leaderboard_name, member)
      transaction.zrevrank(leaderboard_name, member)
    end
    
    result[0] = result[0].to_f
    if !use_zero_index_for_rank
      result[1] = result[1] + 1 rescue nil
    end
    
    {:member => member, :score => result[0], :rank => result[1]}    
  end
  
  def remove_members_in_score_range(min_score, max_score)
    remove_members_in_score_range_in(@leaderboard_name, min_score, max_score)
  end
  
  def remove_members_in_score_range_in(leaderboard_name, min_score, max_score)
    @redis_connection.zremrangebyscore(leaderboard_name, min_score, max_score)
  end
  
  def leaders(current_page, with_scores = true, with_rank = true, use_zero_index_for_rank = false, page_size = nil)
    leaders_in(@leaderboard_name, current_page, with_scores, with_rank, use_zero_index_for_rank, page_size)
  end

  def leaders_in(leaderboard_name, current_page, with_scores = true, with_rank = true, use_zero_index_for_rank = false, page_size = nil)
    if current_page < 1
      current_page = 1
    end
    
    page_size ||= @page_size

    if current_page > total_pages_in(leaderboard_name, page_size)
      current_page = total_pages_in(leaderboard_name, page_size)
    end
    
    index_for_redis = current_page - 1

    starting_offset = (index_for_redis * page_size)
    if starting_offset < 0
      starting_offset = 0
    end
    
    ending_offset = (starting_offset + page_size) - 1
        
    raw_leader_data = @redis_connection.zrevrange(leaderboard_name, starting_offset, ending_offset, :with_scores => false)    
    if raw_leader_data
      return ranked_in_list_in(leaderboard_name, raw_leader_data, with_scores, with_rank, use_zero_index_for_rank)
    else
      return []
    end
  end
  
  def around_me(member, with_scores = true, with_rank = true, use_zero_index_for_rank = false, page_size = nil)
    around_me_in(@leaderboard_name, member, with_scores, with_rank, use_zero_index_for_rank, page_size)
  end
  
  def around_me_in(leaderboard_name, member, with_scores = true, with_rank = true, use_zero_index_for_rank = false, page_size = nil)
    reverse_rank_for_member = @redis_connection.zrevrank(leaderboard_name, member)
    
    page_size ||= @page_size
    
    starting_offset = reverse_rank_for_member - (page_size / 2)
    if starting_offset < 0
      starting_offset = 0
    end
        
    ending_offset = (starting_offset + page_size) - 1
    
    raw_leader_data = @redis_connection.zrevrange(leaderboard_name, starting_offset, ending_offset, :with_scores => false)
    if raw_leader_data
      return ranked_in_list_in(leaderboard_name, raw_leader_data, with_scores, with_rank, use_zero_index_for_rank)
    else
      return []
    end
  end
  
  def ranked_in_list(members, with_scores = true, with_rank = true, use_zero_index_for_rank = false)
    ranked_in_list_in(@leaderboard_name, members, with_scores, with_rank, use_zero_index_for_rank)
  end
  
  def ranked_in_list_in(leaderboard_name, members, with_scores = true, with_rank = true, use_zero_index_for_rank = false)
    ranks_for_members = []
    
    responses = @redis_connection.multi do |transaction|
      members.each do |member|
        transaction.zrevrank(leaderboard_name, member)        
        transaction.zscore(leaderboard_name, member) if with_scores
      end
    end
    
    members.each_with_index do |member, index|
      data = {}
      data[:member] = member
      if with_scores
        if with_rank
          if use_zero_index_for_rank
            data[:rank] = responses[index * 2]
          else
            data[:rank] = responses[index * 2] + 1
          end
        end

        data[:score] = responses[index * 2 + 1].to_f
      else
        if with_rank
          if use_zero_index_for_rank
            data[:rank] = responses[index]
          else
            data[:rank] = responses[index] + 1
          end
        end
      end
      
      ranks_for_members << data
    end
    
    ranks_for_members
  end
  
  # Merge leaderboards given by keys with this leaderboard into destination
  def merge_leaderboards(destination, keys, options = {:aggregate => :sum})
    @redis_connection.zunionstore(destination, keys.insert(0, @leaderboard_name), options)
  end
  
  # Intersect leaderboards given by keys with this leaderboard into destination
  def intersect_leaderboards(destination, keys, options = {:aggregate => :sum})
    @redis_connection.zinterstore(destination, keys.insert(0, @leaderboard_name), options)
  end
end