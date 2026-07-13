# frozen_string_literal: true

RSpec.describe EightBall::Conditions do
  describe 'by_name' do
    it 'should be case insensitive' do
      expect(EightBall::Conditions.by_name('always')).to eq EightBall::Conditions::Always
      expect(EightBall::Conditions.by_name('ALWAYS')).to eq EightBall::Conditions::Always
      expect(EightBall::Conditions.by_name('Always')).to eq EightBall::Conditions::Always
      expect(EightBall::Conditions.by_name('aLwAyS')).to eq EightBall::Conditions::Always
    end

    it 'should resolve percentage case-insensitively' do
      expect(EightBall::Conditions.by_name('percentage')).to eq EightBall::Conditions::Percentage
      expect(EightBall::Conditions.by_name('Percentage')).to eq EightBall::Conditions::Percentage
      expect(EightBall::Conditions.by_name('PERCENTAGE')).to eq EightBall::Conditions::Percentage
    end
  end
end
