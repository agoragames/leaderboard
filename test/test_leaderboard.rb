require 'helper'
require 'mocha'

class TestLeaderboard < Test::Unit::TestCase
  def test_version
    assert_equal '1.0.0', Leaderboard::VERSION
  end
  
  def test_initialize_with_defaults
    leaderboard = Leaderboard.new('name')
    
    assert_equal 'name', leaderboard.leaderboard_name
    assert_equal 'localhost', leaderboard.host
    assert_equal 6379, leaderboard.port
  end
  
  def test_add_member
    leaderboard = Leaderboard.new('name')
    
    leaderboard.expects(:add_member).at_least_once
    leaderboard.add_member('david', 1)
  end
  
  def test_total_members
    leaderboard = Leaderboard.new('name')
    
    leaderboard.add_member('david', 1)
    
    assert_equal 1, leaderboard.total_members
  end

  def test_total_members_in_score_range
    leaderboard = Leaderboard.new('name')
    
    leaderboard.add_member('david', 1)
    
    assert_equal 1, leaderboard.total_members_in_score_range(1, 1)
  end
end
