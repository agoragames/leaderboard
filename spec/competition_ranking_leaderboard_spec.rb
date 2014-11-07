require 'spec_helper'
require 'competition_ranking_leaderboard'

describe 'CompetitionRankingLeaderboard' do
  before(:each) do
    @redis_connection = Redis.new(:host => "127.0.0.1", :db => 15)
  end

  after(:each) do
    @redis_connection.flushdb
    @redis_connection.client.disconnect
  end

  context 'ties' do
    it 'should retrieve the correct rankings for #leaders' do
      leaderboard = CompetitionRankingLeaderboard.new('ties', Leaderboard::DEFAULT_OPTIONS, {:host => "127.0.0.1", :db => 15})
      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_3', 30)
      leaderboard.rank_member('member_4', 30)
      leaderboard.rank_member('member_5', 10)

      leaderboard.leaders(1).tap do |leaders|
        expect(leaders[0][:rank]).to eq(1)
        expect(leaders[1][:rank]).to eq(1)
        expect(leaders[2][:rank]).to eq(3)
        expect(leaders[3][:rank]).to eq(3)
        expect(leaders[4][:rank]).to eq(5)
      end

      leaderboard.disconnect
    end

    it 'should retrieve the correct rankings for #leaders with different page sizes' do
      leaderboard = CompetitionRankingLeaderboard.new('ties', Leaderboard::DEFAULT_OPTIONS, {:host => "127.0.0.1", :db => 15})
      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_6', 50)
      leaderboard.rank_member('member_7', 50)
      leaderboard.rank_member('member_3', 30)
      leaderboard.rank_member('member_4', 30)
      leaderboard.rank_member('member_8', 30)
      leaderboard.rank_member('member_9', 30)
      leaderboard.rank_member('member_5', 10)
      leaderboard.rank_member('member_10', 10)

      leaderboard.leaders(1, :page_size => 3).tap do |leaders|
        expect(leaders[0][:rank]).to eq(1)
        expect(leaders[1][:rank]).to eq(1)
        expect(leaders[2][:rank]).to eq(1)
      end

      leaderboard.leaders(2, :page_size => 3).tap do |leaders|
        expect(leaders[0][:rank]).to eq(1)
        expect(leaders[1][:rank]).to eq(5)
        expect(leaders[2][:rank]).to eq(5)
      end

      leaderboard.disconnect
    end

    it 'should retrieve the correct rankings for #around_me' do
      leaderboard = CompetitionRankingLeaderboard.new('ties', Leaderboard::DEFAULT_OPTIONS, {:host => "127.0.0.1", :db => 15})
      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_6', 50)
      leaderboard.rank_member('member_7', 50)
      leaderboard.rank_member('member_3', 30)
      leaderboard.rank_member('member_4', 30)
      leaderboard.rank_member('member_8', 30)
      leaderboard.rank_member('member_9', 30)
      leaderboard.rank_member('member_5', 10)
      leaderboard.rank_member('member_10', 10)

      leaderboard.around_me('member_4').tap do |leaders|
        expect(leaders[0][:rank]).to eq(1)
        expect(leaders[4][:rank]).to eq(5)
        expect(leaders[9][:rank]).to eq(9)
      end

      leaderboard.disconnect
    end

    it 'should allow you to retrieve the rank of a single member using #rank_for' do
      leaderboard = CompetitionRankingLeaderboard.new('ties', Leaderboard::DEFAULT_OPTIONS, {:host => "127.0.0.1", :db => 15})
      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_3', 30)

      expect(leaderboard.rank_for('member_1')).to eq(1)
      expect(leaderboard.rank_for('member_2')).to eq(1)
      expect(leaderboard.rank_for('member_3')).to eq(3)

      leaderboard.disconnect
    end

    it 'should allow you to retrieve the score and rank of a single member using #score_and_rank_for' do
      leaderboard = CompetitionRankingLeaderboard.new('ties', Leaderboard::DEFAULT_OPTIONS, {:host => "127.0.0.1", :db => 15})
      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_3', 30)

      expect(leaderboard.score_and_rank_for('member_1')[:rank]).to eq(1)
      expect(leaderboard.score_and_rank_for('member_2')[:rank]).to eq(1)
      expect(leaderboard.score_and_rank_for('member_3')[:rank]).to eq(3)

      leaderboard.disconnect
    end

    it 'should have the correct rankings and scores when using change_score_for' do
      leaderboard = CompetitionRankingLeaderboard.new('ties', Leaderboard::DEFAULT_OPTIONS, {:host => "127.0.0.1", :db => 15})

      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_3', 30)
      leaderboard.rank_member('member_4', 30)
      leaderboard.rank_member('member_5', 10)
      leaderboard.change_score_for('member_3', 10)

      expect(leaderboard.rank_for('member_3')).to eq(3)
      expect(leaderboard.rank_for('member_4')).to eq(4)
      expect(leaderboard.score_for('member_3')).to eq(40.0)

      leaderboard.disconnect
    end
  end
end