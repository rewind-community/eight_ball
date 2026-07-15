# frozen_string_literal: true

module EightBall::Conditions
  # The Range Condition describes a range of acceptable values by specifying
  # a minimum and a maximum. These can be strings, integers, etc. but mixing
  # data types will probably give you unexpected results.
  class Range < Base
    attr_reader :min, :max

    # Creates a new instance of a Range Condition.
    #
    # @param [Hash] options
    #
    # @option options :min The minimum acceptable value (inclusive).
    # @option options :max The maximum acceptable value (inclusive).
    # @option options [String] :parameter
    #   The name of the parameter this Condition was created for (eg. "account_id").
    #   This value is only used by calling classes as a way to know what to pass
    #   into {satisfied?}.
    def initialize(options = {})
      options ||= {}

      raise ArgumentError, 'Missing value for min' if options[:min].nil?
      raise ArgumentError, 'Missing value for max' if options[:max].nil?

      @min = options[:min]

      raise ArgumentError, 'Max must be greater or equal to min' if options[:max] < min

      @max = options[:max]

      self.parameter = options[:parameter]
    end

    # @example Using integers
    #   condition = new EightBall::Conditions::List.new min: 1, max: 300
    #   condition.satisfied? 1 => true
    #   condition.satisfied? 301 => false
    #
    # @example Using strings
    #   condition = new EightBall::Conditions::List.new min: 'a', max: 'm'
    #   condition.satisfied? 'a' => true
    #   condition.satisfied? 'z' => false
    def satisfied?(value)
      value >= min && value <= max
    end

    def wire_fields
      %i[min max parameter]
    end

    protected

    def state
      super + [@min, @max]
    end
  end
end
