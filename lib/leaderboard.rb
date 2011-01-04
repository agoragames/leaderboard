require 'redis'

class Leaderboard
  VERSION = '1.0.0'.freeze
  
  def initialize(leaderboard_name, host = 'localhost', port = 6379)
    @leaderboard_name = leaderboard_name
    @host = host
    @port = port
    
    @redis_server = Redis.new(:host => @host, :port => @port)
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
  
  def add_member(member, score)
    @redis_server.zadd(@leaderboard_name, score, member)
  end
  
  def total_members
    @redis_server.zcard(@leaderboard_name)
  end
  
  def total_members_in_score_range(min_score, max_score)
    @redis_server.zcount(@leaderboard_name, min_score, max_score)
  end  
end