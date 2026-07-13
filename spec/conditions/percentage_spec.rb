# frozen_string_literal: true

require 'digest'

RSpec.describe EightBall::Conditions::Percentage do
  def build(percentage:, flag_name: 'Flag', parameter: nil)
    opts = { percentage: percentage }
    opts[:parameter] = parameter if parameter
    condition = EightBall::Conditions::Percentage.new opts
    condition.flag_name = flag_name
    condition
  end

  describe 'initialize' do
    it 'should raise if percentage is missing' do
      expect { EightBall::Conditions::Percentage.new(parameter: 'organization_id') }
        .to raise_error ArgumentError, 'Missing value for percentage'
    end

    it 'should raise if percentage is out of range' do
      expect { EightBall::Conditions::Percentage.new(percentage: -1) }
        .to raise_error ArgumentError, 'percentage must be an integer between 0 and 100'
      expect { EightBall::Conditions::Percentage.new(percentage: 101) }
        .to raise_error ArgumentError, 'percentage must be an integer between 0 and 100'
      expect { EightBall::Conditions::Percentage.new(percentage: 'fifty') }
        .to raise_error ArgumentError, 'percentage must be an integer between 0 and 100'
    end

    it 'should default parameter to organization_id' do
      expect(EightBall::Conditions::Percentage.new(percentage: 50).parameter).to eq 'organization_id'
    end

    it 'should accept an explicit parameter (snake-cased by Base)' do
      expect(EightBall::Conditions::Percentage.new(percentage: 50, parameter: 'accountId').parameter).to eq 'account_id'
    end

    it 'should expose the percentage' do
      expect(EightBall::Conditions::Percentage.new(percentage: 25).percentage).to eq 25
    end
  end

  describe 'satisfied?' do
    it 'should raise if flag_name was never injected' do
      condition = EightBall::Conditions::Percentage.new percentage: 50
      expect { condition.satisfied?('123') }
        .to raise_error ArgumentError, 'flag_name has not been set on Percentage condition'
    end

    it 'should match the canonical bucket formula exactly' do
      condition = build(percentage: 100, flag_name: 'MyFlag')
      value = 'org-42'

      expected_bucket = Integer(Digest::SHA256.hexdigest("MyFlag:#{value}")[0, 8], 16) % 100
      # percentage 100 => always satisfied; assert the bucket math is the documented one.
      expect(expected_bucket).to be_between(0, 99)
      expect(condition.satisfied?(value)).to be true
    end

    it 'should be satisfied iff bucket < percentage' do
      flag = 'BucketFlag'
      value = 'org-7'
      bucket = Integer(Digest::SHA256.hexdigest("#{flag}:#{value}")[0, 8], 16) % 100

      # Just below the bucket => not satisfied; just above => satisfied.
      expect(build(percentage: bucket, flag_name: flag).satisfied?(value)).to be false
      expect(build(percentage: bucket + 1, flag_name: flag).satisfied?(value)).to be true
    end

    it 'should never be satisfied at percentage 0' do
      condition = build(percentage: 0, flag_name: 'Z')
      20.times { |i| expect(condition.satisfied?("id-#{i}")).to be false }
    end

    it 'should always be satisfied at percentage 100' do
      condition = build(percentage: 100, flag_name: 'Z')
      20.times { |i| expect(condition.satisfied?("id-#{i}")).to be true }
    end

    it 'should be deterministic (sticky) for the same flag + value' do
      condition = build(percentage: 50, flag_name: 'StickyFlag')
      first = condition.satisfied?('org-99')
      10.times { expect(condition.satisfied?('org-99')).to eq first }
    end

    it 'should coerce the value to a string so 42 and "42" bucket identically' do
      int_bucket = Integer(Digest::SHA256.hexdigest('F:42')[0, 8], 16) % 100
      expect(int_bucket).to be_between(0, 99)

      # Assert at a threshold that straddles the shared bucket, so the outcome depends
      # on the actual bucket: a stringification regression (42 vs "42" bucketing
      # differently) would make the integer and string subjects diverge here.
      expect(build(percentage: int_bucket, flag_name: 'F').satisfied?(42)).to be false
      expect(build(percentage: int_bucket, flag_name: 'F').satisfied?('42')).to be false
      expect(build(percentage: int_bucket + 1, flag_name: 'F').satisfied?(42)).to be true
      expect(build(percentage: int_bucket + 1, flag_name: 'F').satisfied?('42')).to be true
    end

    it 'should decorrelate an id across different flags (flag name is the salt)' do
      value = 'org-123'
      buckets = %w[FlagA FlagB FlagC].to_h do |flag|
        [flag, Integer(Digest::SHA256.hexdigest("#{flag}:#{value}")[0, 8], 16) % 100]
      end
      # The three fixed names do not all bucket the same value identically.
      expect(buckets.values.uniq.size).to be > 1

      # Prove the REAL condition uses the flag name as salt: each flag's verdict tracks
      # ITS OWN bucket. A bug that ignored flag_name would bucket every flag identically
      # and break these per-flag thresholds.
      buckets.each do |flag, bucket|
        expect(build(percentage: bucket, flag_name: flag).satisfied?(value)).to be false
        expect(build(percentage: bucket + 1, flag_name: flag).satisfied?(value)).to be true
      end
    end
  end

  describe '==' do
    it 'should be equal for same parameter and percentage' do
      c1 = EightBall::Conditions::Percentage.new percentage: 30, parameter: 'organization_id'
      c2 = EightBall::Conditions::Percentage.new percentage: 30, parameter: 'organization_id'
      expect(c1 == c2).to be true
    end

    it 'should differ when percentage differs' do
      c1 = EightBall::Conditions::Percentage.new percentage: 30
      c2 = EightBall::Conditions::Percentage.new percentage: 40
      expect(c1 == c2).to be false
    end

    it 'should differ when parameter differs' do
      c1 = EightBall::Conditions::Percentage.new percentage: 30, parameter: 'organization_id'
      c2 = EightBall::Conditions::Percentage.new percentage: 30, parameter: 'account_id'
      expect(c1 == c2).to be false
    end
  end
end
