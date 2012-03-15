require 'rubygems'
require 'test/unit'

require 'leaderboard'

class LeaderboardTest < Test::Unit::TestCase

  def test_version
    assert_equal '2.0.5', Leaderboard::VERSION
  end

  private
  
  def rank_members_in_leaderboard(members_to_add = 5)
    1.upto(members_to_add) do |index|
      @leaderboard.rank_member("member_#{index}", index)
    end
  end
end