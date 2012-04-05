require 'spec_helper'

describe Leaderboard do
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
end