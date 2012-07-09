require 'spec_helper'

describe 'Leaderboard::VERSION' do
  it 'should be the correct version' do
    Leaderboard::VERSION.should == '2.3.0'
  end
end