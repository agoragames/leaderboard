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
end