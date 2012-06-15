require 'spec_helper'

describe 'Leaderboard (reverse option)' do
  before(:each) do
    @redis_connection = Redis.new(:host => "127.0.0.1", :db => 15)
    @leaderboard = Leaderboard.new('name', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:reverse => true}), :host => "127.0.0.1", :db => 15)
  end
  
  after(:each) do
    @redis_connection.flushdb
    @leaderboard.disconnect
    @redis_connection.client.disconnect
  end

  it 'should return the correct rank when calling rank_for' do
    rank_members_in_leaderboard(5)

    @leaderboard.rank_for('member_4').should be(4)
    @leaderboard.rank_for('member_4', true).should be(3)
  end

  it 'should return the correct list when calling leaders' do
    rank_members_in_leaderboard(25)
    
    @leaderboard.total_members.should be(25)

    leaders = @leaderboard.leaders(1)
        
    leaders.size.should be(25)
    leaders[0][:member].should == 'member_1'
    leaders[-2][:member].should == 'member_24'
    leaders[-1][:member].should == 'member_25'
    leaders[-1][:score].to_i.should be(25)
  end

  it 'should allow you to retrieve leaders in a given score range' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    leaders = @leaderboard.leaders_from_score_range(10, 15, {:with_scores => false, :with_rank => false})

    member_10 = {:member => 'member_10'}
    leaders[0].should == member_10

    member_15 = {:member => 'member_15'}
    leaders[5].should == member_15

    leaders = @leaderboard.leaders_from_score_range(10, 15, {:with_scores => true, :with_rank => true, :with_member_data => true})

    member_10 = {:member => 'member_10', :rank => 10, :score => 10.0, :member_data => {'member_name' => 'Leaderboard member 10'}}
    leaders[0].should == member_10

    member_15 = {:member => 'member_15', :rank => 15, :score => 15.0, :member_data => {'member_name' => 'Leaderboard member 15'}}
    leaders[5].should == member_15
  end

  it 'should allow you to retrieve leaders without scores and ranks' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.total_members.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    leaders = @leaderboard.leaders(1, {:with_scores => false, :with_rank => false})

    member_1 = {:member => 'member_1'}
    leaders[0].should == member_1
    
    member_25 = {:member => 'member_25'}
    leaders[24].should == member_25
  end

  it 'should allow you to call leaders with various options that respect the defaults for the options not passed in' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE + 1)

    leaders = @leaderboard.leaders(1, :page_size => 1)
    leaders.size.should be(1)
    
    leaders = @leaderboard.leaders(1, :with_rank => false)
    leaders.size.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    member_1 = {:member => 'member_1', :score => 1}
    member_2 = {:member => 'member_2', :score => 2}
    member_3 = {:member => 'member_3', :score => 3}
    leaders[0].should == member_1
    leaders[1].should == member_2
    leaders[2].should == member_3

    leaders = @leaderboard.leaders(1, :with_scores => false)
    leaders.size.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    member_1 = {:member => 'member_1', :rank => 1}
    member_2 = {:member => 'member_2', :rank => 2}
    leaders[0].should == member_1
    leaders[1].should == member_2

    leaders = @leaderboard.leaders(1, :with_scores => false, :with_rank => false)
    leaders.size.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    member_1 = {:member => 'member_1'}
    member_2 = {:member => 'member_2'}
    leaders[0].should == member_1
    leaders[1].should == member_2

    leaders = @leaderboard.leaders(1, :with_rank => false, :page_size => 1)
    leaders.size.should be(1)
    member_1 = {:member => 'member_1', :score => 1}
    leaders[0].should == member_1
  end

  it 'should return a single leader when calling leader_at' do
    rank_members_in_leaderboard(50)
    @leaderboard.leader_at(1)[:rank].should == 1
    @leaderboard.leader_at(1)[:score].should == 1.0
    @leaderboard.leader_at(26)[:rank].should == 26
    @leaderboard.leader_at(50)[:rank].should == 50
    @leaderboard.leader_at(51).should be_nil
    @leaderboard.leader_at(1, :with_member_data => true)[:member_data].should == {'member_name' => 'Leaderboard member 1'}
    @leaderboard.leader_at(1, :use_zero_index_for_rank => true)[:rank].should == 0
  end

  it 'should return the correct information when calling around_me' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    @leaderboard.total_members.should be(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)
    
    leaders_around_me = @leaderboard.around_me('member_30')
    (leaders_around_me.size / 2).should be(@leaderboard.page_size / 2)
    
    leaders_around_me = @leaderboard.around_me('member_76')
    leaders_around_me.size.should be(@leaderboard.page_size / 2 + 1)
    
    leaders_around_me = @leaderboard.around_me('member_1')
    (leaders_around_me.size / 2).should be(@leaderboard.page_size / 2)
  end

  it 'should return the correct information when calling ranked_in_list' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.total_members.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    
    members = ['member_1', 'member_5', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS)
    
    ranked_members.size.should be(3)

    ranked_members[0][:rank].should == 1
    ranked_members[0][:score].should == 1

    ranked_members[1][:rank].should == 5
    ranked_members[1][:score].should == 5

    ranked_members[2][:rank].should == 10
    ranked_members[2][:score].should == 10
  end

  it 'should return the correct information when calling ranked_in_list without scores' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)
    
    @leaderboard.total_members.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    
    members = ['member_1', 'member_5', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, {:with_scores => false, :with_rank => true, :use_zero_index_for_rank => false})
    
    ranked_members.size.should be(3)

    ranked_members[0][:rank].should be(1)

    ranked_members[1][:rank].should be(5)

    ranked_members[2][:rank].should be(10)
  end

  it 'should return the correct information when calling score_and_rank_for' do
    rank_members_in_leaderboard
    
    data = @leaderboard.score_and_rank_for('member_1')
    data[:member].should == 'member_1'
    data[:score].should == 1
    data[:rank].should be(1)
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
    first_leader_in_foobar[:rank].should be(1)
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
    first_leader_in_foobar[:rank].should be(1)
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

  it 'should return the correct number of members when calling around_me with a page_size options' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)
    
    leaders_around_me = @leaderboard.around_me('member_30', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 3}))
    leaders_around_me.size.should be(3)
    leaders_around_me[2][:member].should == 'member_31'
    leaders_around_me[0][:member].should == 'member_29'
  end

  it 'should return the correct information when calling percentile_for' do
    rank_members_in_leaderboard(12)
    
    @leaderboard.percentile_for('member_1').should == 100
    @leaderboard.percentile_for('member_2').should == 91
    @leaderboard.percentile_for('member_3').should == 83
    @leaderboard.percentile_for('member_4').should == 75
    @leaderboard.percentile_for('member_12').should == 8
  end

  it 'should return the correct page when calling page_for a given member in the leaderboard' do
    @leaderboard.page_for('jones').should be(0)

    rank_members_in_leaderboard(20)

    @leaderboard.page_for('member_17').should be(1)
    @leaderboard.page_for('member_11').should be(1)
    @leaderboard.page_for('member_10').should be(1)
    @leaderboard.page_for('member_1').should be(1)

    @leaderboard.page_for('member_10', 10).should be(1)
    @leaderboard.page_for('member_1', 10).should be(1)
    @leaderboard.page_for('member_17', 10).should be(2)
    @leaderboard.page_for('member_11', 10).should be(2)
  end

  it 'should allow you to rank multiple members with a variable number of arguments' do
    @leaderboard.total_members.should be(0)
    @leaderboard.rank_members('member_1', 1, 'member_10', 10)
    @leaderboard.total_members.should be(2)
    @leaderboard.leaders(1).first[:member].should == 'member_1'
  end

  it 'should allow you to rank multiple members with an array' do
    @leaderboard.total_members.should be(0)
    @leaderboard.rank_members(['member_1', 1, 'member_10', 10])
    @leaderboard.total_members.should be(2)
    @leaderboard.leaders(1).first[:member].should == 'member_1'
  end
end