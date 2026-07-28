# frozen_string_literal: true

RSpec.describe EightBall::Marshallers::Json do
  let(:marshaller) { EightBall::Marshallers::Json.new }

  describe 'marshall' do
    it 'should convert an array of Features into JSON' do
      features = [
        EightBall::Feature.new(
          'WithConditions',
          [EightBall::Conditions::List.new(values: [1, 2, 3, 4], parameter: 'param1')],
          [EightBall::Conditions::Never.new]
        )
      ]

      json = '[{"name":"WithConditions","enabledFor":[{"type":"list","values":[1,2,3,4],"parameter":"param1"}],"disabledFor":[{"type":"never"}]}]'

      expect(marshaller.marshall(features)).to eq json
    end

    it 'should not include disabledFor key if empty' do
      features = [EightBall::Feature.new('WithConditions', [EightBall::Conditions::Always.new])]

      json = '[{"name":"WithConditions","enabledFor":[{"type":"always"}]}]'

      expect(marshaller.marshall(features)).to eq json
    end

    it 'should not include enabledFor key if empty' do
      features = [EightBall::Feature.new('WithConditions', nil, [EightBall::Conditions::Always.new])]

      json = '[{"name":"WithConditions","disabledFor":[{"type":"always"}]}]'

      expect(marshaller.marshall(features)).to eq json
    end

    it 'should not include "parameter" and "value" keys if not present' do
      features = [
        EightBall::Feature.new(
          'WithConditions',
          [EightBall::Conditions::Always.new],
          [EightBall::Conditions::Never.new]
        )
      ]

      json = '[{"name":"WithConditions","enabledFor":[{"type":"always"}],"disabledFor":[{"type":"never"}]}]'

      expect(marshaller.marshall(features)).to eq json
    end

    it 'should include top-level metadata when present' do
      features = [
        EightBall::Feature.new(
          'WithMeta',
          [EightBall::Conditions::Always.new],
          [],
          metadata: { 'type' => 'experiment', 'owner' => 'growth', 'expires_at' => '2026-12-31' }
        )
      ]

      json = '[{"name":"WithMeta","enabledFor":[{"type":"always"}],"metadata":{"type":"experiment","owner":"growth","expiresAt":"2026-12-31"}}]'

      expect(marshaller.marshall(features)).to eq json
    end

    it 'should omit metadata key when nil' do
      features = [EightBall::Feature.new('NoMeta', [EightBall::Conditions::Always.new])]

      json = '[{"name":"NoMeta","enabledFor":[{"type":"always"}]}]'

      expect(marshaller.marshall(features)).to eq json
    end

    it 'should marshall a percentage condition without leaking flag_name (fail-closed allowlist)' do
      condition = EightBall::Conditions::Percentage.new(percentage: 25, parameter: 'account_id')
      condition.flag_name = 'Experiment' # runtime injection; must NEVER appear in JSON

      features = [EightBall::Feature.new('Experiment', [condition])]

      # parameter serializes snake_case: Base#parameter= snake-cases on construction, and
      # to_camelback_keys only transforms keys, not values.
      json = '[{"name":"Experiment","enabledFor":[{"type":"percentage","percentage":25,"parameter":"account_id"}]}]'

      result = marshaller.marshall(features)
      expect(result).to eq json
      # The allowlist guarantees the runtime salt is never serialized, by construction.
      expect(result).not_to include 'flagName'
      expect(result).not_to include 'flag_name'
    end

    it 'should serialize coerce on a list condition only when enabled' do
      coerced = [
        EightBall::Feature.new('Coerced', [EightBall::Conditions::List.new(values: [1], parameter: 'param1', coerce: true)])
      ]
      # Exact substring, so the key order (coerce before parameter) that keeps the
      # wire byte-identical with eight-ball-ts cannot silently regress.
      expect(marshaller.marshall(coerced)).to include '"values":[1],"coerce":true,"parameter":"param1"'

      default = [
        EightBall::Feature.new('Default', [EightBall::Conditions::List.new(values: [1], parameter: 'param1')])
      ]
      expect(marshaller.marshall(default)).not_to include 'coerce'

      # A truthy non-boolean serializes as a canonical true, never the raw value.
      truthy = [
        EightBall::Feature.new('Truthy', [EightBall::Conditions::List.new(values: [1], parameter: 'param1', coerce: 1)])
      ]
      expect(marshaller.marshall(truthy)).to include '"coerce":true'
      expect(marshaller.marshall(truthy)).not_to include '"coerce":1'

      # An explicit false is omitted from the wire, same as the default.
      explicit_false = [
        EightBall::Feature.new('ExplicitFalse', [EightBall::Conditions::List.new(values: [1], parameter: 'param1', coerce: false)])
      ]
      expect(marshaller.marshall(explicit_false)).not_to include 'coerce'
    end

    it 'should round-trip every condition type through the allowlist unchanged' do
      features = [
        EightBall::Feature.new('AlwaysFlag', [EightBall::Conditions::Always.new]),
        EightBall::Feature.new('NeverFlag', [EightBall::Conditions::Never.new]),
        EightBall::Feature.new('ListFlag', [EightBall::Conditions::List.new(values: [1, 2, 3], parameter: 'param1')]),
        EightBall::Feature.new('RangeFlag', [EightBall::Conditions::Range.new(min: 1, max: 5, parameter: 'accountId')]),
        EightBall::Feature.new('PctFlag', [EightBall::Conditions::Percentage.new(percentage: 30, parameter: 'accountId')])
      ]

      json = marshaller.marshall(features)

      expect(json).to include '{"type":"always"}'
      expect(json).to include '{"type":"never"}'
      expect(json).to include '{"type":"list","values":[1,2,3],"parameter":"param1"}'
      expect(json).to include '{"type":"range","min":1,"max":5,"parameter":"account_id"}'
      expect(json).to include '{"type":"percentage","percentage":30,"parameter":"account_id"}'
    end
  end

  describe 'unmarshall' do
    it 'should raise error if provided JSON is not an array' do
      json = %(
        {
          "name": "NoConditions"
        }
      )

      expect { marshaller.unmarshall(json) }.to raise_error ArgumentError, 'JSON input was not an array'
    end

    it 'should convert JSON into an array of Features' do
      json = %(
        [{
          "name": "NoConditions"
        }, {
          "name": "WithConditions",
          "enabledFor": [{
            "type": "list",
            "parameter": "param1",
            "values": [1, 2, 3, 4]
          }],
          "disabledFor": [{
            "type": "never"
          }]
        }]
      )

      features = marshaller.unmarshall json

      expect(features.size).to be 2

      expect(features[0].name).to eq 'NoConditions'
      expect(features[0].enabled_for.size).to be 0
      expect(features[0].disabled_for.size).to be 0

      expect(features[1].name).to eq 'WithConditions'
      expect(features[1].enabled_for.size).to be 1
      expect(features[1].enabled_for[0]).to be_a EightBall::Conditions::List
      expect(features[1].enabled_for[0].parameter).to eq 'param1'
      expect(features[1].enabled_for[0].values).to contain_exactly 1, 2, 3, 4
      expect(features[1].disabled_for.size).to be 1
      expect(features[1].disabled_for[0]).to be_a EightBall::Conditions::Never
    end

    it 'should round-trip a coerce-enabled list condition' do
      json = %([{ "name": "Coerced", "enabledFor": [{ "type": "list", "parameter": "param1", "values": [1], "coerce": true }] }])

      features = marshaller.unmarshall(json)
      condition = features[0].enabled_for[0]

      expect(condition).to be_a EightBall::Conditions::List
      expect(condition.coerce).to be true
      expect(condition.satisfied?('1')).to be true

      # Re-marshalling preserves the coerce flag.
      expect(marshaller.marshall(features)).to include '"coerce":true'
    end

    it 'should default to [] if JSON parsing error occurs' do
      allow(JSON).to receive(:parse).and_raise JSON::ParserError

      features = marshaller.unmarshall ''

      expect(features).to eq []
    end

    it 'should round-trip metadata through unmarshall and marshall' do
      json = %(
        [{
          "name": "WithMeta",
          "enabledFor": [{ "type": "always" }],
          "metadata": { "type": "experiment", "owner": "growth", "expiresAt": "2026-12-31" }
        }]
      )

      features = marshaller.unmarshall json

      expect(features.size).to be 1
      # Keys are symbols: unmarshall parses with symbolize_names, so metadata
      # (like every other unmarshalled hash) comes back symbol-keyed and snake-cased.
      expect(features[0].metadata).to eq(
        type: 'experiment', owner: 'growth', expires_at: '2026-12-31'
      )

      # Round-trip: marshalling what we unmarshalled reproduces the camelCase wire form.
      expect(marshaller.marshall(features)).to eq(
        '[{"name":"WithMeta","enabledFor":[{"type":"always"}],"metadata":{"type":"experiment","owner":"growth","expiresAt":"2026-12-31"}}]'
      )
    end

    it 'should leave metadata nil when absent' do
      json = %([{ "name": "NoMeta" }])

      features = marshaller.unmarshall json

      expect(features[0].metadata).to be_nil
    end

    it 'should mark only the offending feature un-evaluable on unknown condition type, not raise' do
      json = %(
        [{
          "name": "GoodFlag",
          "enabledFor": [{ "type": "always" }]
        }, {
          "name": "BadFlag",
          "enabledFor": [{ "type": "made_up_type", "parameter": "accountId", "values": [1] }]
        }]
      )

      # Must not raise and must not return []; the bad flag fails closed, the rest parse.
      features = nil
      expect { features = marshaller.unmarshall(json) }.not_to raise_error

      expect(features.size).to be 2

      good = features.find { |f| f.name == 'GoodFlag' }
      bad = features.find { |f| f.name == 'BadFlag' }

      # GoodFlag still evaluates normally.
      expect(good.un_evaluable?).to be false
      expect(good.enabled?).to be true

      # BadFlag is forced OFF and never evaluates its (unparseable) condition.
      expect(bad.un_evaluable?).to be true
      expect(bad.enabled?).to be false
    end

    it 'should log a warning naming the flag and the unknown type' do
      json = %([{ "name": "BadFlag", "enabledFor": [{ "type": "made_up_type" }] }])

      logger = instance_double(Logger)
      allow(EightBall).to receive(:logger).and_return(logger)
      expect(logger).to receive(:warn) do |&block|
        message = block.call
        expect(message).to include('BadFlag')
        expect(message).to include('made_up_type')
      end

      marshaller.unmarshall json
    end

    it 'should unmarshall a percentage condition' do
      json = %(
        [{
          "name": "Experiment",
          "enabledFor": [{ "type": "percentage", "parameter": "accountId", "percentage": 25 }]
        }]
      )

      features = marshaller.unmarshall json
      condition = features[0].enabled_for[0]

      expect(condition).to be_a EightBall::Conditions::Percentage
      expect(condition.parameter).to eq 'account_id'
      expect(condition.percentage).to eq 25
    end

    it 'should fail only the offending flag closed on a malformed known condition, not raise' do
      # A KNOWN type with invalid params (range missing min/max) raises ArgumentError
      # from the condition constructor; it must fail that flag closed, not black out the blob.
      json = %(
        [{
          "name": "GoodFlag",
          "enabledFor": [{ "type": "always" }]
        }, {
          "name": "BadRange",
          "enabledFor": [{ "type": "range", "parameter": "accountId" }]
        }]
      )

      features = nil
      expect { features = marshaller.unmarshall(json) }.not_to raise_error

      expect(features.size).to be 2
      expect(features.find { |f| f.name == 'GoodFlag' }.enabled?).to be true

      bad = features.find { |f| f.name == 'BadRange' }
      expect(bad.un_evaluable?).to be true
      expect(bad.enabled?).to be false
    end

    it 'should preserve an un-evaluable flag verbatim across a marshall round-trip (no OFF->ON flip, no definition loss)' do
      json = %([{ "name": "BadFlag", "enabledFor": [{ "type": "made_up_type", "parameter": "accountId" }] }])

      once = marshaller.unmarshall(json)
      expect(once[0].un_evaluable?).to be true
      expect(once[0].enabled?).to be false

      # Re-marshalling must re-emit the original (unparseable) condition, not drop it.
      remarshalled = marshaller.marshall(once)
      expect(remarshalled).to include 'made_up_type'

      # Re-reading the re-marshalled blob keeps the flag fail-closed (OFF), never flips it ON.
      twice = marshaller.unmarshall(remarshalled)
      expect(twice[0].un_evaluable?).to be true
      expect(twice[0].enabled?).to be false
    end

    it 'should fail only the offending flag closed on a non-object condition entry, not raise' do
      # A condition entry that is not an object (string/number/null) must not blow up the
      # whole unmarshall; it fails only that flag closed, like any other unbuildable condition.
      json = %(
        [{
          "name": "GoodFlag",
          "enabledFor": [{ "type": "always" }]
        }, {
          "name": "JunkFlag",
          "enabledFor": ["not-an-object"]
        }]
      )

      features = nil
      expect { features = marshaller.unmarshall(json) }.not_to raise_error

      expect(features.size).to be 2
      expect(features.find { |f| f.name == 'GoodFlag' }.enabled?).to be true

      junk = features.find { |f| f.name == 'JunkFlag' }
      expect(junk.un_evaluable?).to be true
      expect(junk.enabled?).to be false
    end

    it 'should fail a flag closed on a condition with a missing or non-string type, not raise' do
      json = %(
        [{ "name": "Good", "enabledFor": [{ "type": "always" }] },
         { "name": "NonStringType", "enabledFor": [{ "type": 5 }] },
         { "name": "MissingType", "enabledFor": [{ "parameter": "account_id" }] }]
      )

      features = nil
      expect { features = marshaller.unmarshall(json) }.not_to raise_error

      expect(features.size).to be 3
      expect(features.find { |f| f.name == 'Good' }.enabled?).to be true
      expect(features.find { |f| f.name == 'NonStringType' }.enabled?).to be false
      expect(features.find { |f| f.name == 'MissingType' }.enabled?).to be false
    end

    it 'should skip non-object top-level entries without dropping the healthy flags' do
      json = %(
        [{ "name": "Good", "enabledFor": [{ "type": "always" }] }, null, 5, "junk"]
      )

      features = nil
      expect { features = marshaller.unmarshall(json) }.not_to raise_error

      expect(features.map(&:name)).to eq ['Good']
      expect(features.first.enabled?).to be true
    end

    it 'should fail a flag closed when a condition list is present but not an array' do
      json = %(
        [{ "name": "Good", "enabledFor": [{ "type": "always" }] },
         { "name": "BadEnabledList", "enabledFor": { "type": "always" } },
         { "name": "BadDisabledList", "disabledFor": "nope" }]
      )

      features = nil
      expect { features = marshaller.unmarshall(json) }.not_to raise_error

      expect(features.find { |f| f.name == 'Good' }.enabled?).to be true
      expect(features.find { |f| f.name == 'BadEnabledList' }.enabled?).to be false
      expect(features.find { |f| f.name == 'BadDisabledList' }.enabled?).to be false
    end

    it 'should fail a flag closed when a condition constructor raises a non-ArgumentError' do
      # array bounds hit [2] < [1] -> NoMethodError inside Range#initialize
      json = %([{ "name": "BadRange", "enabledFor": [{ "type": "range", "min": [1], "max": [2] }] }])

      features = nil
      expect { features = marshaller.unmarshall(json) }.not_to raise_error
      expect(features.first.un_evaluable?).to be true
      expect(features.first.enabled?).to be false
    end

    it 'should fail a nameless flag closed instead of raising at eval' do
      # No name means a nil salt is injected into the percentage condition, which would
      # raise at eval; it must fail closed like any other unparseable flag.
      json = %([{ "enabledFor": [{ "type": "percentage", "parameter": "accountId", "percentage": 100 }] }])

      features = marshaller.unmarshall(json)

      expect(features.size).to be 1
      expect(features.first.un_evaluable?).to be true
      expect { features.first.enabled?(account_id: 'acct-1') }.not_to raise_error
      expect(features.first.enabled?(account_id: 'acct-1')).to be false
    end

    it 'should inject flag_name for a percentage condition in disabledFor' do
      json = %([{ "name": "DisabledPct", "disabledFor": [{ "type": "percentage", "parameter": "accountId", "percentage": 100 }] }])

      features = marshaller.unmarshall(json)
      condition = features[0].disabled_for[0]

      expect(condition).to be_a EightBall::Conditions::Percentage
      expect(condition.flag_name).to eq 'DisabledPct'
      # Must evaluate without raising: the salt is injected through the marshaller path.
      expect(features[0].enabled?(account_id: 'acct-1')).to be false
    end
  end
end
