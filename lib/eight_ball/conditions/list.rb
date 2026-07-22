# frozen_string_literal: true

module EightBall::Conditions
  # The List Condition describes a list of acceptable values.
  # These can be strings, integers, etc.
  class List < Base
    attr_reader :values, :coerce

    # Creates a new instance of a List Condition.
    #
    # @param [Hash] options
    #
    # @option options [Array<String>, String] :values
    #   The list of acceptable values
    # @option options [String] :parameter
    #   The name of the parameter this Condition was created for (eg. "account_id").
    #   This value is only used by calling classes as a way to know what to pass
    #   into {satisfied?}.
    # @option options [Boolean] :coerce
    #   When true, compare values and the tested input as strings so that, eg.,
    #   an integer list matches a string caller. Defaults to exact-type matching.
    def initialize(options = {})
      options ||= {}

      @values = Array(options[:values])
      @coerce = options[:coerce] || nil
      self.parameter = options[:parameter]
    end

    # @example
    #   condition = new EightBall::Conditions::List.new [1, 'a']
    #   condition.satisfied? 1 => true
    #   condition.satisfied? 2 => false
    #   condition.satisfied? 'a' => true
    def satisfied?(value)
      return values.map(&:to_s).include?(value.to_s) if @coerce

      values.include? value
    end

    def wire_fields
      %i[values parameter coerce]
    end

    protected

    def state
      super + [@values.sort, @coerce]
    end
  end
end
