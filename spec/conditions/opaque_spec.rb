# frozen_string_literal: true

RSpec.describe EightBall::Conditions::Opaque do
  let(:raw) { { type: 'made_up', parameter: 'account_id' } }

  it 'is never satisfied' do
    expect(EightBall::Conditions::Opaque.new(raw).satisfied?('anything')).to be false
    expect(EightBall::Conditions::Opaque.new(raw).satisfied?).to be false
  end

  it 're-emits its raw input verbatim' do
    expect(EightBall::Conditions::Opaque.new(raw).to_wire).to eq raw
  end

  it 'is equal when wrapping equal raw input' do
    expect(EightBall::Conditions::Opaque.new(raw)).to eq EightBall::Conditions::Opaque.new(raw.dup)
    expect(EightBall::Conditions::Opaque.new(raw)).not_to eq EightBall::Conditions::Opaque.new(type: 'other')
  end
end
