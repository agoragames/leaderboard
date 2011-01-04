require 'redis'

class Leaderboard
  VERSION = '1.0.0'.freeze
  DEFAULT_PAGE_SIZE = 25
  
  def initialize(leaderboard_name, host = 'localhost', port = 6379, page_size = DEFAULT_PAGE_SIZE)
    @leaderboard_name = leaderboard_name
    @host = host
    @port = port
    
    if page_size < 1
      page_size = DEFAULT_PAGE_SIZE
    end
    
    @page_size = page_size
    
    @redis_connection = Redis.new(:host => @host, :port => @port)
  end
    
  def host
    @host
  end
  
  def port
    @port
  end
  
  def leaderboard_name
    @leaderboard_name
  end
  
  def page_size
    @page_size
  end
  
  def add_member(member, score)
    @redis_connection.zadd(@leaderboard_name, score, member)
  end
  
  def total_members
    @redis_connection.zcard(@leaderboard_name)
  end
  
  def total_pages
    (total_members / @page_size.to_f).ceil
  end
  
  def total_members_in_score_range(min_score, max_score)
    @redis_connection.zcount(@leaderboard_name, min_score, max_score)
  end
  
  def rank_for(member)
    @redis_connection.zrevrank(@leaderboard_name, member)
  end
  
  def score_for(member)
    @redis_connection.zscore(@leaderboard_name, member).to_f
  end

  def leaders(current_page, with_scores = true)
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
    
    @redis_connection.zrevrange(@leaderboard_name, starting_offset, ending_offset, :with_scores => with_scores)
  end
  
  def around_me(member, with_scores = true)
    reverse_rank_for_member = @redis_connection.zrevrank(@leaderboard_name, member)
    
    starting_offset = reverse_rank_for_member - (@page_size / 2)
    if starting_offset < 0
      starting_offset = 0
    end
    
    ending_offset = (starting_offset + @page_size) - 1
    
    @redis_connection.zrevrange(@leaderboard_name, starting_offset, ending_offset, :with_scores => with_scores)
  end
  
  def ranked_in_list(members, with_scores = false)
    ranks_for_members = []
    
    members.each do |member|
      data = []
      data << member
      data << rank_for(member)
      data << score_for(member) if with_scores
      
      ranks_for_members << data
    end
    
    ranks_for_members
  end
end