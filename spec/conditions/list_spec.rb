# frozen_string_literal: true

RSpec.describe EightBall::Conditions::List do
  describe 'initialize' do
    it 'should ensure values is an array' do
      expect(EightBall::Conditions::List.new(values: 1).values).to eq [1]
      expect(EightBall::Conditions::List.new(values: nil).values).to eq []
      expect(EightBall::Conditions::List.new(nil).values).to eq []
      expect(EightBall::Conditions::List.new.values).to eq []
      expect(EightBall::Conditions::List.new(values: 'a').values).to eq ['a']
      expect(EightBall::Conditions::List.new(values: []).values).to eq []
    end

    it 'should set parameter' do
      expect(EightBall::Conditions::List.new(parameter: 'a').parameter).to eq 'a'
    end
  end

  describe 'satifisfied?' do
    it 'should return true if value accepted' do
      list1 = EightBall::Conditions::List.new values: [1, 2, 3]
      expect(list1.satisfied?(1)).to eq true

      list2 = EightBall::Conditions::List.new values: %w[John Jim]
      expect(list2.satisfied?('John')).to eq true
    end

    it 'should return false if value not accepted' do
      list1 = EightBall::Conditions::List.new values: [1, 2, 3]
      expect(list1.satisfied?(4)).to eq false

      list2 = EightBall::Conditions::List.new values: %w[John Jim]
      expect(list2.satisfied?('Jeremy')).to eq false
    end

    it 'should not coerce types by default' do
      # The exact-type match still succeeds, so a regression in the non-coerce path is caught.
      expect(EightBall::Conditions::List.new(values: [1]).satisfied?(1)).to eq true
      expect(EightBall::Conditions::List.new(values: [1]).satisfied?('1')).to eq false
      expect(EightBall::Conditions::List.new(values: ['1']).satisfied?(1)).to eq false
    end

    context 'when coerce is enabled' do
      it 'should match across types by comparing both sides as strings' do
        expect(EightBall::Conditions::List.new(values: [1], coerce: true).satisfied?('1')).to eq true
        expect(EightBall::Conditions::List.new(values: ['1'], coerce: true).satisfied?(1)).to eq true
      end

      it 'should still return false for a non-member' do
        expect(EightBall::Conditions::List.new(values: [1, 2], coerce: true).satisfied?('3')).to eq false
      end

      it 'compares by exact string form: 1.0 does not match 1, and nil/empty share a form' do
        expect(EightBall::Conditions::List.new(values: [1], coerce: true).satisfied?(1.0)).to eq false
        expect(EightBall::Conditions::List.new(values: [1], coerce: true).satisfied?(nil)).to eq false
        expect(EightBall::Conditions::List.new(values: [nil], coerce: true).satisfied?('')).to eq true
      end

      it 'should normalize a truthy value to a canonical boolean' do
        expect(EightBall::Conditions::List.new(values: [1], coerce: 1).coerce).to be true
        expect(EightBall::Conditions::List.new(values: [1], coerce: false).coerce).to be_nil
      end

      it 'should compare mixed-type coerced Lists without raising' do
        c1 = EightBall::Conditions::List.new(parameter: 'id', values: [1, '2'], coerce: true)
        c2 = EightBall::Conditions::List.new(parameter: 'id', values: ['2', 1], coerce: true)
        expect(c1 == c2).to be true
      end
    end
  end

  describe '==' do
    it 'should return true for identical Lists' do
      c1 = EightBall::Conditions::List.new parameter: 'id', values: [1, 2, 3]
      c2 = EightBall::Conditions::List.new parameter: 'id', values: [1, 2, 3]

      expect(c1 == c2).to be true
    end

    it 'should return true for Lists that have the same values in different order' do
      c1 = EightBall::Conditions::List.new parameter: 'id', values: [1, 2, 3]
      c2 = EightBall::Conditions::List.new parameter: 'id', values: [3, 2, 1]

      expect(c1 == c2).to be true
    end

    it 'should return false for Lists with different values' do
      c1 = EightBall::Conditions::List.new parameter: 'id', values: [1, 2, 3]
      c2 = EightBall::Conditions::Base.new parameter: 'id', values: [4, 5, 6]

      expect(c1 == c2).to be false
    end

    it 'should return false for Lists with different paramter names' do
      c1 = EightBall::Conditions::List.new parameter: 'id', values: [1, 2, 3]
      c2 = EightBall::Conditions::Base.new parameter: 'id2', values: [1, 2, 3]

      expect(c1 == c2).to be false
    end

    it 'should return false for Lists that differ only in coerce' do
      c1 = EightBall::Conditions::List.new parameter: 'id', values: [1, 2, 3]
      c2 = EightBall::Conditions::List.new parameter: 'id', values: [1, 2, 3], coerce: true

      expect(c1 == c2).to be false
    end
  end
end
