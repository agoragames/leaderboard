require 'helper'

class TestLeaderboard < Test::Unit::TestCase
  def test_version
    assert_equal '1.0.0', Leaderboard::VERSION
  end
end
