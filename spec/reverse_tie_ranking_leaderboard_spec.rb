require 'spec_helper'
require 'tie_ranking_leaderboard'

describe 'TieRankingLeaderboard (reverse option)' do
  before(:each) do
    @redis_connection = Redis.new(:host => "127.0.0.1", :db => 15)
  end

  after(:each) do
    @redis_connection.flushdb
    @redis_connection.client.disconnect
  end

  context 'ties' do
    it 'should delete the ties ranking internal leaderboard when you delete a leaderboard configured for ties' do
      leaderboard = TieRankingLeaderboard.new('ties', {:reverse => true}, {:host => "127.0.0.1", :db => 15})
      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_3', 30)
      leaderboard.rank_member('member_4', 30)
      leaderboard.rank_member('member_5', 10)

      expect(@redis_connection.exists(leaderboard.send(:ties_leaderboard_key, leaderboard.leaderboard_name))).to be_truthy
      leaderboard.delete_leaderboard
      expect(@redis_connection.exists(leaderboard.send(:ties_leaderboard_key, leaderboard.leaderboard_name))).to be_falsey

      leaderboard.disconnect
    end

    it 'should retrieve the correct rankings for #leaders' do
      leaderboard = TieRankingLeaderboard.new('ties', {:reverse => true}, {:host => "127.0.0.1", :db => 15})
      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_3', 30)
      leaderboard.rank_member('member_4', 30)
      leaderboard.rank_member('member_5', 10)

      leaderboard.leaders(1).tap do |leaders|
        expect(leaders[0][:rank]).to eq(1)
        expect(leaders[1][:rank]).to eq(2)
        expect(leaders[2][:rank]).to eq(2)
        expect(leaders[3][:rank]).to eq(3)
        expect(leaders[4][:rank]).to eq(3)
      end

      leaderboard.disconnect
    end

    it 'should retrieve the correct rankings for #leaders with different page sizes' do
      leaderboard = TieRankingLeaderboard.new('ties', {:reverse => true}, {:host => "127.0.0.1", :db => 15})
      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_3', 30)
      leaderboard.rank_member('member_4', 30)
      leaderboard.rank_member('member_5', 10)
      leaderboard.rank_member('member_6', 50)
      leaderboard.rank_member('member_7', 50)
      leaderboard.rank_member('member_8', 30)
      leaderboard.rank_member('member_9', 30)
      leaderboard.rank_member('member_10', 10)

      leaderboard.leaders(1, :page_size => 3).tap do |leaders|
        expect(leaders[0][:rank]).to eq(1)
        expect(leaders[1][:rank]).to eq(1)
        expect(leaders[2][:rank]).to eq(2)
      end

      leaderboard.leaders(2, :page_size => 3).tap do |leaders|
        expect(leaders[0][:rank]).to eq(2)
        expect(leaders[1][:rank]).to eq(2)
        expect(leaders[2][:rank]).to eq(2)
      end

      leaderboard.disconnect
    end

    it 'should retrieve the correct rankings for #around_me' do
      leaderboard = TieRankingLeaderboard.new('ties', {:reverse => true}, {:host => "127.0.0.1", :db => 15})
      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_3', 30)
      leaderboard.rank_member('member_4', 30)
      leaderboard.rank_member('member_5', 10)
      leaderboard.rank_member('member_6', 50)
      leaderboard.rank_member('member_7', 50)
      leaderboard.rank_member('member_8', 30)
      leaderboard.rank_member('member_9', 30)
      leaderboard.rank_member('member_10', 10)

      leaderboard.around_me('member_3', :page_size => 3).tap do |leaders|
        expect(leaders[0][:rank]).to eq(1)
        expect(leaders[1][:rank]).to eq(2)
        expect(leaders[2][:rank]).to eq(2)
      end

      leaderboard.disconnect
    end

    it 'should support that removing a single member will also remove their score from the tie scores leaderboard when appropriate' do
      leaderboard = TieRankingLeaderboard.new('ties', {:reverse => true}, {:host => "127.0.0.1", :db => 15})
      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_3', 30)

      leaderboard.remove_member('member_1')
      expect(leaderboard.total_members_in(leaderboard.send(:ties_leaderboard_key, leaderboard.leaderboard_name))).to eq(2)
      leaderboard.remove_member('member_2')
      expect(leaderboard.total_members_in(leaderboard.send(:ties_leaderboard_key, leaderboard.leaderboard_name))).to eq(1)
      leaderboard.remove_member('member_3')
      expect(leaderboard.total_members_in(leaderboard.send(:ties_leaderboard_key, leaderboard.leaderboard_name))).to eq(0)

      leaderboard.disconnect
    end

    it 'should allow you to retrieve the rank of a single member using #rank_for' do
      leaderboard = TieRankingLeaderboard.new('ties', {:reverse => true}, {:host => "127.0.0.1", :db => 15})
      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_3', 30)

      expect(leaderboard.rank_for('member_1')).to eq(2)
      expect(leaderboard.rank_for('member_2')).to eq(2)
      expect(leaderboard.rank_for('member_3')).to eq(1)

      leaderboard.disconnect
    end

    it 'should allow you to retrieve the score and rank of a single member using #score_and_rank_for' do
      leaderboard = TieRankingLeaderboard.new('ties', {:reverse => true}, {:host => "127.0.0.1", :db => 15})
      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_3', 30)

      expect(leaderboard.score_and_rank_for('member_1')[:rank]).to eq(2)
      expect(leaderboard.score_and_rank_for('member_2')[:rank]).to eq(2)
      expect(leaderboard.score_and_rank_for('member_3')[:rank]).to eq(1)

      leaderboard.disconnect
    end

    it 'should have the correct rankings and scores when using change_score_for' do
      leaderboard = TieRankingLeaderboard.new('ties', {:reverse => true}, {:host => "127.0.0.1", :db => 15})

      leaderboard.rank_member('member_1', 50)
      leaderboard.rank_member('member_2', 50)
      leaderboard.rank_member('member_3', 30)
      leaderboard.rank_member('member_4', 30)
      leaderboard.rank_member('member_5', 10)
      leaderboard.change_score_for('member_3', 10)

      expect(leaderboard.rank_for('member_3')).to eq(3)
      expect(leaderboard.rank_for('member_4')).to eq(2)
      expect(leaderboard.score_for('member_3')).to eq(40.0)

      leaderboard.disconnect
    end

    it 'should have the correct rankings and scores when using change_score_for (varying scores)' do
      leaderboard = TieRankingLeaderboard.new('ties', {:reverse => true}, {:host => "127.0.0.1", :db => 15})

      leaderboard.rank_member('member_1', 5)
      leaderboard.rank_member('member_2', 4)
      leaderboard.rank_member('member_3', 3)
      leaderboard.rank_member('member_4', 2)
      leaderboard.rank_member('member_5', 1)
      leaderboard.change_score_for('member_3', 0.5)

      expect(leaderboard.rank_for('member_3')).to eq(3)
      expect(leaderboard.rank_for('member_4')).to eq(2)
      expect(leaderboard.score_for('member_3')).to eq(3.5)

      leaderboard.disconnect
    end

    it 'should output the correct rank when initial score is 0 and then later scores are tied' do
      # See https://github.com/agoragames/leaderboard/issues/53
      leaderboard = TieRankingLeaderboard.new('ties', {:reverse => true}, {:host => "127.0.0.1", :db => 15})

      leaderboard.rank_members('member_1', 0, 'member_2', 0)
      expect(leaderboard.rank_for('member_1')).to eq(1)
      expect(leaderboard.rank_for('member_2')).to eq(1)
      leaderboard.rank_members('member_1', 1, 'member_2', 1)
      expect(leaderboard.rank_for('member_1')).to eq(1)
      expect(leaderboard.rank_for('member_2')).to eq(1)
      leaderboard.rank_members('member_1', 1, 'member_2', 1, 'member_3', 4)
      expect(leaderboard.rank_for('member_3')).to eq(2)
      expect(leaderboard.rank_for('member_1')).to eq(1)
      expect(leaderboard.rank_for('member_2')).to eq(1)
    end
  end
end