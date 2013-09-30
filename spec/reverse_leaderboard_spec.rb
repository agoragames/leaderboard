require 'spec_helper'

describe 'Leaderboard (reverse option)' do
  before(:each) do
    @redis_connection = Redis.new(:host => "127.0.0.1", :db => 15)
    @leaderboard = Leaderboard.new('name', Leaderboard::DEFAULT_OPTIONS.merge({:reverse => true}), :host => "127.0.0.1", :db => 15)
  end

  after(:each) do
    @redis_connection.flushdb
    @leaderboard.disconnect
    @redis_connection.client.disconnect
  end

  it 'should return the correct rank when calling rank_for' do
    rank_members_in_leaderboard(5)

    @leaderboard.rank_for('member_4').should be(4)
  end

  it 'should return the correct list when calling leaders' do
    rank_members_in_leaderboard(25)

    @leaderboard.total_members.should be(25)

    leaders = @leaderboard.leaders(1)

    leaders.size.should be(25)
    leaders[0][:member].should eql('member_1')
    leaders[-2][:member].should eql('member_24')
    leaders[-1][:member].should eql('member_25')
    leaders[-1][:score].to_i.should be(25)
  end

  it 'should return the correct list when calling members' do
    rank_members_in_leaderboard(25)

    @leaderboard.total_members.should be(25)

    members = @leaderboard.members(1)

    members.size.should be(25)
    members[0][:member].should eql('member_1')
    members[-2][:member].should eql('member_24')
    members[-1][:member].should eql('member_25')
    members[-1][:score].to_i.should be(25)
  end

  it 'should allow you to retrieve members in a given score range' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    members = @leaderboard.members_from_score_range(10, 15, {:with_scores => false, :with_rank => false})

    member_10 = {:member => 'member_10', :score => 10.0, :rank => 10}
    members[0].should eql(member_10)

    member_15 = {:member => 'member_15', :score => 15.0, :rank => 15}
    members[5].should eql(member_15)

    members = @leaderboard.members_from_score_range(10, 15, {:with_member_data => true})

    member_10 = {:member => 'member_10', :rank => 10, :score => 10.0, :member_data => {:member_name => 'Leaderboard member 10'}.to_s}
    members[0].should == member_10

    member_15 = {:member => 'member_15', :rank => 15, :score => 15.0, :member_data => {:member_name => 'Leaderboard member 15'}.to_s}
    members[5].should == member_15
  end

  it 'should allow you to call leaders with various options that respect the defaults for the options not passed in' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE + 1)

    leaders = @leaderboard.leaders(1, :page_size => 1)
    leaders.size.should be(1)

    leaders = @leaderboard.leaders(1)
    leaders.size.should be(Leaderboard::DEFAULT_PAGE_SIZE)
    member_1 = {:member => 'member_1', :score => 1.0, :rank => 1}
    member_2 = {:member => 'member_2', :score => 2.0, :rank => 2}
    member_3 = {:member => 'member_3', :score => 3.0, :rank => 3}
    leaders[0].should eql(member_1)
    leaders[1].should eql(member_2)
    leaders[2].should eql(member_3)
  end

  it 'should return a single member when calling member_at' do
    rank_members_in_leaderboard(50)
    @leaderboard.member_at(1)[:rank].should eql(1)
    @leaderboard.member_at(1)[:score].should eql(1.0)
    @leaderboard.member_at(26)[:rank].should eql(26)
    @leaderboard.member_at(50)[:rank].should eql(50)
    @leaderboard.member_at(51).should be_nil
    @leaderboard.member_at(1, :with_member_data => true)[:member_data].should == {:member_name => 'Leaderboard member 1'}.to_s
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

    ranked_members[0][:rank].should eql(1)
    ranked_members[0][:score].should eql(1.0)

    ranked_members[1][:rank].should eql(5)
    ranked_members[1][:score].should eql(5.0)

    ranked_members[2][:rank].should eql(10)
    ranked_members[2][:score].should eql(10.0)
  end

  it 'should return the correct information when calling ranked_in_list without scores' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    @leaderboard.total_members.should be(Leaderboard::DEFAULT_PAGE_SIZE)

    members = ['member_1', 'member_5', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, {:with_scores => false, :with_rank => true})
    ranked_members.size.should be(3)

    ranked_members[0][:rank].should be(1)

    ranked_members[1][:rank].should be(5)

    ranked_members[2][:rank].should be(10)
  end

  it 'should return the correct information when calling score_and_rank_for' do
    rank_members_in_leaderboard

    data = @leaderboard.score_and_rank_for('member_1')
    data[:member].should eql('member_1')
    data[:score].should eql(1.0)
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

  it 'should allow you to remove members outside a given rank' do
    rank_members_in_leaderboard

    @leaderboard.total_members.should be(5)
    @leaderboard.remove_members_outside_rank(3).should be(2)

    leaders = @leaderboard.leaders(1)
    leaders.size.should be(3)
    leaders[0][:member].should == 'member_1'
    leaders[2][:member].should == 'member_3'
  end

  it 'should allow you to merge leaderboards' do
    foo = Leaderboard.new('foo', Leaderboard::DEFAULT_OPTIONS, :host => "127.0.0.1", :db => 15)
    bar = Leaderboard.new('bar', Leaderboard::DEFAULT_OPTIONS, :host => "127.0.0.1", :db => 15)

    foo.rank_member('foo_1', 1)
    foo.rank_member('foo_2', 2)
    bar.rank_member('bar_1', 3)
    bar.rank_member('bar_2', 4)
    bar.rank_member('bar_3', 5)

    foobar_keys = foo.merge_leaderboards('foobar', ['bar'])
    foobar_keys.should be(5)

    foobar = Leaderboard.new('foobar', Leaderboard::DEFAULT_OPTIONS, :host => "127.0.0.1", :db => 15)
    foobar.total_members.should be(5)

    first_leader_in_foobar = foobar.leaders(1).first
    first_leader_in_foobar[:rank].should be(1)
    first_leader_in_foobar[:member].should eql('bar_3')
    first_leader_in_foobar[:score].should eql(5.0)

    foo.disconnect
    bar.disconnect
    foobar.disconnect
  end

  it 'should allow you to intersect leaderboards' do
    foo = Leaderboard.new('foo', Leaderboard::DEFAULT_OPTIONS, :host => "127.0.0.1", :db => 15)
    bar = Leaderboard.new('bar', Leaderboard::DEFAULT_OPTIONS, :host => "127.0.0.1", :db => 15)

    foo.rank_member('foo_1', 1)
    foo.rank_member('foo_2', 2)
    foo.rank_member('bar_3', 6)
    bar.rank_member('bar_1', 3)
    bar.rank_member('foo_1', 4)
    bar.rank_member('bar_3', 5)

    foobar_keys = foo.intersect_leaderboards('foobar', ['bar'], {:aggregate => :max})
    foobar_keys.should be(2)

    foobar = Leaderboard.new('foobar', Leaderboard::DEFAULT_OPTIONS, :host => "127.0.0.1", :db => 15)
    foobar.total_members.should be(2)

    first_leader_in_foobar = foobar.leaders(1).first
    first_leader_in_foobar[:rank].should be(1)
    first_leader_in_foobar[:member].should eql('bar_3')
    first_leader_in_foobar[:score].should eql(6.0)

    foo.disconnect
    bar.disconnect
    foobar.disconnect
  end

  it 'should respect options in the massage_leader_data method' do
    rank_members_in_leaderboard(25)

    @leaderboard.total_members.should be(25)

    leaders = @leaderboard.leaders(1)
    leaders[0][:member].should_not be_nil
    leaders[0][:score].should_not be_nil
    leaders[0][:rank].should_not be_nil

    @leaderboard.page_size = Leaderboard::DEFAULT_PAGE_SIZE
    leaders = @leaderboard.leaders(1, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS)
    leaders.size.should be(25)
    leaders[0][:member].should_not be_nil
    leaders[0][:score].should_not be_nil
    leaders[0][:rank].should_not be_nil
  end

  it 'should return the correct number of members when calling around_me with a page_size options' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    leaders_around_me = @leaderboard.around_me('member_30', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 3}))
    leaders_around_me.size.should be(3)
    leaders_around_me[2][:member].should eql('member_31')
    leaders_around_me[0][:member].should eql('member_29')
  end

  it 'should return the correct information when calling percentile_for' do
    rank_members_in_leaderboard(12)

    @leaderboard.percentile_for('member_1').should eql(100)
    @leaderboard.percentile_for('member_2').should eql(91)
    @leaderboard.percentile_for('member_3').should eql(83)
    @leaderboard.percentile_for('member_4').should eql(75)
    @leaderboard.percentile_for('member_12').should eql(8)
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
    @leaderboard.leaders(1).first[:member].should eql('member_1')
  end

  it 'should allow you to rank multiple members with an array' do
    @leaderboard.total_members.should be(0)
    @leaderboard.rank_members(['member_1', 1, 'member_10', 10])
    @leaderboard.total_members.should be(2)
    @leaderboard.leaders(1).first[:member].should eql('member_1')
  end

  it 'should allow you to retrieve a given set of members from the leaderboard in a rank range' do
    rank_members_in_leaderboard(25)

    members = @leaderboard.members_from_rank_range(5, 9)
    members.size.should be(5)
    members[0][:member].should eql('member_5')
    members[0][:score].to_i.should be(5)
    members[4][:member].should eql('member_9')

    members = @leaderboard.members_from_rank_range(1, 1)
    members.size.should be(1)
    members[0][:member].should eql('member_1')

    members = @leaderboard.members_from_rank_range(-1, 26)
    members.size.should be(25)
    members[0][:member].should eql('member_1')
    members[0][:score].to_i.should be(1)
    members[24][:member].should eql('member_25')
  end

  it 'should sort by rank if the :sort_by option is set to :rank' do
    rank_members_in_leaderboard(25)

    members = ['member_5', 'member_1', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, :sort_by => :rank)

    ranked_members.size.should be(3)

    ranked_members[0][:rank].should be(1)
    ranked_members[0][:score].should eql(1.0)

    ranked_members[1][:rank].should be(5)
    ranked_members[1][:score].should eql(5.0)

    ranked_members[2][:rank].should be(10)
    ranked_members[2][:score].should eql(10.0)
  end

  it 'should sort by score if the :sort_by option is set to :score' do
    rank_members_in_leaderboard(25)

    members = ['member_5', 'member_1', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, :sort_by => :score)

    ranked_members.size.should be(3)

    ranked_members[0][:rank].should be(1)
    ranked_members[0][:score].should eql(1.0)

    ranked_members[1][:rank].should be(5)
    ranked_members[1][:score].should eql(5.0)

    ranked_members[2][:rank].should be(10)
    ranked_members[2][:score].should eql(10.0)
  end
end