require 'helper'

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
end
