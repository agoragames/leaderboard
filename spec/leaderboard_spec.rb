require 'spec_helper'

describe 'Leaderboard' do
  before(:each) do
    @redis_connection = Redis.new(:host => "127.0.0.1", :db => 15)
    @leaderboard = Leaderboard.new('name', Leaderboard::DEFAULT_OPTIONS, {:host => "127.0.0.1", :db => 15})
  end

  after(:each) do
    @redis_connection.flushdb
    @leaderboard.disconnect
    @redis_connection.client.disconnect
  end

  it 'should be initialized with defaults' do
    expect(@leaderboard.leaderboard_name).to eql('name')
    expect(@leaderboard.page_size).to eql(Leaderboard::DEFAULT_PAGE_SIZE)
  end

  it 'should be able to disconnect its connection to Redis' do
    expect(@leaderboard.disconnect).to be_nil
  end

  it 'should automatically reconnect to Redis after a disconnect' do
    expect(@leaderboard.total_members).to be(0)
    rank_members_in_leaderboard(5)
    expect(@leaderboard.total_members).to be(5)
    expect(@leaderboard.disconnect).to be_nil
    expect(@leaderboard.total_members).to be(5)
  end

  it 'should set the page size to the default page size if passed an invalid value' do
    some_leaderboard = Leaderboard.new('name', {:page_size => 0}, {:host => "127.0.0.1", :db => 15})

    expect(some_leaderboard.page_size).to be(Leaderboard::DEFAULT_PAGE_SIZE)
    some_leaderboard.disconnect
  end

  it 'should allow you to delete a leaderboard' do
    rank_members_in_leaderboard

    expect(@redis_connection.exists('name')).to be_truthy
    expect(@redis_connection.exists('name:member_data')).to be_truthy
    @leaderboard.delete_leaderboard
    expect(@redis_connection.exists('name')).to be_falsey
    expect(@redis_connection.exists('name:member_data')).to be_falsey
  end

  it 'should allow you to pass in an existing redis connection in the initializer' do
    @leaderboard = Leaderboard.new('name', Leaderboard::DEFAULT_OPTIONS, {:redis_connection => @redis_connection})
    rank_members_in_leaderboard

    expect(@redis_connection.info["connected_clients"].to_i).to be(1)
  end

  it 'should allow you to rank a member and see that reflected in total members' do
    @leaderboard.rank_member('member', 1)

    expect(@leaderboard.total_members).to be(1)
  end

  it 'should return the correct number of members in a given score range' do
    rank_members_in_leaderboard(5)

    expect(@leaderboard.total_members_in_score_range(2, 4)).to be(3)
  end

  it 'should return the correct rank when calling rank_for' do
    rank_members_in_leaderboard(5)

    expect(@leaderboard.rank_for('member_4')).to be(2)
  end

  it 'should return the correct score when calling score_for' do
    rank_members_in_leaderboard(5)

    expect(@leaderboard.score_for('member_4')).to eql(4.0)
    expect(@leaderboard.score_for('jones')).to be_nil
  end

  it 'should return the correct total pages' do
    rank_members_in_leaderboard(10)

    expect(@leaderboard.total_pages).to be(1)
    expect(@leaderboard.total_pages(5)).to be(2)

    @redis_connection.flushdb

    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE + 1)

    expect(@leaderboard.total_pages).to be(2)
  end

  it 'should return the correct list when calling leaders' do
    rank_members_in_leaderboard(25)

    expect(@leaderboard.total_members).to be(25)

    leaders = @leaderboard.leaders(1)

    expect(leaders.size).to be(25)
    expect(leaders[0][:member]).to eql 'member_25'
    expect(leaders[-2][:member]).to eql 'member_2'
    expect(leaders[-1][:member]).to eql 'member_1'
    expect(leaders[-1][:score].to_i).to be(1)
  end

  it 'should return the correct list when calling members' do
    rank_members_in_leaderboard(25)

    expect(@leaderboard.total_members).to be(25)

    members = @leaderboard.members(1)

    expect(members.size).to be(25)
    expect(members[0][:member]).to eql('member_25')
    expect(members[-2][:member]).to eql('member_2')
    expect(members[-1][:member]).to eql('member_1')
    expect(members[-1][:score].to_i).to be(1)
  end

  it 'should return the correct number of members when calling leaders with multiple pages' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    expect(@leaderboard.total_members).to be(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    leaders = @leaderboard.leaders(1)
    expect(leaders.size).to be(@leaderboard.page_size)

    leaders = @leaderboard.leaders(2)
    expect(leaders.size).to be(@leaderboard.page_size)

    leaders = @leaderboard.leaders(3)
    expect(leaders.size).to be(@leaderboard.page_size)

    leaders = @leaderboard.leaders(4)
    expect(leaders.size).to be(1)

    leaders = @leaderboard.leaders(-5)
    expect(leaders.size).to be(@leaderboard.page_size)

    leaders = @leaderboard.leaders(10)
    expect(leaders.size).to be(1)
  end

  %w(members leaders).each do |method|
    it "should return the entire leaderboard when you call 'all_#{method}'" do
      rank_members_in_leaderboard(27)

      expect(@leaderboard.total_members).to be(27)

      members = @leaderboard.send("all_#{method}")

      expect(members.size).to be(27)
      expect(members[0][:member]).to eql('member_27')
      expect(members[-2][:member]).to eql('member_2')
      expect(members[-1][:member]).to eql('member_1')
      expect(members[-1][:score].to_i).to be(1)
    end
  end

  it 'should allow you to retrieve members in a given score range' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    members = @leaderboard.members_from_score_range(10, 15)

    member_15 = {:member => 'member_15', :score => 15.0, :rank => 11}
    expect(members[0]).to eql(member_15)

    member_10 = {:member => 'member_10', :score => 10.0, :rank => 16}
    expect(members[5]).to eql(member_10)

    members = @leaderboard.members_from_score_range(10, 15, {:with_member_data => true})

    member_15 = {:member => 'member_15', :rank => 11, :score => 15.0, :member_data => {:member_name => 'Leaderboard member 15'}.to_s}
    expect(members[0]).to eq(member_15)

    member_10 = {:member => 'member_10', :rank => 16, :score => 10.0, :member_data => {:member_name => 'Leaderboard member 10'}.to_s}
    expect(members[5]).to eq(member_10)
  end

  it 'should allow you to retrieve leaders with extra data' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    expect(@leaderboard.total_members).to be(Leaderboard::DEFAULT_PAGE_SIZE)
    leaders = @leaderboard.leaders(1, {:with_member_data => true})

    member_25 = {:member => 'member_25', :score => 25.0, :rank => 1, :member_data => { :member_name => "Leaderboard member 25" }.to_s }
    expect(leaders[0]).to eq(member_25)

    member_1 = {:member => 'member_1', :score => 1.0, :rank => 25, :member_data => { :member_name => "Leaderboard member 1" }.to_s }
    expect(leaders[24]).to eq(member_1)
  end

  it 'should allow you to retrieve optional member data' do
    @leaderboard.rank_member('member_id', 1, {'username' => 'member_name', 'other_data_key' => 'other_data_value'})

    expect(@leaderboard.member_data_for('unknown_member')).to be_nil
    expect(@leaderboard.member_data_for('member_id')).to eq({'username' => 'member_name', 'other_data_key' => 'other_data_value'}.to_s)
  end

  it 'should allow you to update optional member data' do
    @leaderboard.rank_member('member_id', 1, {'username' => 'member_name'})

    expect(@leaderboard.member_data_for('member_id')).to eq({'username' => 'member_name'}.to_s)
    @leaderboard.update_member_data('member_id', {'username' => 'member_name', 'other_data_key' => 'other_data_value'})
    expect(@leaderboard.member_data_for('member_id')).to eq({'username' => 'member_name', 'other_data_key' => 'other_data_value'}.to_s)
  end

  it 'should allow you to remove optional member data' do
    @leaderboard.rank_member('member_id', 1, {'username' => 'member_name'})

    expect(@leaderboard.member_data_for('member_id')).to eq({'username' => 'member_name'}.to_s)
    @leaderboard.remove_member_data('member_id')
    expect(@leaderboard.member_data_for('member_id')).to be_nil
  end

  it 'should allow you to call leaders with various options that respect the defaults for the options not passed in' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE + 1)

    leaders = @leaderboard.leaders(1, :page_size => 1)
    expect(leaders.size).to be(1)
    member_26 = {:member => 'member_26', :score => 26.0, :rank => 1}
    expect(leaders[0]).to eql(member_26)
  end

  it 'should return a single member when calling member_at' do
    rank_members_in_leaderboard(50)
    expect(@leaderboard.member_at(1)[:rank]).to eql(1)
    expect(@leaderboard.member_at(1)[:score]).to eql(50.0)
    expect(@leaderboard.member_at(26)[:rank]).to eql(26)
    expect(@leaderboard.member_at(50)[:rank]).to eql(50)
    expect(@leaderboard.member_at(51)).to be_nil
    expect(@leaderboard.member_at(1, :with_member_data => true)[:member_data]).to eq({:member_name => 'Leaderboard member 50'}.to_s)
  end

  it 'should return the correct information when calling around_me' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    expect(@leaderboard.total_members).to be(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    leaders_around_me = @leaderboard.around_me('member_30')
    expect(leaders_around_me.size / 2).to be(@leaderboard.page_size / 2)

    leaders_around_me = @leaderboard.around_me('member_1')
    expect(leaders_around_me.size).to be(@leaderboard.page_size / 2 + 1)

    leaders_around_me = @leaderboard.around_me('member_76')
    expect(leaders_around_me.size / 2).to be(@leaderboard.page_size / 2)
  end

  it 'should return the correct information when calling ranked_in_list' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    expect(@leaderboard.total_members).to be(Leaderboard::DEFAULT_PAGE_SIZE)

    members = ['member_1', 'member_5', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS)

    expect(ranked_members.size).to be(3)

    expect(ranked_members[0][:rank]).to be(25)
    expect(ranked_members[0][:score]).to eql(1.0)

    expect(ranked_members[1][:rank]).to be(21)
    expect(ranked_members[1][:score]).to eql(5.0)

    expect(ranked_members[2][:rank]).to be(16)
    expect(ranked_members[2][:score]).to eql(10.0)
  end

  it 'should return the correct information when calling ranked_in_list without scores' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    expect(@leaderboard.total_members).to be(Leaderboard::DEFAULT_PAGE_SIZE)

    members = ['member_1', 'member_5', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, {:with_rank => true})
    expect(ranked_members.size).to be(3)
    expect(ranked_members[0][:rank]).to be(25)
    expect(ranked_members[1][:rank]).to be(21)
    expect(ranked_members[2][:rank]).to be(16)
  end

  it 'should allow you to remove members' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    expect(@leaderboard.total_members).to be(Leaderboard::DEFAULT_PAGE_SIZE)

    @leaderboard.remove_member('member_1')

    expect(@leaderboard.total_members).to be(Leaderboard::DEFAULT_PAGE_SIZE - 1)
    expect(@leaderboard.rank_for('member_1')).to be_nil
  end

  it 'should allow you to change the score for a member' do
    @leaderboard.rank_member('member_1', 5)
    expect(@leaderboard.score_for('member_1')).to eql(5.0)

    @leaderboard.change_score_for('member_1', 5)
    expect(@leaderboard.score_for('member_1')).to eql(10.0)

    @leaderboard.change_score_for('member_1', -5)
    expect(@leaderboard.score_for('member_1')).to eql(5.0)
  end

  it 'should allow you to check if a member exists' do
    @leaderboard.rank_member('member_1', 10)

    expect(@leaderboard.check_member?('member_1')).to be_truthy
    expect(@leaderboard.check_member?('member_2')).to be_falsey
  end

  it 'should allow you to change the page size and have that reflected in the size of the result set' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    @leaderboard.page_size = 5

    expect(@leaderboard.total_pages).to be(5)
    expect(@leaderboard.leaders(1).size).to be(5)
  end

  it 'should not allow you to set the page size to an invalid page size' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE)

    @leaderboard.page_size = 0
    expect(@leaderboard.total_pages).to be(1)
    expect(@leaderboard.leaders(1).size).to be(Leaderboard::DEFAULT_PAGE_SIZE)
  end

  it 'should return the correct information when calling score_and_rank_for' do
    rank_members_in_leaderboard

    data = @leaderboard.score_and_rank_for('member_1')
    expect(data[:member]).to eql('member_1')
    expect(data[:score]).to eql(1.0)
    expect(data[:rank]).to eql(5)
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
    expect(leaders[0][:member]).to eq('member_5')
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
    expect(first_leader_in_foobar[:rank]).to eql(1)
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
    expect(first_leader_in_foobar[:rank]).to eql(1)
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
    expect(leaders[0][:member]).not_to be_nil
    expect(leaders[0][:score]).not_to be_nil
    expect(leaders[0][:rank]).not_to be_nil

    @leaderboard.page_size = 25
    leaders = @leaderboard.leaders(1, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS)
    expect(leaders.size).to be(25)
  end

  it 'should return the correct number of pages when calling total_pages_in page size option' do
    rank_members_in_leaderboard(25)

    expect(@leaderboard.total_pages_in(@leaderboard.leaderboard_name)).to be(1)
    expect(@leaderboard.total_pages_in(@leaderboard.leaderboard_name, 5)).to be(5)
  end

  it 'should return the correct number of members when calling leaders with a page_size option' do
    rank_members_in_leaderboard(25)

    expect(@leaderboard.leaders(1, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 5})).size).to be(5)
    expect(@leaderboard.leaders(1, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 10})).size).to be(10)
    expect(@leaderboard.leaders(2, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 10})).size).to be(10)
    expect(@leaderboard.leaders(3, Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 10})).size).to be(5)
  end

  it 'should return the correct number of members when calling around_me with a page_size options' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    leaders_around_me = @leaderboard.around_me('member_30', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 3}))
    expect(leaders_around_me.size).to be(3)
    expect(leaders_around_me[0][:member]).to eql('member_31')
    expect(leaders_around_me[2][:member]).to eql('member_29')
  end

  it 'should return the correct information when calling percentile_for' do
    rank_members_in_leaderboard(12)

    expect(@leaderboard.percentile_for('member_1')).to eql(0)
    expect(@leaderboard.percentile_for('member_2')).to eql(9)
    expect(@leaderboard.percentile_for('member_3')).to eql(17)
    expect(@leaderboard.percentile_for('member_4')).to eql(25)
    expect(@leaderboard.percentile_for('member_12')).to eql(92)
  end

  it 'should return the correct information when calling score_for_percentile' do
    rank_members_in_leaderboard(5)

    expect(@leaderboard.score_for_percentile(0)).to eql(1.0)
    expect(@leaderboard.score_for_percentile(75)).to eql(4.0)
    expect(@leaderboard.score_for_percentile(87.5)).to eql(4.5)
    expect(@leaderboard.score_for_percentile(93.75)).to eql(4.75)
    expect(@leaderboard.score_for_percentile(100)).to eql(5.0)
  end

  it 'should not throw an exception when calling around_me with a member not in the leaderboard' do
    rank_members_in_leaderboard(Leaderboard::DEFAULT_PAGE_SIZE * 3 + 1)

    leaders_around_me = @leaderboard.around_me('jones', Leaderboard::DEFAULT_LEADERBOARD_REQUEST_OPTIONS.merge({:page_size => 3}))
    expect(leaders_around_me.size).to be(0)
  end

  it 'should not throw an exception when calling score_and_rank_for with a member not in the leaderboard' do
    score_and_rank_for_member = @leaderboard.score_and_rank_for('jones')

    expect(score_and_rank_for_member[:member]).to eql('jones')
    expect(score_and_rank_for_member[:score]).to be_nil
    expect(score_and_rank_for_member[:rank]).to be_nil
  end

  it 'should not throw an exception when calling ranked_in_list with a member not in the leaderboard' do
    rank_members_in_leaderboard

    members = ['member_1', 'member_5', 'jones']
    ranked_members = @leaderboard.ranked_in_list(members)

    expect(ranked_members.size).to be(3)
    expect(ranked_members[2][:rank]).to be_nil
  end

  it 'should not throw an exception when calling percentile_for with a member not in the leaderboard' do
    percentile = @leaderboard.percentile_for('jones')

    expect(percentile).to be_nil
  end

  it 'should allow you to change the score for a member not in the leaderboard' do
    expect(@leaderboard.score_for('jones')).to be_nil
    @leaderboard.change_score_for('jones', 5)
    expect(@leaderboard.score_for('jones')).to eql(5.0)
  end

  it 'should return the correct page when calling page_for a given member in the leaderboard' do
    expect(@leaderboard.page_for('jones')).to be(0)

    rank_members_in_leaderboard(20)

    expect(@leaderboard.page_for('member_17')).to be(1)
    expect(@leaderboard.page_for('member_11')).to be(1)
    expect(@leaderboard.page_for('member_10')).to be(1)
    expect(@leaderboard.page_for('member_1')).to be(1)

    expect(@leaderboard.page_for('member_17', 10)).to be(1)
    expect(@leaderboard.page_for('member_11', 10)).to be(1)
    expect(@leaderboard.page_for('member_10', 10)).to be(2)
    expect(@leaderboard.page_for('member_1', 10)).to be(2)
  end

  it 'should set an expire on the leaderboard' do
    rank_members_in_leaderboard

    @leaderboard.expire_leaderboard(3)
    @redis_connection.ttl(@leaderboard.leaderboard_name).tap do |ttl|
      expect(ttl).to be > 1
      expect(ttl).to be <= 3
    end
    @redis_connection.ttl(@leaderboard.send(:member_data_key, @leaderboard.leaderboard_name)).tap do |ttl|
      expect(ttl).to be > 1
      expect(ttl).to be <= 3
    end
  end

  it 'should set an expire on the leaderboard using a timestamp' do
    rank_members_in_leaderboard

    @leaderboard.expire_leaderboard_at((Time.now + 10).to_i)
    @redis_connection.ttl(@leaderboard.leaderboard_name).tap do |ttl|
      expect(ttl).to be > 1
      expect(ttl).to be <= 10
    end
    @redis_connection.ttl(@leaderboard.send(:member_data_key, @leaderboard.leaderboard_name)).tap do |ttl|
      expect(ttl).to be > 1
      expect(ttl).to be <= 10
    end
  end

  it 'should allow you to rank multiple members with a variable number of arguments' do
    expect(@leaderboard.total_members).to be(0)
    @leaderboard.rank_members('member_1', 1, 'member_10', 10)
    expect(@leaderboard.total_members).to be(2)
    expect(@leaderboard.leaders(1).first[:member]).to eql('member_10')
  end

  it 'should allow you to rank multiple members with an array' do
    expect(@leaderboard.total_members).to be(0)
    @leaderboard.rank_members(['member_1', 1, 'member_10', 10])
    expect(@leaderboard.total_members).to be(2)
    expect(@leaderboard.leaders(1).first[:member]).to eql('member_10')
  end

  it 'should allow you to set reverse after creating a leaderboard to see results in highest-to-lowest or lowest-to-highest order' do
    rank_members_in_leaderboard(25)

    leaders = @leaderboard.leaders(1)

    expect(leaders.size).to be(25)
    expect(leaders[0][:member]).to eql('member_25')
    expect(leaders[-2][:member]).to eql('member_2')
    expect(leaders[-1][:member]).to eql('member_1')
    expect(leaders[-1][:score].to_i).to be(1)

    @leaderboard.reverse = true

    leaders = @leaderboard.leaders(1)

    expect(leaders.size).to be(25)
    expect(leaders[0][:member]).to eql('member_1')
    expect(leaders[-2][:member]).to eql('member_24')
    expect(leaders[-1][:member]).to eql('member_25')
    expect(leaders[-1][:score].to_i).to be(25)
  end

  it 'should allow you to retrieve a given set of members from the leaderboard in a rank range' do
    rank_members_in_leaderboard(25)

    members = @leaderboard.members_from_rank_range(5, 9)
    expect(members.size).to be(5)
    expect(members[0][:member]).to eql('member_21')
    expect(members[0][:score].to_i).to be(21)
    expect(members[4][:member]).to eql('member_17')

    members = @leaderboard.members_from_rank_range(1, 1)
    expect(members.size).to be(1)
    expect(members[0][:member]).to eql('member_25')

    members = @leaderboard.members_from_rank_range(-1, 26)
    expect(members.size).to be(25)
    expect(members[0][:member]).to eql('member_25')
    expect(members[0][:score].to_i).to be(25)
    expect(members[24][:member]).to eql('member_1')
  end

  it 'should sort by rank if the :sort_by option is set to :rank' do
    rank_members_in_leaderboard(25)

    members = ['member_5', 'member_1', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, :sort_by => :rank)

    expect(ranked_members.size).to be(3)

    expect(ranked_members[0][:rank]).to be(16)
    expect(ranked_members[0][:score]).to eql(10.0)

    expect(ranked_members[1][:rank]).to be(21)
    expect(ranked_members[1][:score]).to eql(5.0)

    expect(ranked_members[2][:rank]).to be(25)
    expect(ranked_members[2][:score]).to eql(1.0)
  end

  it 'should sort by score if the :sort_by option is set to :score' do
    rank_members_in_leaderboard(25)

    members = ['member_5', 'member_1', 'member_10']
    ranked_members = @leaderboard.ranked_in_list(members, :sort_by => :score)

    expect(ranked_members.size).to be(3)

    expect(ranked_members[0][:rank]).to be(25)
    expect(ranked_members[0][:score]).to eql(1.0)

    expect(ranked_members[1][:rank]).to be(21)
    expect(ranked_members[1][:score]).to eql(5.0)

    expect(ranked_members[2][:rank]).to be(16)
    expect(ranked_members[2][:score]).to eql(10.0)
  end

  it 'should return nil for the score and rank for ranked_in_list if a member is not in the leaderboard' do
    rank_members_in_leaderboard

    ranked_members = @leaderboard.ranked_in_list(['jones'])

    expect(ranked_members.size).to be(1)
    expect(ranked_members[0][:member]).to eql('jones')
    expect(ranked_members[0][:score]).to be_nil
    expect(ranked_members[0][:rank]).to be_nil
  end

  it 'should rank a member in the leaderboard with conditional execution' do
    highscore_check = lambda do |member, current_score, score, member_data, leaderboard_options|
      return true if current_score.nil?
      return true if score > current_score
      false
    end

    expect(@leaderboard.total_members).to be(0)
    @leaderboard.rank_member_if(highscore_check, 'david', 1337)
    expect(@leaderboard.total_members).to be(1)
    expect(@leaderboard.score_for('david')).to eql(1337.0)
    @leaderboard.rank_member_if(highscore_check, 'david', 1336)
    expect(@leaderboard.score_for('david')).to eql(1337.0)
    @leaderboard.rank_member_if(highscore_check, 'david', 1338)
    expect(@leaderboard.score_for('david')).to eql(1338.0)
  end

  it 'should not delete all the member data when calling remove_member' do
    rank_members_in_leaderboard

    expect(@redis_connection.exists("name:member_data")).to be_truthy
    expect(@redis_connection.hgetall("name:member_data").size).to be(5)
    expect(@leaderboard.total_members).to be(5)
    @leaderboard.remove_member('member_1')
    expect(@redis_connection.exists("name:member_data")).to be_truthy
    expect(@redis_connection.hgetall("name:member_data").size).to be(4)
    expect(@leaderboard.total_members).to be(4)
  end

  it 'should return the members only if the :members_only option is passed' do
    rank_members_in_leaderboard(25)

    leaders = @leaderboard.leaders(1, :page_size => 10, :members_only => true)
    expect(leaders.size).to eq(10)
    leaders.collect { |leader| expect(leader.keys).to eq([:member]) }

    leaders = @leaderboard.all_leaders(:members_only => true)
    expect(leaders.size).to eq(25)
    leaders.collect { |leader| expect(leader.keys).to eq([:member]) }

    leaders = @leaderboard.members_from_score_range(10, 14, :members_only => true)
    expect(leaders.size).to eq(5)
    leaders.collect { |leader| expect(leader.keys).to eq([:member]) }

    leaders = @leaderboard.members_from_rank_range(1, 5, :page_size => 10, :members_only => true)
    expect(leaders.size).to eq(5)
    leaders.collect { |leader| expect(leader.keys).to eq([:member]) }

    leaders = @leaderboard.around_me('member_10', :page_size => 3, :members_only => true)
    expect(leaders.size).to eq(3)
    leaders.collect { |leader| expect(leader.keys).to eq([:member]) }

    leaders = @leaderboard.ranked_in_list(['member_1', 'member_25'], :members_only => true)
    expect(leaders.size).to eq(2)
    leaders.collect { |leader| expect(leader.keys).to eq([:member]) }
  end

  it 'should allow you to rank a member across multiple leaderboards' do
    @leaderboard.rank_member_across(['highscores', 'more_highscores'], 'david', 50000, { :member_name => "david" })
    expect(@leaderboard.leaders_in('highscores', 1).size).to eql(1)
    expect(@leaderboard.leaders_in('more_highscores', 1).size).to eql(1)
  end

  it 'should allow you to set custom keys for member, score, rank and member_data' do
    @leaderboard = Leaderboard.new('name',
      {
        :member_key => :custom_member_key,
        :rank_key => :custom_rank_key,
        :score_key => :custom_score_key,
        :member_data_key => :custom_member_data_key
      },
      {:host => "127.0.0.1", :db => 15})

    rank_members_in_leaderboard(5)
    leaders = @leaderboard.leaders(1, :with_member_data => true)
    leaders.each do |leader|
      expect(leader[:custom_member_key]).not_to be_nil
      expect(leader[:member]).to be_nil
      expect(leader[:custom_score_key]).not_to be_nil
      expect(leader[:score]).to be_nil
      expect(leader[:custom_rank_key]).not_to be_nil
      expect(leader[:rank]).to be_nil
      expect(leader[:custom_member_data_key]).not_to be_nil
      expect(leader[:member_data]).to be_nil
    end
  end

  it 'should allow you to change the :member_data_namespace option' do
    @leaderboard = Leaderboard.new('name', {:member_data_namespace => 'md'}, {:host => "127.0.0.1", :db => 15})
    rank_members_in_leaderboard

    expect(@redis_connection.exists("name:member_data")).to be_falsey
    expect(@redis_connection.exists("name:md")).to be_truthy
  end

  it 'should allow you to have a global member data namespace' do
    @leaderboard = Leaderboard.new('name', {:global_member_data => true}, {:host => "127.0.0.1", :db => 15})
    rank_members_in_leaderboard

    expect(@redis_connection.exists("member_data")).to be_truthy
    expect(@redis_connection.exists("name:member_data")).to be_falsey
  end
end
