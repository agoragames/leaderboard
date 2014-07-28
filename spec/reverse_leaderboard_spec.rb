require 'spec_helper'

describe 'Leaderboard (reverse option)' do
  before(:each) do
    @redis_connection = Redis.new(:host => "127.0.0.1", :db => 15)
    @leaderboard = Leaderboard.new('name', Leaderboard::DEFAULT_OPTIONS.merge({:reverse => true}), {:host => "127.0.0.1", :db => 15})
  end

  after(:each) do
    @redis_connection.flushdb
    @leaderboard.disconnect
    @redis_connection.client.disconnect
  end

  it 'should return the correct rank when calling rank_for' do
    rank_members_in_leaderboard(5)

    expect(@leaderboard.rank_for('member_4')).to be(4)
  end

  it 'should return the correct list when calling leaders' do
    rank_members_in_leaderboard(25)

    expect(@leaderboard.total_members).to be(25)

    leaders = @leaderboard.leaders(1)

    expect(leaders.size).to be(25)
    expect(leaders[0][:member]).to eql('member_1')
    expect(leaders[-2][:member]).to eql('member_24')
    expect(leaders[-1][:member]).to eql('member_25')
    expect(leaders[-1][:score].to_i).to be(25)
  end

  it 'should return the correct list when calling members' do
    rank_members_in_leaderboard(25)

    expect(@leaderboard.total_members).to be(25)

    members = @leaderboard.members(1)

    expect(members.size).to be(25)
    expect(members[0][:member]).to eql('member_1')
    expect(members[-2][:member]).to eql('member_24')
    expect(members[-1][:member]).to eql('member_25')
    expect(members[-1][:score].to_i).to be(25)
  end

  it 'should allow you to retrieve members in a given score range' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    members = @leaderboard.members_from_score_range(10, 15, {:with_scores => false, :with_rank => false})

    member_10 = {:member => 'member_10', :score => 10.0, :rank => 10}
    expect(members[0]).to eql(member_10)

    member_15 = {:member => 'member_15', :score => 15.0, :rank => 15}
    expect(members[5]).to eql(member_15)

    members = @leaderboard.members_from_score_range(10, 15, {:with_member_data => true})

    member_10 = {:member => 'member_10', :rank => 10, :score => 10.0, :member_data => {:member_name => 'Leaderboard member 10'}.to_s}
    expect(members[0]).to eq(member_10)

    member_15 = {:member => 'member_15', :rank => 15, :score => 15.0, :member_data => {:member_name => 'Leaderboard member 15'}.to_s}
    expect(members[5]).to eq(member_15)
  end

  it 'should allow you to call leaders with various options that respect the defaults for the options not passed in' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE + 1)

    leaders = @leaderboard.leaders(1, :page_size => 1)
    expect(leaders.size).to be(1)

    leaders = @leaderboard.leaders(1)
    expect(leaders.size).to be(Leaderboard::DEFAULT_PAGE_SIZE)
    member_1 = {:member => 'member_1', :score => 1.0, :rank => 1}
    member_2 = {:member => 'member_2', :score => 2.0, :rank => 2}
    member_3 = {:member => 'member_3', :score => 3.0, :rank => 3}
    expect(leaders[0]).to eql(member_1)
    expect(leaders[1]).to eql(member_2)
    expect(leaders[2]).to eql(member_3)
  end

  it 'should return a single member when calling member_at' do
    rank_members_in_leaderboard(50)
    expect(@leaderboard.member_at(1)[:rank]).to eql(1)
    expect(@leaderboard.member_at(1)[:score]).to eql(1.0)
    expect(@leaderboard.member_at(26)[:rank]).to eql(26)
    expect(@leaderboard.member_at(50)[:rank]).to eql(50)
    expect(@leaderboard.member_at(51)).to be_nil
    expect(@leaderboard.member_at(1, :with_member_data => true)[:member_data]).to eq({:member_name => 'Leaderboard member 1'}.to_s)
  end

  it 'should return the correct information when calling around_me' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    expect(@leaderboard.total_members).to be(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    leaders_around_me = @leaderboard.around_me('member_30')
    expect(leaders_around_me.size / 2).to be(@leaderboard.page_size / 2)

    leaders_around_me = @leaderboard.around_me('member_76')
    expect(leaders_around_me.size).to be(@leaderboard.page_size / 2 + 1)

    leaders_around_me = @leaderboard.around_me('member_1')
    expect(leaders_around_me.size / 2).to be(@leaderboard.page_size / 2)
  end

  it 'should return the correct information when calling ranked_in_list' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    expect(@leaderboard.total_members).to be(Leaderboard::DEFAULT_PAGE_SIZE)

    members = ['member_1', 'member_5', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS)

    expect(ranked_members.size).to be(3)

    expect(ranked_members[0][:rank]).to eql(1)
    expect(ranked_members[0][:score]).to eql(1.0)

    expect(ranked_members[1][:rank]).to eql(5)
    expect(ranked_members[1][:score]).to eql(5.0)

    expect(ranked_members[2][:rank]).to eql(10)
    expect(ranked_members[2][:score]).to eql(10.0)
  end

  it 'should return the correct information when calling ranked_in_list without scores' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    expect(@leaderboard.total_members).to be(Leaderboard::DEFAULT_PAGE_SIZE)

    members = ['member_1', 'member_5', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, {:with_scores => false, :with_rank => true})
    expect(ranked_members.size).to be(3)

    expect(ranked_members[0][:rank]).to be(1)

    expect(ranked_members[1][:rank]).to be(5)

    expect(ranked_members[2][:rank]).to be(10)
  end

  it 'should return the correct information when calling score_and_rank_for' do
    rank_members_in_leaderboard

    data = @leaderboard.score_and_rank_for('member_1')
    expect(data[:member]).to eql('member_1')
    expect(data[:score]).to eql(1.0)
    expect(data[:rank]).to be(1)
  end

  it 'should allow you to remove members in a given score range' do
    rank_members_in_leaderboard

    expect(@leaderboard.total_members).to be(5)

    @leaderboard.rank_member('cheater_1', 100)
    @leaderboard.rank_member('cheater_2', 101)
    @leaderboard.rank_member('cheater_3', 102)

    expect(@leaderboard.total_members).to be(8)

    @leaderboard.remove_members_in_score_range(100, 102)

    expect(@leaderboard.total_members).to be(5)

    leaders = @leaderboard.leaders(1)
    leaders.each do |leader|
      expect(leader[:score]).to be < 100
    end
  end

  it 'should allow you to remove members outside a given rank' do
    rank_members_in_leaderboard

    expect(@leaderboard.total_members).to be(5)
    expect(@leaderboard.remove_members_outside_rank(3)).to be(2)

    leaders = @leaderboard.leaders(1)
    expect(leaders.size).to be(3)
    expect(leaders[0][:member]).to eq('member_1')
    expect(leaders[2][:member]).to eq('member_3')
  end

  it 'should allow you to merge leaderboards' do
    foo = Leaderboard.new('foo', Leaderboard::DEFAULT_OPTIONS, {:host => "127.0.0.1", :db => 15})
    bar = Leaderboard.new('bar', Leaderboard::DEFAULT_OPTIONS, {:host => "127.0.0.1", :db => 15})

    foo.rank_member('foo_1', 1)
    foo.rank_member('foo_2', 2)
    bar.rank_member('bar_1', 3)
    bar.rank_member('bar_2', 4)
    bar.rank_member('bar_3', 5)

    foobar_keys = foo.merge_leaderboards('foobar', ['bar'])
    expect(foobar_keys).to be(5)

    foobar = Leaderboard.new('foobar', Leaderboard::DEFAULT_OPTIONS, {:host => "127.0.0.1", :db => 15})
    expect(foobar.total_members).to be(5)

    first_leader_in_foobar = foobar.leaders(1).first
    expect(first_leader_in_foobar[:rank]).to be(1)
    expect(first_leader_in_foobar[:member]).to eql('bar_3')
    expect(first_leader_in_foobar[:score]).to eql(5.0)

    foo.disconnect
    bar.disconnect
    foobar.disconnect
  end

  it 'should allow you to intersect leaderboards' do
    foo = Leaderboard.new('foo', Leaderboard::DEFAULT_OPTIONS, {:host => "127.0.0.1", :db => 15})
    bar = Leaderboard.new('bar', Leaderboard::DEFAULT_OPTIONS, {:host => "127.0.0.1", :db => 15})

    foo.rank_member('foo_1', 1)
    foo.rank_member('foo_2', 2)
    foo.rank_member('bar_3', 6)
    bar.rank_member('bar_1', 3)
    bar.rank_member('foo_1', 4)
    bar.rank_member('bar_3', 5)

    foobar_keys = foo.intersect_leaderboards('foobar', ['bar'], {:aggregate => :max})
    expect(foobar_keys).to be(2)

    foobar = Leaderboard.new('foobar', Leaderboard::DEFAULT_OPTIONS, {:host => "127.0.0.1", :db => 15})
    expect(foobar.total_members).to be(2)

    first_leader_in_foobar = foobar.leaders(1).first
    expect(first_leader_in_foobar[:rank]).to be(1)
    expect(first_leader_in_foobar[:member]).to eql('bar_3')
    expect(first_leader_in_foobar[:score]).to eql(6.0)

    foo.disconnect
    bar.disconnect
    foobar.disconnect
  end

  it 'should respect options in the massage_leader_data method' do
    rank_members_in_leaderboard(25)

    expect(@leaderboard.total_members).to be(25)

    leaders = @leaderboard.leaders(1)
    expect(leaders[0][:member]).not_to be_nil
    expect(leaders[0][:score]).not_to be_nil
    expect(leaders[0][:rank]).not_to be_nil

    @leaderboard.page_size = Leaderboard::DEFAULT_PAGE_SIZE
    leaders = @leaderboard.leaders(1, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS)
    expect(leaders.size).to be(25)
    expect(leaders[0][:member]).not_to be_nil
    expect(leaders[0][:score]).not_to be_nil
    expect(leaders[0][:rank]).not_to be_nil
  end

  it 'should return the correct number of members when calling around_me with a page_size options' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    leaders_around_me = @leaderboard.around_me('member_30', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 3}))
    expect(leaders_around_me.size).to be(3)
    expect(leaders_around_me[2][:member]).to eql('member_31')
    expect(leaders_around_me[0][:member]).to eql('member_29')
  end

  it 'should return the correct information when calling percentile_for' do
    rank_members_in_leaderboard(12)

    expect(@leaderboard.percentile_for('member_1')).to eql(100)
    expect(@leaderboard.percentile_for('member_2')).to eql(91)
    expect(@leaderboard.percentile_for('member_3')).to eql(83)
    expect(@leaderboard.percentile_for('member_4')).to eql(75)
    expect(@leaderboard.percentile_for('member_12')).to eql(8)
  end

  it 'should return the correct information when calling score_for_percentile' do
    rank_members_in_leaderboard(5)

    expect(@leaderboard.score_for_percentile(0)).to eql(5.0)
    expect(@leaderboard.score_for_percentile(75)).to eql(2.0)
    expect(@leaderboard.score_for_percentile(87.5)).to eql(1.5)
    expect(@leaderboard.score_for_percentile(93.75)).to eql(1.25)
    expect(@leaderboard.score_for_percentile(100)).to eql(1.0)
  end

  it 'should return the correct page when calling page_for a given member in the leaderboard' do
    expect(@leaderboard.page_for('jones')).to be(0)

    rank_members_in_leaderboard(20)

    expect(@leaderboard.page_for('member_17')).to be(1)
    expect(@leaderboard.page_for('member_11')).to be(1)
    expect(@leaderboard.page_for('member_10')).to be(1)
    expect(@leaderboard.page_for('member_1')).to be(1)

    expect(@leaderboard.page_for('member_10', 10)).to be(1)
    expect(@leaderboard.page_for('member_1', 10)).to be(1)
    expect(@leaderboard.page_for('member_17', 10)).to be(2)
    expect(@leaderboard.page_for('member_11', 10)).to be(2)
  end

  it 'should allow you to rank multiple members with a variable number of arguments' do
    expect(@leaderboard.total_members).to be(0)
    @leaderboard.rank_members('member_1', 1, 'member_10', 10)
    expect(@leaderboard.total_members).to be(2)
    expect(@leaderboard.leaders(1).first[:member]).to eql('member_1')
  end

  it 'should allow you to rank multiple members with an array' do
    expect(@leaderboard.total_members).to be(0)
    @leaderboard.rank_members(['member_1', 1, 'member_10', 10])
    expect(@leaderboard.total_members).to be(2)
    expect(@leaderboard.leaders(1).first[:member]).to eql('member_1')
  end

  it 'should allow you to retrieve a given set of members from the leaderboard in a rank range' do
    rank_members_in_leaderboard(25)

    members = @leaderboard.members_from_rank_range(5, 9)
    expect(members.size).to be(5)
    expect(members[0][:member]).to eql('member_5')
    expect(members[0][:score].to_i).to be(5)
    expect(members[4][:member]).to eql('member_9')

    members = @leaderboard.members_from_rank_range(1, 1)
    expect(members.size).to be(1)
    expect(members[0][:member]).to eql('member_1')

    members = @leaderboard.members_from_rank_range(-1, 26)
    expect(members.size).to be(25)
    expect(members[0][:member]).to eql('member_1')
    expect(members[0][:score].to_i).to be(1)
    expect(members[24][:member]).to eql('member_25')
  end

  it 'should sort by rank if the :sort_by option is set to :rank' do
    rank_members_in_leaderboard(25)

    members = ['member_5', 'member_1', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, :sort_by => :rank)

    expect(ranked_members.size).to be(3)

    expect(ranked_members[0][:rank]).to be(1)
    expect(ranked_members[0][:score]).to eql(1.0)

    expect(ranked_members[1][:rank]).to be(5)
    expect(ranked_members[1][:score]).to eql(5.0)

    expect(ranked_members[2][:rank]).to be(10)
    expect(ranked_members[2][:score]).to eql(10.0)
  end

  it 'should sort by score if the :sort_by option is set to :score' do
    rank_members_in_leaderboard(25)

    members = ['member_5', 'member_1', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, :sort_by => :score)

    expect(ranked_members.size).to be(3)

    expect(ranked_members[0][:rank]).to be(1)
    expect(ranked_members[0][:score]).to eql(1.0)

    expect(ranked_members[1][:rank]).to be(5)
    expect(ranked_members[1][:score]).to eql(5.0)

    expect(ranked_members[2][:rank]).to be(10)
    expect(ranked_members[2][:score]).to eql(10.0)
  end
end