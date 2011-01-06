require 'helper'

class TestLeaderboard < Test::Unit::TestCase
  def setup
    @leaderboard = Leaderboard.new('name')
    @redis_connection = Redis.new
  end
  
  def teardown
    @redis_connection.flushdb
  end
  
  def test_version
    assert_equal '1.0.1', Leaderboard::VERSION
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
  
  def test_add_member_and_total_members
    @leaderboard.add_member('member', 1)

    assert_equal 1, @leaderboard.total_members
  end
  
  def test_total_members_in_score_range
    add_members_to_leaderboard(5)
    
    assert_equal 3, @leaderboard.total_members_in_score_range(2, 4)
  end
  
  def test_rank_for
    add_members_to_leaderboard(5)

    assert_equal 2, @leaderboard.rank_for('member_4')
    assert_equal 1, @leaderboard.rank_for('member_4', true)
  end
  
  def test_score_for
    add_members_to_leaderboard(5)
    
    assert_equal 4, @leaderboard.score_for('member_4')
  end
  
  def test_total_pages
    add_members_to_leaderboard(10)
    
    assert_equal 1, @leaderboard.total_pages
    
    @redis_connection.flushdb
    
    add_members_to_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE + 1)
    
    assert_equal 2, @leaderboard.total_pages
  end
  
  def test_leaders
    add_members_to_leaderboard(25)
    
    assert_equal 25, @leaderboard.total_members

    leaders = @leaderboard.leaders(1)
        
    assert_equal 25, leaders.size
    assert_equal 'member_25', leaders[0][:member]
    assert_equal 'member_2', leaders[-2][:member]
    assert_equal 'member_1', leaders[-1][:member]
    assert_equal 1, leaders[-1][:score].to_i
  end
  
  def test_leaders_with_multiple_pages
    add_members_to_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)
    
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1, @leaderboard.total_members

    leaders = @leaderboard.leaders(1)
    assert_equal @leaderboard.page_size, leaders.size
    
    leaders = @leaderboard.leaders(2)
    assert_equal @leaderboard.page_size, leaders.size

    leaders = @leaderboard.leaders(3)
    assert_equal @leaderboard.page_size, leaders.size

    leaders = @leaderboard.leaders(4)
    assert_equal 1, leaders.size
    
    leaders = @leaderboard.leaders(-5)
    assert_equal @leaderboard.page_size, leaders.size
    
    leaders = @leaderboard.leaders(10)
    assert_equal 1, leaders.size
  end
  
  def test_around_me
    add_members_to_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    assert_equal Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1, @leaderboard.total_members
    
    leaders_around_me = @leaderboard.around_me('member_30')
    assert_equal @leaderboard.page_size / 2, leaders_around_me.size / 2
    
    leaders_around_me = @leaderboard.around_me('member_1')
    assert_equal @leaderboard.page_size / 2 + 1, leaders_around_me.size
    
    leaders_around_me = @leaderboard.around_me('member_76')
    assert_equal @leaderboard.page_size / 2, leaders_around_me.size / 2
  end
  
  def test_ranked_in_list
    add_members_to_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE, @leaderboard.total_members
    
    members = ['member_1', 'member_5', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, true)
    
    assert_equal 3, ranked_members.size

    assert_equal 25, ranked_members[0][:rank]
    assert_equal 1, ranked_members[0][:score]

    assert_equal 21, ranked_members[1][:rank]
    assert_equal 5, ranked_members[1][:score]

    assert_equal 16, ranked_members[2][:rank]
    assert_equal 10, ranked_members[2][:score]    
  end
  
  def test_remove_member
    add_members_to_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE, @leaderboard.total_members
    
    @leaderboard.remove_member('member_1')
    
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE - 1, @leaderboard.total_members
    assert_nil @leaderboard.rank_for('member_1')
  end
  
  def test_change_score_for
    @leaderboard.add_member('member_1', 5)    
    assert_equal 5, @leaderboard.score_for('member_1')

    @leaderboard.change_score_for('member_1', 5)    
    assert_equal 10, @leaderboard.score_for('member_1')

    @leaderboard.change_score_for('member_1', -5)    
    assert_equal 5, @leaderboard.score_for('member_1')
  end
  
  def test_can_change_page_size_and_have_it_reflected_in_size_of_result_set
    add_members_to_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.page_size = 5
    assert_equal 5, @leaderboard.total_pages
    assert_equal 5, @leaderboard.leaders(1).size
  end
  
  private
  
  def add_members_to_leaderboard(members_to_add = 5)
    1.upto(members_to_add) do |index|
      @leaderboard.add_member("member_#{index}", index)
    end
  end
end
