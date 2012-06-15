require 'spec_helper'

describe 'Leaderboard' do
  before(:each) do
    @redis_connection = Redis.new(:host => "127.0.0.1", :db => 15)
    @leaderboard = Leaderboard.new('name', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS, :host => "127.0.0.1", :db => 15)
  end

  after(:each) do
    @redis_connection.flushdb
    @leaderboard.disconnect
    @redis_connection.client.disconnect
  end

  it 'should be initialized with defaults' do
    @leaderboard.leaderboard_name.should == 'name'
    @leaderboard.page_size.should == Leaderboard::DEFAULT_PAGE_SIZE 
  end

  it 'should be able to disconnect its connection to Redis' do
    @leaderboard.disconnect.should be_nil
  end

  it 'should automatically reconnect to Redis after a disconnect' do
    @leaderboard.total_members.should be(0)
    rank_members_in_leaderboard(5)
    @leaderboard.total_members.should be(5)
    @leaderboard.disconnect.should be_nil
    @leaderboard.total_members.should be(5)
  end

  it 'should set the page size to the default page size if passed an invalid value' do
    some_leaderboard = Leaderboard.new('name', {:page_size => 0})
    
    some_leaderboard.page_size.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    some_leaderboard.disconnect
  end

  it 'should allow you to delete a leaderboard' do
    rank_members_in_leaderboard
    
    @redis_connection.exists('name').should be_true
    @leaderboard.delete_leaderboard
    @redis_connection.exists('name').should be_false
  end

  it 'should allow you to pass in an existing redis connection in the initializer' do
    @leaderboard = Leaderboard.new('name', Leaderboard::DEFAULT_OPTIONS, {:redis_connection => @redis_connection})
    rank_members_in_leaderboard
    
    @redis_connection.info["connected_clients"].to_i.should be(1)
  end

  it 'should allow you to rank a member and see that reflected in total members' do
    @leaderboard.rank_member('member', 1)

    @leaderboard.total_members.should be(1)
  end

  it 'should return the correct number of members in a given score range' do
    rank_members_in_leaderboard(5)
    
    @leaderboard.total_members_in_score_range(2, 4).should be(3)
  end

  it 'should return the correct rank when calling rank_for' do
    rank_members_in_leaderboard(5)

    @leaderboard.rank_for('member_4').should be(2)
    @leaderboard.rank_for('member_4', true).should be(1)
  end

  it 'should return the correct score when calling score_for' do
    rank_members_in_leaderboard(5)
    
    @leaderboard.score_for('member_4').should == 4
  end

  it 'should return the correct total pages' do
    rank_members_in_leaderboard(10)
    
    @leaderboard.total_pages.should be(1)
    
    @redis_connection.flushdb
    
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE + 1)
    
    @leaderboard.total_pages.should be(2)
  end

  it 'should return the correct list when calling leaders' do
    rank_members_in_leaderboard(25)
    
    @leaderboard.total_members.should be(25)

    leaders = @leaderboard.leaders(1)
        
    leaders.size.should be(25)
    leaders[0][:member].should == 'member_25'
    leaders[-2][:member].should == 'member_2'
    leaders[-1][:member].should == 'member_1'
    leaders[-1][:score].to_i.should be(1)
  end

  it 'should return the correct number of members when calling leaders with multiple pages' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)
    
    @leaderboard.total_members.should be(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    leaders = @leaderboard.leaders(1)
    leaders.size.should be(@leaderboard.page_size)
    
    leaders = @leaderboard.leaders(2)
    leaders.size.should be(@leaderboard.page_size)

    leaders = @leaderboard.leaders(3)
    leaders.size.should be(@leaderboard.page_size)

    leaders = @leaderboard.leaders(4)
    leaders.size.should be(1)
    
    leaders = @leaderboard.leaders(-5)
    leaders.size.should be(@leaderboard.page_size)
    
    leaders = @leaderboard.leaders(10)
    leaders.size.should be(1)
  end

  it 'should allow you to retrieve leaders in a given score range' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    leaders = @leaderboard.leaders_from_score_range(10, 15, {:with_scores => false, :with_rank => false})

    member_15 = {:member => 'member_15'}
    leaders[0].should == member_15

    member_10 = {:member => 'member_10'}
    leaders[5].should == member_10

    leaders = @leaderboard.leaders_from_score_range(10, 15, {:with_scores => true, :with_rank => true, :with_member_data => true})

    member_15 = {:member => 'member_15', :rank => 11, :score => 15.0, :member_data => {'member_name' => 'Leaderboard member 15'}}
    leaders[0].should == member_15

    member_10 = {:member => 'member_10', :rank => 16, :score => 10.0, :member_data => {'member_name' => 'Leaderboard member 10'}}
    leaders[5].should == member_10
  end

  it 'should allow you to retrieve leaders without scores and ranks' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.total_members.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    leaders = @leaderboard.leaders(1, {:with_scores => false, :with_rank => false})

    member_25 = {:member => 'member_25'}
    leaders[0].should == member_25
    
    member_1 = {:member => 'member_1'}
    leaders[24].should == member_1
  end

  it 'should allow you to retrieve leaders with extra data' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.total_members.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    leaders = @leaderboard.leaders(1, {:with_scores => false, :with_rank => false, :with_member_data => true})

    member_25 = {:member => 'member_25', :member_data => { "member_name" => "Leaderboard member 25" }}
    leaders[0].should == member_25
    
    member_1 = {:member => 'member_1', :member_data => { "member_name" => "Leaderboard member 1" }}
    leaders[24].should == member_1
  end

  it 'should allow you to retrieve optional member data' do
    @leaderboard.rank_member('member_id', 1, {'username' => 'member_name', 'other_data_key' => 'other_data_value'})

    @leaderboard.member_data_for('unknown_member').should == {}
    @leaderboard.member_data_for('member_id').should == {'username' => 'member_name', 'other_data_key' => 'other_data_value'}
  end

  it 'should allow you to update optional member data' do
    @leaderboard.rank_member('member_id', 1, {'username' => 'member_name'})

    @leaderboard.member_data_for('member_id').should == {'username' => 'member_name'}
    @leaderboard.update_member_data('member_id', {'other_data_key' => 'other_data_value'})
    @leaderboard.member_data_for('member_id').should == {'username' => 'member_name', 'other_data_key' => 'other_data_value'}
  end

  it 'should allow you to remove optional member data' do
    @leaderboard.rank_member('member_id', 1, {'username' => 'member_name'})

    @leaderboard.member_data_for('member_id').should == {'username' => 'member_name'}
    @leaderboard.remove_member_data('member_id')
    @leaderboard.member_data_for('member_id').should == {}
  end

  it 'should allow you to call leaders with various options that respect the defaults for the options not passed in' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE + 1)

    leaders = @leaderboard.leaders(1, :page_size => 1)
    leaders.size.should be(1)
    
    leaders = @leaderboard.leaders(1, :with_rank => false)
    leaders.size.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    member_26 = {:member => 'member_26', :score => 26}
    member_25 = {:member => 'member_25', :score => 25}
    member_24 = {:member => 'member_24', :score => 24}
    leaders[0].should == member_26
    leaders[1].should == member_25
    leaders[2].should == member_24

    leaders = @leaderboard.leaders(1, :with_scores => false)
    leaders.size.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    member_26 = {:member => 'member_26', :rank => 1}
    member_25 = {:member => 'member_25', :rank => 2}
    leaders[0].should == member_26
    leaders[1].should == member_25

    leaders = @leaderboard.leaders(1, :with_scores => false, :with_rank => false)
    leaders.size.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    member_26 = {:member => 'member_26'}
    member_25 = {:member => 'member_25'}
    leaders[0].should == member_26
    leaders[1].should == member_25

    leaders = @leaderboard.leaders(1, :with_rank => false, :page_size => 1)
    leaders.size.should be(1)
    member_26 = {:member => 'member_26', :score => 26}
    leaders[0].should == member_26
  end

  it 'should return the correct information when calling around_me' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    @leaderboard.total_members.should be(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)
    
    leaders_around_me = @leaderboard.around_me('member_30')
    (leaders_around_me.size / 2).should be(@leaderboard.page_size / 2)
    
    leaders_around_me = @leaderboard.around_me('member_1')
    leaders_around_me.size.should be(@leaderboard.page_size / 2 + 1)
    
    leaders_around_me = @leaderboard.around_me('member_76')
    (leaders_around_me.size / 2).should be(@leaderboard.page_size / 2)
  end

  it 'should return the correct information when calling ranked_in_list' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.total_members.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    
    members = ['member_1', 'member_5', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS)
    
    ranked_members.size.should be(3)

    ranked_members[0][:rank].should be(25)
    ranked_members[0][:score].should == 1

    ranked_members[1][:rank].should be(21)
    ranked_members[1][:score].should == 5

    ranked_members[2][:rank].should be(16)
    ranked_members[2][:score].should == 10
  end

  it 'should return the correct information when calling ranked_in_list without scores' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.total_members.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    
    members = ['member_1', 'member_5', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, {:with_scores => false, :with_rank => true, :use_zero_index_for_rank => false})
    
    ranked_members.size.should be(3)
    ranked_members[0][:rank].should be(25)
    ranked_members[1][:rank].should be(21)
    ranked_members[2][:rank].should be(16)
  end

  it 'should allow you to remove members' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.total_members.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.remove_member('member_1')
    
    @leaderboard.total_members.should be(Leaderboard::DEFAULT_PAGE_SIZE - 1)
    @leaderboard.rank_for('member_1').should be_nil
  end

  it 'should allow you to change the score for a member' do
    @leaderboard.rank_member('member_1', 5)    
    @leaderboard.score_for('member_1').should == 5

    @leaderboard.change_score_for('member_1', 5)    
    @leaderboard.score_for('member_1').should == 10

    @leaderboard.change_score_for('member_1', -5)    
    @leaderboard.score_for('member_1').should == 5
  end

  it 'should allow you to check if a member exists' do
    @leaderboard.rank_member('member_1', 10)
    
    @leaderboard.check_member?('member_1').should be_true
    @leaderboard.check_member?('member_2').should be_false
  end

  it 'should allow you to change the page size and have that reflected in the size of the result set' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.page_size = 5
    
    @leaderboard.total_pages.should be(5)
    @leaderboard.leaders(1).size.should be(5)
  end

  it 'should not allow you to set the page size to an invalid page size' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.page_size = 0
    @leaderboard.total_pages.should be(1)
    @leaderboard.leaders(1).size.should be(Leaderboard::DEFAULT_PAGE_SIZE)
  end

  it 'should return the correct information when calling score_and_rank_for' do
    rank_members_in_leaderboard
    
    data = @leaderboard.score_and_rank_for('member_1')
    data[:member].should == 'member_1' 
    data[:score].should == 1
    data[:rank].should == 5
  end

  it 'should allow you to remove members in a given score range' do
    rank_members_in_leaderboard
    
    @leaderboard.total_members.should be(5)
    
    @leaderboard.rank_member('cheater_1', 100)
    @leaderboard.rank_member('cheater_2', 101)
    @leaderboard.rank_member('cheater_3', 102)

    @leaderboard.total_members.should be(8)

    @leaderboard.remove_members_in_score_range(100, 102)
    
    @leaderboard.total_members.should be(5)
    
    leaders = @leaderboard.leaders(1)
    leaders.each do |leader|
      leader[:score].should be < 100
    end
  end

  it 'should allow you to merge leaderboards' do
    foo = Leaderboard.new('foo', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS, :host => "127.0.0.1", :db => 15)
    bar = Leaderboard.new('bar', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS, :host => "127.0.0.1", :db => 15)
    
    foo.rank_member('foo_1', 1)
    foo.rank_member('foo_2', 2)
    bar.rank_member('bar_1', 3)
    bar.rank_member('bar_2', 4)
    bar.rank_member('bar_3', 5)
    
    foobar_keys = foo.merge_leaderboards('foobar', ['bar'])
    foobar_keys.should be(5)
    
    foobar = Leaderboard.new('foobar', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS, :host => "127.0.0.1", :db => 15)
    foobar.total_members.should be(5)
    
    first_leader_in_foobar = foobar.leaders(1).first
    first_leader_in_foobar[:rank].should == 1
    first_leader_in_foobar[:member].should == 'bar_3'
    first_leader_in_foobar[:score].should == 5
    
    foo.disconnect
    bar.disconnect
    foobar.disconnect
  end

  it 'should allow you to intersect leaderboards' do
    foo = Leaderboard.new('foo', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS, :host => "127.0.0.1", :db => 15)
    bar = Leaderboard.new('bar', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS, :host => "127.0.0.1", :db => 15)
    
    foo.rank_member('foo_1', 1)
    foo.rank_member('foo_2', 2)
    foo.rank_member('bar_3', 6)
    bar.rank_member('bar_1', 3)
    bar.rank_member('foo_1', 4)
    bar.rank_member('bar_3', 5)
    
    foobar_keys = foo.intersect_leaderboards('foobar', ['bar'], {:aggregate => :max})    
    foobar_keys.should be(2)
    
    foobar = Leaderboard.new('foobar', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS, :host => "127.0.0.1", :db => 15)
    foobar.total_members.should be(2)
    
    first_leader_in_foobar = foobar.leaders(1).first
    first_leader_in_foobar[:rank].should == 1
    first_leader_in_foobar[:member].should == 'bar_3'
    first_leader_in_foobar[:score].should == 6
    
    foo.disconnect
    bar.disconnect
    foobar.disconnect
  end

  it 'should respect the with_scores option in the massage_leader_data method' do
    rank_members_in_leaderboard(25)
    
    @leaderboard.total_members.should be(25)

    leaders = @leaderboard.leaders(1, {:with_scores => false, :with_rank => false})
    leaders[0][:member].should_not be_nil
    leaders[0][:score].should be_nil
    leaders[0][:rank].should be_nil
    
    @leaderboard.page_size = 25
    leaders = @leaderboard.leaders(1, {:with_scores => false, :with_rank => false})
    leaders.size.should be(25)

    @leaderboard.page_size = Leaderboard::DEFAULT_PAGE_SIZE
    leaders = @leaderboard.leaders(1, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS)
    leaders[0][:member].should_not be_nil
    leaders[0][:score].should_not be_nil
    leaders[0][:rank].should_not be_nil
    
    @leaderboard.page_size = 25
    leaders = @leaderboard.leaders(1, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS)
    leaders.size.should be(25)
  end

  it 'should return the correct number of pages when calling total_pages_in page size option' do
    rank_members_in_leaderboard(25)
    
    @leaderboard.total_pages_in(@leaderboard.leaderboard_name).should be(1)
    @leaderboard.total_pages_in(@leaderboard.leaderboard_name, 5).should be(5)
  end

  it 'should return the correct number of members when calling leaders with a page_size option' do
    rank_members_in_leaderboard(25)
    
    @leaderboard.leaders(1, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 5})).size.should be(5)
    @leaderboard.leaders(1, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 10})).size.should be(10)
    @leaderboard.leaders(2, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 10})).size.should be(10)
    @leaderboard.leaders(3, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 10})).size.should be(5)
  end

  it 'should return the correct number of members when calling around_me with a page_size options' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)
    
    leaders_around_me = @leaderboard.around_me('member_30', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 3}))
    leaders_around_me.size.should be(3)
    leaders_around_me[0][:member].should == 'member_31'
    leaders_around_me[2][:member].should == 'member_29'
  end

  it 'should return the correct information when calling percentile_for' do
    rank_members_in_leaderboard(12)
    
    @leaderboard.percentile_for('member_1').should == 0
    @leaderboard.percentile_for('member_2').should == 9
    @leaderboard.percentile_for('member_3').should == 17
    @leaderboard.percentile_for('member_4').should == 25
    @leaderboard.percentile_for('member_12').should == 92
  end

  it 'should not throw an exception when calling around_me with a member not in the leaderboard' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)
    
    leaders_around_me = @leaderboard.around_me('jones', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 3}))
    leaders_around_me.size.should be(0)
  end

  it 'should not throw an exception when calling score_and_rank_for with a member not in the leaderboard' do
    score_and_rank_for_member = @leaderboard.score_and_rank_for('jones')
  
    score_and_rank_for_member[:member].should == 'jones'
    score_and_rank_for_member[:score].should == 0.0
    score_and_rank_for_member[:rank].should be_nil
  end

  it 'should not throw an exception when calling ranked_in_list with a member not in the leaderboard' do
    rank_members_in_leaderboard

    members = ['member_1', 'member_5', 'jones']
    ranked_members = @leaderboard.ranked_in_list(members)

    ranked_members.size.should be(3)
    ranked_members[2][:rank].should be_nil
  end

  it 'should not throw an exception when calling percentile_for with a member not in the leaderboard' do
    percentile = @leaderboard.percentile_for('jones')

    percentile.should be_nil
  end

  it 'should allow you to change the score for a member not in the leaderboard' do
    @leaderboard.score_for('jones').should == 0.0
    @leaderboard.change_score_for('jones', 5)
    @leaderboard.score_for('jones').should == 5.0
  end

  it 'should return the correct page when calling page_for a given member in the leaderboard' do
    @leaderboard.page_for('jones').should be(0)

    rank_members_in_leaderboard(20)

    @leaderboard.page_for('member_17').should be(1)
    @leaderboard.page_for('member_11').should be(1)
    @leaderboard.page_for('member_10').should be(1)
    @leaderboard.page_for('member_1').should be(1)

    @leaderboard.page_for('member_17', 10).should be(1)
    @leaderboard.page_for('member_11', 10).should be(1)
    @leaderboard.page_for('member_10', 10).should be(2)
    @leaderboard.page_for('member_1', 10).should be(2)
  end

  it 'should allow you to rank multiple members with a variable number of arguments' do
    @leaderboard.total_members.should be(0)
    @leaderboard.rank_members('member_1', 1, 'member_10', 10)
    @leaderboard.total_members.should be(2)
    @leaderboard.leaders(1).first[:member].should == 'member_10'
  end

  it 'should allow you to rank multiple members with an array' do
    @leaderboard.total_members.should be(0)
    @leaderboard.rank_members(['member_1', 1, 'member_10', 10])
    @leaderboard.total_members.should be(2)
    @leaderboard.leaders(1).first[:member].should == 'member_10'
  end

  it 'should allow you to set reverse after creating a leaderboard to see results in highest-to-lowest or lowest-to-highest order' do
    rank_members_in_leaderboard(25)

    leaders = @leaderboard.leaders(1)
        
    leaders.size.should be(25)
    leaders[0][:member].should == 'member_25'
    leaders[-2][:member].should == 'member_2'
    leaders[-1][:member].should == 'member_1'
    leaders[-1][:score].to_i.should be(1)

    @leaderboard.reverse = true

    leaders = @leaderboard.leaders(1)
        
    leaders.size.should be(25)
    leaders[0][:member].should == 'member_1'
    leaders[-2][:member].should == 'member_24'
    leaders[-1][:member].should == 'member_25'
    leaders[-1][:score].to_i.should be(25)
  end
end