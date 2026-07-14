# frozen_string_literal: true

require 'digest'

module EightBall::Conditions
  # The Percentage Condition is satisfied for a deterministic, sticky subset of
  # values sized to +percentage+ percent. Bucketing is salted by the owning flag's
  # name (injected by {EightBall::Feature}), so a value buckets independently per
  # flag. See the README for the bucket algorithm.
  class Percentage < Base
    attr_reader :percentage, :flag_name

    # @param [Hash] options
    # @option options [Integer] :percentage Integer 0..100. 0 is never
    #   satisfied; 100 is always satisfied.
    # @option options [String] :parameter The name of the parameter this Condition
    #   was created for (eg. "account_id").
    def initialize(options = {})
      options ||= {}

      raise ArgumentError, 'Missing value for percentage' if options[:percentage].nil?

      percentage = options[:percentage]
      unless percentage.is_a?(Integer) && percentage >= 0 && percentage <= 100
        raise ArgumentError, 'percentage must be an integer between 0 and 100'
      end

      @percentage = percentage
      @flag_name = nil

      self.parameter = options[:parameter]
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

      bucket = Integer(Digest::SHA256.hexdigest("#{@flag_name}:#{value}")[0, 8], 16) % 100
      bucket < @percentage
    end

    protected

    # flag_name is a runtime injection, excluded from equality and the wire form.
    def state
      super + [@percentage]
    end
  end
end
