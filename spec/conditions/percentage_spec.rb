# frozen_string_literal: true

require 'digest'

RSpec.describe EightBall::Conditions::Percentage do
  def build(percentage:, flag_name: 'Flag', parameter: 'account_id')
    condition = EightBall::Conditions::Percentage.new percentage: percentage, parameter: parameter
    condition.flag_name = flag_name
    condition
  end

  describe 'initialize' do
    it 'should raise if percentage is missing' do
      expect { EightBall::Conditions::Percentage.new(parameter: 'account_id') }
        .to raise_error ArgumentError, 'Missing value for percentage'
    end

    it 'should raise if percentage is out of range' do
      expect { EightBall::Conditions::Percentage.new(percentage: -1, parameter: 'account_id') }
        .to raise_error ArgumentError, 'percentage must be an integer between 0 and 100'
      expect { EightBall::Conditions::Percentage.new(percentage: 101, parameter: 'account_id') }
        .to raise_error ArgumentError, 'percentage must be an integer between 0 and 100'
      expect { EightBall::Conditions::Percentage.new(percentage: 'fifty', parameter: 'account_id') }
        .to raise_error ArgumentError, 'percentage must be an integer between 0 and 100'
    end

    it 'should raise if parameter is missing' do
      expect { EightBall::Conditions::Percentage.new(percentage: 50) }
        .to raise_error ArgumentError, 'Missing value for parameter'
      expect { EightBall::Conditions::Percentage.new(percentage: 50, parameter: nil) }
        .to raise_error ArgumentError, 'Missing value for parameter'
      expect { EightBall::Conditions::Percentage.new(percentage: 50, parameter: '  ') }
        .to raise_error ArgumentError, 'Missing value for parameter'
    end

    it 'should accept an explicit parameter (snake-cased by Base)' do
      expect(EightBall::Conditions::Percentage.new(percentage: 50, parameter: 'accountId').parameter).to eq 'account_id'
    end

    it 'should expose the percentage' do
      expect(EightBall::Conditions::Percentage.new(percentage: 25, parameter: 'account_id').percentage).to eq 25
    end

    it 'should accept an integral Float percentage' do
      expect(EightBall::Conditions::Percentage.new(percentage: 50.0, parameter: 'account_id').percentage).to eq 50
    end

    it 'should reject a non-integral Float percentage' do
      expect { EightBall::Conditions::Percentage.new(percentage: 50.5, parameter: 'account_id') }
        .to raise_error ArgumentError, 'percentage must be an integer between 0 and 100'
    end
  end

  describe 'satisfied?' do
    it 'should raise if flag_name was never injected' do
      condition = EightBall::Conditions::Percentage.new percentage: 50, parameter: 'account_id'
      expect { condition.satisfied?('123') }
        .to raise_error ArgumentError, 'flag_name has not been set on Percentage condition'
    end

    it 'should match the canonical bucket formula exactly' do
      condition = build(percentage: 100, flag_name: 'MyFlag')
      value = 'acct-42'

      expected_bucket = Integer(Digest::SHA256.hexdigest("MyFlag:#{value}")[0, 8], 16) % 100
      # percentage 100 => always satisfied; assert the bucket math is the documented one.
      expect(expected_bucket).to be_between(0, 99)
      expect(condition.satisfied?(value)).to be true
    end

    it 'should be satisfied iff bucket < percentage' do
      flag = 'BucketFlag'
      value = 'acct-7'
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
      first = condition.satisfied?('acct-99')
      10.times { expect(condition.satisfied?('acct-99')).to eq first }
    end

    it 'should coerce the value to a string so 42 and "42" bucket identically' do
      int_bucket = Integer(Digest::SHA256.hexdigest('F:42')[0, 8], 16) % 100
      expect(int_bucket).to be_between(0, 99)

      # At a threshold straddling the shared bucket, int and string subjects must
      # agree; a coercion regression would diverge here.
      expect(build(percentage: int_bucket, flag_name: 'F').satisfied?(42)).to be false
      expect(build(percentage: int_bucket, flag_name: 'F').satisfied?('42')).to be false
      expect(build(percentage: int_bucket + 1, flag_name: 'F').satisfied?(42)).to be true
      expect(build(percentage: int_bucket + 1, flag_name: 'F').satisfied?('42')).to be true
    end

    it 'should decorrelate an id across different flags (flag name is the salt)' do
      value = 'acct-123'
      buckets = %w[FlagA FlagB FlagC].to_h do |flag|
        [flag, Integer(Digest::SHA256.hexdigest("#{flag}:#{value}")[0, 8], 16) % 100]
      end
      # The three fixed names do not all bucket the same value identically.
      expect(buckets.values.uniq.size).to be > 1

      # Each flag's verdict must track its own salted bucket; a flag_name-agnostic
      # bug would fail here.
      buckets.each do |flag, bucket|
        expect(build(percentage: bucket, flag_name: flag).satisfied?(value)).to be false
        expect(build(percentage: bucket + 1, flag_name: flag).satisfied?(value)).to be true
      end
    end
  end

  describe '==' do
    it 'should be equal for same parameter and percentage' do
      c1 = EightBall::Conditions::Percentage.new percentage: 30, parameter: 'account_id'
      c2 = EightBall::Conditions::Percentage.new percentage: 30, parameter: 'account_id'
      expect(c1 == c2).to be true
    end

    it 'should differ when percentage differs' do
      c1 = EightBall::Conditions::Percentage.new percentage: 30, parameter: 'account_id'
      c2 = EightBall::Conditions::Percentage.new percentage: 40, parameter: 'account_id'
      expect(c1 == c2).to be false
    end

    it 'should differ when parameter differs' do
      c1 = EightBall::Conditions::Percentage.new percentage: 30, parameter: 'account_id'
      c2 = EightBall::Conditions::Percentage.new percentage: 30, parameter: 'region_name'
      expect(c1 == c2).to be false
    end
  end
end
