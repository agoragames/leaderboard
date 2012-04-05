require 'rspec'
require 'leaderboard'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  def rank_members_in_leaderboard(members_to_add = 5)
    1.upto(members_to_add) do |index|
      @leaderboard.rank_member("member_#{index}", index)
    end
  end

  config.before(:each) do
    @redis_connection = Redis.new(:host => "127.0.0.1")
    @leaderboard = Leaderboard.new('name', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS, :host => "127.0.0.1")
  end

  config.after(:each) do
    @redis_connection.flushdb
    @leaderboard.disconnect
    @redis_connection.client.disconnect
  end
end
