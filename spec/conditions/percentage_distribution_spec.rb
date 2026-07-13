# frozen_string_literal: true

RSpec.describe 'Percentage condition distribution' do
  let(:ids) { (0...10_000).map { |i| "org-#{i}" } }

  def feature_for(percentage)
    condition = EightBall::Conditions::Percentage.new percentage: percentage, parameter: 'organization_id'
    EightBall::Feature.new 'DistFlag', [condition]
  end

  it 'should land within +/- 3 points of the configured percentage' do
    [10, 25, 50, 75, 90].each do |target|
      feature = feature_for(target)
      hits = ids.count { |id| feature.enabled?(organization_id: id) }
      observed = (hits.to_f / ids.size) * 100

      expect(observed).to be_within(3).of(target),
        "percentage #{target}: observed #{observed.round(2)}% (#{hits}/#{ids.size})"
    end
  end

  it 'should be perfectly sticky across two independent evaluation passes' do
    feature = feature_for(50)
    pass_one = ids.map { |id| feature.enabled?(organization_id: id) }
    pass_two = ids.map { |id| feature.enabled?(organization_id: id) }

    expect(pass_two).to eq pass_one
  end
end
