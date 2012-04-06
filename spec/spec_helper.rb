require 'rspec'
require 'leaderboard'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  def rank_members_in_leaderboard(members_to_add = 5)
    1.upto(members_to_add) do |index|
      @leaderboard.rank_member("member_#{index}", index)
    end
  end
end
