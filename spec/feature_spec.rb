# frozen_string_literal: true

RSpec.describe EightBall::Feature do
  describe 'enabled?' do
    it 'should return true if no conditions' do
      feature = EightBall::Feature.new 'NoConditions'
      expect(feature.enabled?).to be true
    end

    it 'should return true if one of the enabled_for conditions is satisfied' do
      satisfied = EightBall::Conditions::Always.new
      unsatisfied = EightBall::Conditions::Never.new

      feature = EightBall::Feature.new 'Feature', [satisfied, unsatisfied]
      expect(feature.enabled?).to be true
    end

    it 'should return true if all of the enabled_for conditions are satisfied' do
      satisfied1 = EightBall::Conditions::Always.new
      satisfied2 = EightBall::Conditions::Always.new

      feature = EightBall::Feature.new 'Feature', [satisfied1, satisfied2]
      expect(feature.enabled?).to be true
    end

    it 'should return false if none of the enabled_for conditions are satisfied' do
      unsatisfied1 = EightBall::Conditions::Never.new
      unsatisfied2 = EightBall::Conditions::Never.new

      feature = EightBall::Feature.new 'Feature', [unsatisfied1, unsatisfied2]
      expect(feature.enabled?).to be false
    end

    it 'should return true if enabled_for satisfied and disabled_for not satisfied' do
      satisfied = EightBall::Conditions::Always.new
      unsatisfied = EightBall::Conditions::Never.new

      feature = EightBall::Feature.new 'Feature', [satisfied], [unsatisfied]
      expect(feature.enabled?).to be true
    end

    it 'should return false if no enabled_for provided and disabled_for is satisfied' do
      satisfied = EightBall::Conditions::Always.new

      feature = EightBall::Feature.new 'Feature', nil, [satisfied]
      expect(feature.enabled?).to be false
    end

    it 'should return true if no enabled_for provided and disabled_for is not satisfied' do
      unsatisfied = EightBall::Conditions::Never.new

      feature = EightBall::Feature.new 'Feature', nil, [unsatisfied]
      expect(feature.enabled?).to be true
    end

    it 'should return false if enabled_for is satisfied and disabled_for is satisfied' do
      satisfied1 = EightBall::Conditions::Always.new
      satisfied2 = EightBall::Conditions::Always.new

      feature = EightBall::Feature.new 'Feature', [satisfied1], [satisfied2]
      expect(feature.enabled?).to be false
    end

    it 'should raise an Exception if a parameter is missing' do
      condition = EightBall::Conditions::List.new parameter: 'param1', values: [1, 2]
      feature = EightBall::Feature.new 'Feature', condition

      expect { feature.enabled? }.to raise_error ArgumentError, 'Missing parameter param1'
    end

    it 'should pass parameter to satisfied?' do
      condition = EightBall::Conditions::List.new parameter: 'param1', values: [1, 2]

      expect(condition).to receive(:satisfied?).with 1

      feature = EightBall::Feature.new 'Feature', condition
      feature.enabled? param1: 1
    end
  end

  describe '==' do
    it 'should return false if the names do not match' do
      f1 = EightBall::Feature.new 'name1'
      f2 = EightBall::Feature.new 'name2'

      expect(f1 == f2).to be false
    end

    it 'should return false if the number of "enabled for" conditions differ' do
      f1 = EightBall::Feature.new 'name1', [EightBall::Conditions::Always.new, EightBall::Conditions::Always.new]
      f2 = EightBall::Feature.new 'name1', [EightBall::Conditions::Always.new]

      expect(f1 == f2).to be false
    end

    it 'should return false if the number of "disabled for" conditions differ' do
      f1 = EightBall::Feature.new 'name1', [], [EightBall::Conditions::Always.new, EightBall::Conditions::Always.new]
      f2 = EightBall::Feature.new 'name1', [], [EightBall::Conditions::Always.new]

      expect(f1 == f2).to be false
    end

    it 'should return true if every "enabled for" condition is matched, regardless of order' do
      f1 = EightBall::Feature.new('name1', [
        EightBall::Conditions::Range.new(min: 1, max: 2),
        EightBall::Conditions::List.new(values: [1, 2, 3])
      ])
      f2 = EightBall::Feature.new('name1', [
        EightBall::Conditions::List.new(values: [1, 2, 3]),
        EightBall::Conditions::Range.new(min: 1, max: 2)
      ])

      expect(f1 == f2).to be true
    end

    it 'should return false if a single "enabled for" condition is not matched' do
      f1 = EightBall::Feature.new('name1', [
        EightBall::Conditions::Range.new(min: 1, max: 2),
        EightBall::Conditions::List.new(values: [1, 2, 3])
      ])
      f2 = EightBall::Feature.new('name1', [
        EightBall::Conditions::Range.new(min: 3, max: 4),
        EightBall::Conditions::List.new(values: [1, 2, 3])
      ])

      expect(f1 == f2).to be false
    end

    it 'should return true if every "disabled for" condition is matched, regardless of order' do
      f1 = EightBall::Feature.new('name1', [], [
        EightBall::Conditions::Range.new(min: 1, max: 2),
        EightBall::Conditions::List.new(values: [1, 2, 3])
      ])
      f2 = EightBall::Feature.new('name1', [], [
        EightBall::Conditions::List.new(values: [1, 2, 3]),
        EightBall::Conditions::Range.new(min: 1, max: 2)
      ])

      expect(f1 == f2).to be true
    end

    it 'should return false if a single "disabled for" condition is not matched' do
      f1 = EightBall::Feature.new('name1', [], [
        EightBall::Conditions::Range.new(min: 1, max: 2),
        EightBall::Conditions::List.new(values: [1, 2, 3])
      ])
      f2 = EightBall::Feature.new('name1', [], [
        EightBall::Conditions::Range.new(min: 3, max: 4),
        EightBall::Conditions::List.new(values: [1, 2, 3])
      ])

      expect(f1 == f2).to be false
    end
  end

  describe 'metadata' do
    it 'should default to nil when not provided' do
      feature = EightBall::Feature.new 'NoMeta'
      expect(feature.metadata).to be_nil
    end

    it 'should expose the metadata hash when provided' do
      meta = { 'type' => 'experiment', 'owner' => 'growth', 'expires_at' => '2026-12-31' }
      feature = EightBall::Feature.new 'WithMeta', [], [], metadata: meta
      expect(feature.metadata).to eq meta
    end

    it 'should not affect evaluation' do
      meta = { 'type' => 'experiment' }
      feature = EightBall::Feature.new 'WithMeta', [], [], metadata: meta
      expect(feature.enabled?).to be true
    end
  end

  describe 'un_evaluable!' do
    it 'should default to evaluable' do
      feature = EightBall::Feature.new 'Feature', [EightBall::Conditions::Always.new]
      expect(feature.un_evaluable?).to be false
      expect(feature.enabled?).to be true
    end

    it 'should force enabled? to false once marked, regardless of conditions' do
      feature = EightBall::Feature.new 'Feature', [EightBall::Conditions::Always.new]
      feature.un_evaluable!

      expect(feature.un_evaluable?).to be true
      expect(feature.enabled?).to be false
    end

    it 'should not raise for missing parameters when un-evaluable' do
      condition = EightBall::Conditions::List.new parameter: 'param1', values: [1, 2]
      feature = EightBall::Feature.new 'Feature', condition
      feature.un_evaluable!

      # Normally this raises ArgumentError (missing param1); un-evaluable must short-circuit first.
      expect(feature.enabled?).to be false
    end
  end

  describe 'percentage condition integration' do
    it 'should inject the flag name as the bucket salt at construction' do
      condition = EightBall::Conditions::Percentage.new percentage: 50, parameter: 'account_id'
      EightBall::Feature.new 'SaltedFlag', [condition]

      expect(condition.flag_name).to eq 'SaltedFlag'
    end

    it 'should evaluate a percentage condition end-to-end without raising' do
      condition = EightBall::Conditions::Percentage.new percentage: 100, parameter: 'account_id'
      feature = EightBall::Feature.new 'Exp', [condition]

      # percentage 100 => always on; the key assertion is that flag_name was
      # injected so satisfied? does not raise the "flag_name has not been set" error.
      expect(feature.enabled?(account_id: 'acct-1')).to be true
    end

    it 'should give the same verdict for the same subject across repeated evaluations (sticky)' do
      condition = EightBall::Conditions::Percentage.new percentage: 50, parameter: 'account_id'
      feature = EightBall::Feature.new 'Sticky', [condition]

      first = feature.enabled?(account_id: 'acct-77')
      5.times { expect(feature.enabled?(account_id: 'acct-77')).to eq first }
    end

    it 'should not inject flag_name into legacy conditions' do
      list = EightBall::Conditions::List.new values: [1, 2], parameter: 'account_id'
      expect { EightBall::Feature.new 'Legacy', [list] }.not_to raise_error
      expect(list).not_to respond_to(:flag_name)
    end
  end
end
