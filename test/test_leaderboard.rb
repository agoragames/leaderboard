require 'helper'

class TestLeaderboard < Test::Unit::TestCase
  def setup    
    @leaderboard = Leaderboard.new('name')
    @redis_connection = Redis.new
  end
  
  def teardown
    @redis_connection.flushdb
    @leaderboard.disconnect
    @redis_connection.client.disconnect
  end
  
  def test_version
    assert_equal '2.0.0', Leaderboard::VERSION
  end
  
  def test_initialize_with_defaults  
    assert_equal 'name', @leaderboard.leaderboard_name
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE, @leaderboard.page_size
  end
  
  def test_disconnect
    assert_equal nil, @leaderboard.disconnect
  end
  
  def test_will_automatically_reconnect_after_a_disconnect
    assert_equal 0, @leaderboard.total_members
    rank_members_in_leaderboard(5)
    assert_equal 5, @leaderboard.total_members
    assert_equal nil, @leaderboard.disconnect
    assert_equal 5, @leaderboard.total_members
  end
  
  def test_page_size_is_default_page_size_if_set_to_invalid_value
    some_leaderboard = Leaderboard.new('name', {:page_size => 0})
    
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE, some_leaderboard.page_size
    some_leaderboard.disconnect
  end
  
  def test_delete_leaderboard
    rank_members_in_leaderboard
    
    assert_equal true, @redis_connection.exists('name')
    @leaderboard.delete_leaderboard
    assert_equal false, @redis_connection.exists('name')    
  end
  
  def test_can_pass_existing_redis_connection_to_initializer
    @leaderboard = Leaderboard.new('name', Leaderboard::DEFAULT_OPTIONS, {:redis_connection => @redis_connection})
    rank_members_in_leaderboard
    
    assert_equal 1, @redis_connection.info["connected_clients"].to_i
  end
  
  def test_rank_member_and_total_members
    @leaderboard.rank_member('member', 1)

    assert_equal 1, @leaderboard.total_members
  end
  
  def test_total_members_in_score_range
    rank_members_in_leaderboard(5)
    
    assert_equal 3, @leaderboard.total_members_in_score_range(2, 4)
  end
  
  def test_rank_for
    rank_members_in_leaderboard(5)

    assert_equal 2, @leaderboard.rank_for('member_4')
    assert_equal 1, @leaderboard.rank_for('member_4', true)
  end
  
  def test_score_for
    rank_members_in_leaderboard(5)
    
    assert_equal 4, @leaderboard.score_for('member_4')
  end
  
  def test_total_pages
    rank_members_in_leaderboard(10)
    
    assert_equal 1, @leaderboard.total_pages
    
    @redis_connection.flushdb
    
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE + 1)
    
    assert_equal 2, @leaderboard.total_pages
  end
  
  def test_leaders
    rank_members_in_leaderboard(25)
    
    assert_equal 25, @leaderboard.total_members

    leaders = @leaderboard.leaders(1)
        
    assert_equal 25, leaders.size
    assert_equal 'member_25', leaders[0][:member]
    assert_equal 'member_2', leaders[-2][:member]
    assert_equal 'member_1', leaders[-1][:member]
    assert_equal 1, leaders[-1][:score].to_i
  end
  
  def test_leaders_with_multiple_pages
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)
    
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
  
  def test_leaders_without_retrieving_scores_and_ranks
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE, @leaderboard.total_members
    leaders = @leaderboard.leaders(1, {:with_scores => false, :with_ranks => false})

    member_25 = {:member => 'member_25'}
    assert_equal member_25, leaders[0]
    
    member_1 = {:member => 'member_1'}
    assert_equal member_1, leaders[24]
  end
  
  def test_around_me
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    assert_equal Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1, @leaderboard.total_members
    
    leaders_around_me = @leaderboard.around_me('member_30')
    assert_equal @leaderboard.page_size / 2, leaders_around_me.size / 2
    
    leaders_around_me = @leaderboard.around_me('member_1')
    assert_equal @leaderboard.page_size / 2 + 1, leaders_around_me.size
    
    leaders_around_me = @leaderboard.around_me('member_76')
    assert_equal @leaderboard.page_size / 2, leaders_around_me.size / 2
  end
  
  def test_ranked_in_list
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE, @leaderboard.total_members
    
    members = ['member_1', 'member_5', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS)
    
    assert_equal 3, ranked_members.size

    assert_equal 25, ranked_members[0][:rank]
    assert_equal 1, ranked_members[0][:score]

    assert_equal 21, ranked_members[1][:rank]
    assert_equal 5, ranked_members[1][:score]

    assert_equal 16, ranked_members[2][:rank]
    assert_equal 10, ranked_members[2][:score]    
  end
  
  def test_ranked_in_list_without_scores
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE, @leaderboard.total_members
    
    members = ['member_1', 'member_5', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, {:with_scores => false, :with_rank => true, :use_zero_index_for_rank => false})
    
    assert_equal 3, ranked_members.size

    assert_equal 25, ranked_members[0][:rank]

    assert_equal 21, ranked_members[1][:rank]

    assert_equal 16, ranked_members[2][:rank]
  end
  
  def test_remove_member
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE, @leaderboard.total_members
    
    @leaderboard.remove_member('member_1')
    
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE - 1, @leaderboard.total_members
    assert_nil @leaderboard.rank_for('member_1')
  end
  
  def test_change_score_for
    @leaderboard.rank_member('member_1', 5)    
    assert_equal 5, @leaderboard.score_for('member_1')

    @leaderboard.change_score_for('member_1', 5)    
    assert_equal 10, @leaderboard.score_for('member_1')

    @leaderboard.change_score_for('member_1', -5)    
    assert_equal 5, @leaderboard.score_for('member_1')
  end
  
  def test_check_member
    @leaderboard.rank_member('member_1', 10)
    
    assert_equal true, @leaderboard.check_member?('member_1')
    assert_equal false, @leaderboard.check_member?('member_2')
  end
  
  def test_can_change_page_size_and_have_it_reflected_in_size_of_result_set
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.page_size = 5
    
    assert_equal 5, @leaderboard.total_pages
    assert_equal 5, @leaderboard.leaders(1).size
  end
  
  def test_cannot_set_page_size_to_invalid_page_size
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.page_size = 0
    assert_equal 1, @leaderboard.total_pages
    assert_equal Leaderboard::DEFAULT_PAGE_SIZE, @leaderboard.leaders(1).size
  end
  
  def test_score_and_rank_for
    rank_members_in_leaderboard
    
    data = @leaderboard.score_and_rank_for('member_1')
    assert_equal 'member_1', data[:member]
    assert_equal 1, data[:score]
    assert_equal 5, data[:rank]
  end
  
  def test_remove_members_in_score_range
    rank_members_in_leaderboard
    
    assert_equal 5, @leaderboard.total_members
    
    @leaderboard.rank_member('cheater_1', 100)
    @leaderboard.rank_member('cheater_2', 101)
    @leaderboard.rank_member('cheater_3', 102)

    assert_equal 8, @leaderboard.total_members

    @leaderboard.remove_members_in_score_range(100, 102)
    
    assert_equal 5, @leaderboard.total_members
    
    leaders = @leaderboard.leaders(1)
    leaders.each do |leader|
      assert leader[:score] < 100
    end
  end
  
  def test_merge_leaderboards
    foo = Leaderboard.new('foo')    
    bar = Leaderboard.new('bar')
    
    foo.rank_member('foo_1', 1)
    foo.rank_member('foo_2', 2)
    bar.rank_member('bar_1', 3)
    bar.rank_member('bar_2', 4)
    bar.rank_member('bar_3', 5)
    
    foobar_keys = foo.merge_leaderboards('foobar', ['bar'])
    assert_equal 5, foobar_keys
    
    foobar = Leaderboard.new('foobar')  
    assert_equal 5, foobar.total_members
    
    first_leader_in_foobar = foobar.leaders(1).first
    assert_equal 1, first_leader_in_foobar[:rank]
    assert_equal 'bar_3', first_leader_in_foobar[:member]
    assert_equal 5, first_leader_in_foobar[:score]
    
    foo.disconnect
    bar.disconnect
    foobar.disconnect
  end
  
  def test_intersect_leaderboards
    foo = Leaderboard.new('foo')
    bar = Leaderboard.new('bar')
    
    foo.rank_member('foo_1', 1)
    foo.rank_member('foo_2', 2)
    foo.rank_member('bar_3', 6)
    bar.rank_member('bar_1', 3)
    bar.rank_member('foo_1', 4)
    bar.rank_member('bar_3', 5)
    
    foobar_keys = foo.intersect_leaderboards('foobar', ['bar'], {:aggregate => :max})    
    assert_equal 2, foobar_keys
    
    foobar = Leaderboard.new('foobar')
    assert_equal 2, foobar.total_members
    
    first_leader_in_foobar = foobar.leaders(1).first
    assert_equal 1, first_leader_in_foobar[:rank]
    assert_equal 'bar_3', first_leader_in_foobar[:member]
    assert_equal 6, first_leader_in_foobar[:score]
    
    foo.disconnect
    bar.disconnect
    foobar.disconnect
  end
  
  def test_massage_leader_data_respects_with_scores
    rank_members_in_leaderboard(25)
    
    assert_equal 25, @leaderboard.total_members

    leaders = @leaderboard.leaders(1, {:with_scores => false, :with_rank => false})
    assert_not_nil leaders[0][:member]
    assert_nil leaders[0][:score]
    assert_nil leaders[0][:rank]
    
    @leaderboard.page_size = 25
    leaders = @leaderboard.leaders(1, {:with_scores => false, :with_rank => false})
    assert_equal 25, leaders.size

    @leaderboard.page_size = Leaderboard::DEFAULT_PAGE_SIZE
    leaders = @leaderboard.leaders(1, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS)
    assert_not_nil leaders[0][:member]
    assert_not_nil leaders[0][:score]
    assert_not_nil leaders[0][:rank]
    
    @leaderboard.page_size = 25
    leaders = @leaderboard.leaders(1, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS)
    assert_equal 25, leaders.size
  end
  
  def test_total_pages_in_with_new_page_size
    rank_members_in_leaderboard(25)
    
    assert_equal 1, @leaderboard.total_pages_in(@leaderboard.leaderboard_name)
    assert_equal 5, @leaderboard.total_pages_in(@leaderboard.leaderboard_name, 5)
  end
  
  def test_leaders_call_with_new_page_size
    rank_members_in_leaderboard(25)
    
    assert_equal 5, @leaderboard.leaders(1, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 5})).size
    assert_equal 10, @leaderboard.leaders(1, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 10})).size
    assert_equal 10, @leaderboard.leaders(2, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 10})).size
    assert_equal 5, @leaderboard.leaders(3, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 10})).size
  end
  
  def test_around_me_call_with_new_page_size
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)
    
    leaders_around_me = @leaderboard.around_me('member_30', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 3}))
    assert_equal 3, leaders_around_me.size
    assert_equal 'member_31', leaders_around_me[0][:member]
    assert_equal 'member_29', leaders_around_me[2][:member]
  end
  
  private
  
  def rank_members_in_leaderboard(members_to_add = 5)
    1.upto(members_to_add) do |index|
      @leaderboard.rank_member("member_#{index}", index)
    end
  end
end