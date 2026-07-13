# frozen_string_literal: true

require 'digest'

module EightBall::Conditions
  # The Percentage Condition implements sticky percentage bucketing for
  # A/B experiments. It is satisfied for a deterministic subset of values
  # sized to +percentage+ percent.
  #
  # Canonical bucket algorithm (spec of record):
  #   bucket = Integer(Digest::SHA256.hexdigest("\#{flag_name}:\#{value}")[0, 8], 16) % 100
  #   satisfied iff bucket < percentage
  #
  # The salt is the owning flag's name, so a given value (e.g. an
  # organization_id) is decorrelated across different flags/experiments.
  # +flag_name+ is injected by {EightBall::Feature} at construction time
  # because Conditions do not otherwise know which Feature owns them.
  #
  # Limitation (by design): because the bucket salt is the flag name, an
  # experiment CANNOT be re-randomized on the same flag. The salt is stable for
  # the life of the name, which is what decorrelates an org across flags but also
  # fixes that org's bucket for that flag forever. To re-draw buckets (a fresh
  # randomization) you must rename the flag (a new name is a new salt). Changing
  # +percentage+ only moves the threshold; it does not reshuffle who is in which
  # bucket.
  class Percentage < Base
    attr_reader :percentage, :flag_name

    # @param [Hash] options
    # @option options [Integer] :percentage Integer 0..100. 0 is never
    #   satisfied; 100 is always satisfied.
    # @option options [String] :parameter The attribute to bucket on.
    #   Defaults to "organization_id"; use "account_id" for instance-scoped
    #   experiments.
    def initialize(options = {})
      options ||= {}

      raise ArgumentError, 'Missing value for percentage' if options[:percentage].nil?

      percentage = options[:percentage]
      unless percentage.is_a?(Integer) && percentage >= 0 && percentage <= 100
        raise ArgumentError, 'percentage must be an integer between 0 and 100'
      end

      @percentage = percentage
      @flag_name = nil

      self.parameter = options[:parameter] || 'organization_id'
    end

    # Injected by {EightBall::Feature} so the bucket can be salted by flag name.
    def flag_name=(name)
      @flag_name = name
    end

    # @param value The value of {parameter} for the subject being evaluated.
    # @return [Boolean] whether the subject falls within the bucket.
    # @raise [ArgumentError] if {flag_name} was never injected.
    def satisfied?(value)
      raise ArgumentError, 'flag_name has not been set on Percentage condition' if @flag_name.nil?

      # SHA256 here is a non-cryptographic hash chosen for uniform bucket distribution, not security.
      bucket = Integer(Digest::SHA256.hexdigest("#{@flag_name}:#{value}")[0, 8], 16) % 100
      bucket < @percentage
    end

    protected

    # NOTE: flag_name is deliberately excluded from state/equality and from the
    # wire format; it is a runtime injection, not part of the flag definition.
    def state
      super + [@percentage]
    end
  end
end
