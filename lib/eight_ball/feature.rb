# frozen_string_literal: true

module EightBall
  # A Feature is an element of your application that can be enabled or disabled
  # based on various {EightBall::Conditions}.
  class Feature
    attr_reader :name, :enabled_for, :disabled_for, :metadata

    # Creates a new instance of an Interval RefreshPolicy.
    #
    # @param name [String] The name of the Feature.
    # @param enabled_for [Array<EightBall::Conditions>, EightBall::Conditions]
    #   The Condition(s) that need to be satisfied for the Feature to be enabled.
    # @param disabled_for [Array<EightBall::Conditions>, EightBall::Conditions]
    #   The Condition(s) that need to be satisfied for the Feature to be disabled.
    # @param metadata [Hash, nil] Optional eval-agnostic metadata
    #   (e.g. { "type" => ..., "owner" => ..., "expires_at" => ... }).
    #
    # @example A Feature which is always enabled
    #   feature = EightBall::Feature.new 'feature1', EightBall::Conditions::Always
    def initialize(name, enabled_for = [], disabled_for = [], metadata: nil)
      @name = name
      @enabled_for = Array enabled_for
      @disabled_for = Array disabled_for
      @metadata = metadata
    end

    # "EightBall, is this Feature enabled?"
    #
    # @param parameters [Hash] The parameters the {EightBall::Conditions}
    #   of this Feature are concerned with.
    #
    # @return [true] if no {EightBall::Conditions} are set on the Feature.
    #   This is equivalent to the {EightBall::Conditions::Always Always} condition.
    # @return [true] if ANY of the {enabled_for} {EightBall::Conditions} are satisfied
    #   and NONE of the {disabled_for} {EightBall::Conditions} are satisfied.
    # @return [false ] if ANY of the {disabled_for} {EightBall::Conditions} are satisfied
    #
    # @raise [ArgumentError] if no value is provided for a parameter required
    #   by one of the Feature's {EightBall::Conditions}
    #
    # @example The Feature's {EightBall::Conditions} do not require any parameters
    #   feature.enabled?
    #
    # @example The Feature's {EightBall::Conditions} require an account ID
    #   feature.enabled? account_id: 123
    def enabled?(parameters = {})
      return true if @enabled_for.empty? && @disabled_for.empty?
      return true if @enabled_for.empty? && !any_satisfied?(@disabled_for, parameters)

      any_satisfied?(@enabled_for, parameters) && !any_satisfied?(@disabled_for, parameters)
    end

    def ==(other)
      name == other.name &&
        enabled_for.size == other.enabled_for.size &&
        enabled_for.all? { |condition| other.enabled_for.any? { |other_condition| condition == other_condition } } &&
        disabled_for.size == other.disabled_for.size &&
        disabled_for.all? { |condition| other.disabled_for.any? { |other_condition| condition == other_condition } }
    end
    alias eql? ==

    private

    def any_satisfied?(conditions, parameters)
      conditions.any? do |condition|
        return condition.satisfied? if condition.parameter.nil?

        value = parameters[condition.parameter.to_sym]
        raise ArgumentError, "Missing parameter #{condition.parameter}" if value.nil?

        condition.satisfied? value
      end
    end
  end
end
