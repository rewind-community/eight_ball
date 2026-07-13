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
  end
end
