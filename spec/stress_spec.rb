# frozen_string_literal: true

require 'json'

# Stress / integration suite. Drives the full unmarshall -> evaluate -> marshall cycle
# against realistic feature-flag blobs, large blobs, adversarial input, fuzzed garbage,
# and edge values. Evaluation parameters cover the common subject attributes a caller
# gates on (account_id, region_name, user_id, platform, plan). All randomness is
# seeded so runs are reproducible.
RSpec.describe 'eight_ball stress and integration' do
  subject(:marshaller) { EightBall::Marshallers::Json.new }

  after { EightBall.provider = nil }

  # A full evaluation bag (every param a consumer passes), indexed for reproducibility.
  def bag(index)
    {
      account_id: "acct-#{index}",
      region_name: "region-#{index}",
      user_id: "user-#{index}",
      platform: %w[web ios android api partner][index % 5],
      plan: %w[free pro enterprise][index % 3]
    }
  end

  describe 'realistic production-shaped blob' do
    let(:blob) do
      JSON.generate(
        [
          { name: 'AlwaysOn', enabledFor: [{ type: 'always' }] },
          { name: 'AlwaysOff', enabledFor: [{ type: 'never' }] },
          { name: 'RegionAllowlist', enabledFor: [{ type: 'list', parameter: 'regionName', values: %w[region-1 region-3 region-7] }] },
          { name: 'AccountAllowlist', enabledFor: [{ type: 'list', parameter: 'accountId', values: %w[acct-2 acct-4] }] },
          { name: 'EnterprisePlanGate', enabledFor: [{ type: 'list', parameter: 'plan', values: %w[enterprise] }] },
          { name: 'PlatformGate', enabledFor: [{ type: 'list', parameter: 'platform', values: %w[web] }] },
          { name: 'AccountRange', enabledFor: [{ type: 'range', parameter: 'accountId', min: 'acct-0', max: 'acct-3' }] },
          { name: 'RolloutExperiment', enabledFor: [{ type: 'percentage', parameter: 'regionName', percentage: 25 }],
            metadata: { type: 'experiment', owner: 'growth', expiresAt: '2026-12-31' } },
          { name: 'GatedWithOverride', enabledFor: [{ type: 'list', parameter: 'accountId', values: %w[acct-1] }],
            disabledFor: [{ type: 'list', parameter: 'plan', values: %w[free] }] }
        ]
      )
    end

    it 'evaluates every flag for a range of subjects without raising' do
      features = marshaller.unmarshall(blob)
      EightBall.provider = EightBall::Providers::Static.new(features)

      (0..60).each do |i|
        features.map(&:name).each do |name|
          expect([true, false]).to include(EightBall.enabled?(name, bag(i)))
        end
      end
    end

    it 'produces the expected verdicts for known subjects' do
      EightBall.provider = EightBall::Providers::Static.new(marshaller.unmarshall(blob))

      expect(EightBall.enabled?('AlwaysOn', bag(0))).to be true
      expect(EightBall.enabled?('AlwaysOff', bag(0))).to be false
      expect(EightBall.enabled?('RegionAllowlist', region_name: 'region-3')).to be true
      expect(EightBall.enabled?('RegionAllowlist', region_name: 'region-999')).to be false
      expect(EightBall.enabled?('EnterprisePlanGate', plan: 'enterprise')).to be true
      expect(EightBall.enabled?('EnterprisePlanGate', plan: 'free')).to be false
      expect(EightBall.enabled?('PlatformGate', platform: 'web')).to be true
      expect(EightBall.enabled?('PlatformGate', platform: 'api')).to be false
      expect(EightBall.enabled?('AccountRange', account_id: 'acct-1')).to be true
      expect(EightBall.enabled?('AccountRange', account_id: 'acct-8')).to be false
      # disabled_for overrides enabled_for
      expect(EightBall.enabled?('GatedWithOverride', account_id: 'acct-1', plan: 'pro')).to be true
      expect(EightBall.enabled?('GatedWithOverride', account_id: 'acct-1', plan: 'free')).to be false
      # unknown flag defaults OFF (enabled?) / ON (disabled?)
      expect(EightBall.enabled?('DoesNotExist', bag(0))).to be false
      expect(EightBall.disabled?('DoesNotExist', bag(0))).to be true
    end

    it 'round-trips the blob without changing any verdict' do
      once = marshaller.unmarshall(blob)
      twice = marshaller.unmarshall(marshaller.marshall(once))

      verdicts = lambda do |features|
        EightBall.provider = EightBall::Providers::Static.new(features)
        features.map { |f| [f.name, EightBall.enabled?(f.name, bag(3))] }
      end

      expect(verdicts.call(twice)).to eq verdicts.call(once)
    end

    it 'preserves metadata (symbol-keyed) and camelCases it on the wire' do
      feature = marshaller.unmarshall(blob).find { |f| f.name == 'RolloutExperiment' }
      expect(feature.metadata).to eq(type: 'experiment', owner: 'growth', expires_at: '2026-12-31')
      expect(marshaller.marshall([feature])).to include('"expiresAt":"2026-12-31"')
    end
  end

  describe 'scale' do
    def large_blob(count)
      flags = (0...count).map do |i|
        condition =
          case i % 5
          when 0 then { type: 'always' }
          when 1 then { type: 'list', parameter: 'account_id', values: ["acct-#{i}", "acct-#{i + 1}"] }
          when 2 then { type: 'range', parameter: 'account_id', min: 'acct-0', max: "acct-#{i}" }
          when 3 then { type: 'percentage', parameter: 'region_name', percentage: i % 101 }
          else { type: 'never' }
          end
        { name: "Flag#{i}", enabledFor: [condition] }
      end
      JSON.generate(flags)
    end

    it 'unmarshalls and evaluates a large mixed blob without error' do
      features = marshaller.unmarshall(large_blob(300))
      expect(features.size).to be 300
      EightBall.provider = EightBall::Providers::Static.new(features)

      (0..40).each do |i|
        features.each { |f| expect([true, false]).to include(f.enabled?(bag(i))) }
      end
    end

    it 'round-trips a large mixed blob to a stable serialization' do
      features = marshaller.unmarshall(large_blob(300))
      first = marshaller.marshall(features)
      second = marshaller.marshall(marshaller.unmarshall(first))
      expect(second).to eq first
    end

    it 'keeps percentage distribution within tolerance and sticky at scale' do
      ids = (0...10_000).map { |i| "acct-#{i}" }

      [10, 33, 80].each do |pct|
        features = marshaller.unmarshall(
          JSON.generate([{ name: "Exp#{pct}", enabledFor: [{ type: 'percentage', parameter: 'account_id', percentage: pct }] }])
        )
        EightBall.provider = EightBall::Providers::Static.new(features)

        first_pass = ids.map { |id| EightBall.enabled?("Exp#{pct}", account_id: id) }
        observed = first_pass.count(true) * 100.0 / ids.size
        expect(observed).to be_within(3).of(pct)

        second_pass = ids.map { |id| EightBall.enabled?("Exp#{pct}", account_id: id) }
        expect(second_pass).to eq first_pass
      end
    end
  end

  describe 'adversarial blob (hardening at scale)' do
    let(:blob) do
      JSON.generate(
        [
          { name: 'GoodAlways', enabledFor: [{ type: 'always' }] },
          { name: 'GoodList', enabledFor: [{ type: 'list', parameter: 'account_id', values: %w[acct-1] }] },
          { name: 'GoodPercentage', enabledFor: [{ type: 'percentage', parameter: 'region_name', percentage: 100 }] },
          { name: 'UnknownType', enabledFor: [{ type: 'made_up' }] },
          { name: 'NonStringType', enabledFor: [{ type: 5 }] },
          { name: 'MissingType', enabledFor: [{ parameter: 'account_id' }] },
          { name: 'MalformedRange', enabledFor: [{ type: 'range', parameter: 'account_id' }] },
          { name: 'RangeArrayBounds', enabledFor: [{ type: 'range', min: [1], max: [2] }] },
          { name: 'NonObjectCondition', enabledFor: ['oops'] },
          { name: 'NonArrayEnabled', enabledFor: 'not-a-list' },
          { name: 'NonArrayDisabled', disabledFor: 42 },
          { name: 'FloatPercentage', enabledFor: [{ type: 'percentage', parameter: 'region_name', percentage: 50.5 }] },
          { name: 'OutOfRangePercentage', enabledFor: [{ type: 'percentage', parameter: 'region_name', percentage: 150 }] },
          'not-even-a-feature',
          nil,
          { name: 'GoodNever', enabledFor: [{ type: 'never' }] }
        ]
      )
    end

    let(:good) { %w[GoodAlways GoodList GoodPercentage] }
    let(:bad) do
      %w[UnknownType NonStringType MissingType MalformedRange RangeArrayBounds
         NonObjectCondition NonArrayEnabled NonArrayDisabled FloatPercentage OutOfRangePercentage]
    end

    it 'never raises and fails only the bad flags closed' do
      features = nil
      expect { features = marshaller.unmarshall(blob) }.not_to raise_error

      # the two junk top-level entries are skipped; everything else becomes a feature
      expect(features.size).to be 14
      EightBall.provider = EightBall::Providers::Static.new(features)

      expect(EightBall.enabled?('GoodAlways', bag(0))).to be true
      expect(EightBall.enabled?('GoodList', account_id: 'acct-1')).to be true
      expect(EightBall.enabled?('GoodPercentage', region_name: 'region-42')).to be true
      expect(EightBall.enabled?('GoodNever', bag(0))).to be false

      bad.each do |name|
        expect(EightBall.enabled?(name, bag(0))).to be(false), "#{name} should be OFF"
      end
    end

    it 'round-trips the adversarial blob, keeping bad flags closed and healthy flags intact' do
      once = marshaller.unmarshall(blob)
      twice = marshaller.unmarshall(marshaller.marshall(once))

      expect(twice.size).to eq once.size
      EightBall.provider = EightBall::Providers::Static.new(twice)

      expect(EightBall.enabled?('GoodAlways', bag(0))).to be true
      bad.each { |name| expect(EightBall.enabled?(name, bag(0))).to be false }
    end
  end

  describe 'fuzzing' do
    def random_json_value(rng, depth = 0)
      choices = %i[nil int float string array]
      choices += %i[hash condition feature] if depth < 2
      case choices[rng.rand(choices.size)]
      when :nil then nil
      when :int then rng.rand(-1000..1000)
      when :float then rng.rand * 200
      when :string then "s#{rng.rand(10_000)}"
      when :array then Array.new(rng.rand(0..3)) { random_json_value(rng, depth + 1) }
      when :hash then { "k#{rng.rand(5)}" => random_json_value(rng, depth + 1) }
      when :condition
        { type: %w[always list range percentage made_up][rng.rand(5)],
          parameter: %w[account_id region_name weird][rng.rand(3)],
          values: [rng.rand(10)], min: rng.rand(5), max: rng.rand(5),
          percentage: rng.rand(-10..120) }
      when :feature
        { name: "F#{rng.rand(1000)}", enabledFor: Array.new(rng.rand(0..2)) { random_json_value(rng, depth + 1) } }
      end
    end

    it 'never raises unmarshalling random garbage, always returns an array' do
      rng = Random.new(2024)
      250.times do
        entries = Array.new(rng.rand(0..6)) { random_json_value(rng) }
        result = nil
        expect { result = marshaller.unmarshall(JSON.generate(entries)) }.not_to raise_error
        expect(result).to be_an(Array)
        # nothing that parsed should throw when re-marshalled
        expect { marshaller.marshall(result) }.not_to raise_error
      end
    end

    it 'marshalling round-trips valid generated features idempotently' do
      rng = Random.new(99)
      params = %w[account_id region_name user_id platform plan]
      60.times do
        features = Array.new(rng.rand(1..4)) do
          conditions = Array.new(rng.rand(0..3)) do
            case rng.rand(5)
            when 0 then EightBall::Conditions::Always.new
            when 1 then EightBall::Conditions::Never.new
            when 2 then EightBall::Conditions::List.new(values: [rng.rand(100), "v#{rng.rand(100)}"], parameter: params.sample(random: rng))
            when 3 then EightBall::Conditions::Range.new(min: rng.rand(50), max: rng.rand(50..100), parameter: params.sample(random: rng))
            else EightBall::Conditions::Percentage.new(percentage: rng.rand(0..100), parameter: params.sample(random: rng))
            end
          end
          EightBall::Feature.new("F#{rng.rand(10_000)}", conditions, [], metadata: (rng.rand < 0.3 ? { type: 'experiment' } : nil))
        end

        once = marshaller.marshall(features)
        twice = marshaller.marshall(marshaller.unmarshall(once))
        expect(twice).to eq once
      end
    end
  end

  describe 'edge values' do
    it 'handles unicode and control chars in names and values without crashing' do
      weird = "flag\n\e[31m☃-#{'x' * 40}"
      json = JSON.generate(
        [
          { name: weird, enabledFor: [{ type: 'list', parameter: 'account_id', values: [weird] }] },
          { name: 'BadWeird', enabledFor: [{ type: weird }] }
        ]
      )

      features = nil
      expect { features = marshaller.unmarshall(json) }.not_to raise_error
      expect { marshaller.marshall(features) }.not_to raise_error

      good = features.find { |f| f.name == weird }
      expect(good.enabled?(account_id: weird)).to be true
      expect(features.find { |f| f.name == 'BadWeird' }.enabled?(bag(0))).to be false
    end

    it 'treats an empty array and empty-condition features sensibly' do
      expect(marshaller.unmarshall('[]')).to eq []
      features = marshaller.unmarshall(JSON.generate([{ name: 'NoConditions' }]))
      expect(features.first.enabled?).to be true # no conditions => always on
    end

    it 'defaults to [] on invalid JSON, and raises consistently on any non-array top level' do
      expect(marshaller.unmarshall('{ not json')).to eq [] # JSON::ParserError -> []
      expect { marshaller.unmarshall('null') }.to raise_error(ArgumentError, /not an array/)
      expect { marshaller.unmarshall('5') }.to raise_error(ArgumentError, /not an array/)
      expect { marshaller.unmarshall('{"a":1}') }.to raise_error(ArgumentError, /not an array/)
    end

    it 'raises a clear error when a required parameter is absent (documented contract)' do
      features = marshaller.unmarshall(
        JSON.generate([{ name: 'NeedsAccount', enabledFor: [{ type: 'list', parameter: 'account_id', values: %w[acct-1] }] }])
      )
      expect { features.first.enabled?(region_name: 'region-1') }
        .to raise_error(ArgumentError, /Missing parameter account_id/)
    end
  end
end
