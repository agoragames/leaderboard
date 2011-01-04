require 'helper'
require 'mocha'

class TestLeaderboard < Test::Unit::TestCase
  def setup
    @leaderboard = Leaderboard.new('name')
  end
  
  def teardown
    @leaderboard.flush
  end
  
  def test_version
    assert_equal '1.0.0', Leaderboard::VERSION
  end
  
  def test_initialize_with_defaults  
    assert_equal 'name', @leaderboard.leaderboard_name
    assert_equal 'localhost', @leaderboard.host
    assert_equal 6379, @leaderboard.port
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE, @leaderboard.page_size
  end
  
  def test_page_size_is_default_page_size_if_set_to_invalid_value
    @leaderboard = Leaderboard.new('name', 'localhost', 6379, 0)
    
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE, @leaderboard.page_size
  end
  
  def test_add_member
    @leaderboard.expects(:add_member).at_least_once
    @leaderboard.add_member('member', 1)
  end
  
  def test_total_members
    @leaderboard.add_member('member', 1)
    
    assert_equal 1, @leaderboard.total_members
  end

  def test_total_members_in_score_range
    add_members_to_leaderboard(5)
    
    assert_equal 3, @leaderboard.total_members_in_score_range(2, 4)
  end
  
  def test_rank_for
    add_members_to_leaderboard(5)
    
    assert_equal 1, @leaderboard.rank_for('member_4')
  end
  
  def test_score_for
    add_members_to_leaderboard(5)
    
    assert_equal 4, @leaderboard.score_for('member_4')
  end
  
  def test_total_pages
    add_members_to_leaderboard(10)
    
    assert_equal 1, @leaderboard.total_pages
    
    @leaderboard.flush
    add_members_to_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE + 1)
    
    assert_equal 2, @leaderboard.total_pages
  end
  
  private
  
  def add_members_to_leaderboard(members_to_add = 5)
    1.upto(members_to_add) do |index|
      @leaderboard.add_member("member_#{index}", index)
    end
  end
end
