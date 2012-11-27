require 'spec_helper'

describe 'Leaderboard::VERSION' do
  it 'should be the correct version' do
    Leaderboard::VERSION.should == '3.0.0.rc2'
  end
end