require 'spec_helper'

describe 'Leaderboard::VERSION' do
  it 'should be the correct version' do
    expect(Leaderboard::VERSION).to eq('3.12.0')
  end
end