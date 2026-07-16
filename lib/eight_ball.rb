# frozen_string_literal: true

require 'eight_ball/version'
require 'eight_ball/feature'

require 'eight_ball/configuration_error'

require 'eight_ball/conditions/conditions'
require 'eight_ball/conditions/base'

require 'eight_ball/conditions/always'
require 'eight_ball/conditions/list'
require 'eight_ball/conditions/never'
require 'eight_ball/conditions/opaque'
require 'eight_ball/conditions/percentage'
require 'eight_ball/conditions/range'

require 'eight_ball/marshallers/json'

require 'eight_ball/providers/http'
require 'eight_ball/providers/static'

require 'eight_ball/providers/refresh_policies/interval'

require 'logger'

# For all your feature querying needs.
module EightBall
  # Sets the {EightBall::Providers Provider} instance EightBall
  # will use to obtain your list of {EightBall::Feature Features}.
  #
  # @return [nil]
  #
  # @example
  #   EightBall.provider = EightBall::Providers::Http.new 'http://www.rewind.io'
  def self.provider=(provider)
    @provider = provider
  end

  # Gets the {EightBall::Providers Provider} instance
  # EightBall is configured to use
  #
  # @return {EightBall::Providers Provider}
  def self.provider
    @provider
  end

  # Serves as a shortcut to access the {EightBall::Feature Features} available
  # on the configured {EightBall::Providers Provider}
  #
  # @return [Array<EightBall::Feature>]
  def self.features
    raise EightBall::ConfigurationError, 'No Provider has been configured; there can be no features. Please see "EightBall.provider="' unless provider

    provider.features
  end

  # "EightBall, is the feature named 'NewFeature' enabled?"
  #
  # @return whether or not the {EightBall::Feature} is enabled.
  # @return [false] if {EightBall::Feature} does not exist.
  #
  # @param name [String] The name of the {EightBall::Feature}.
  # @param parameters [Hash] The parameters the {EightBall::Conditions} of this
  #   {EightBall::Feature} are concerned with.
  #
  # @example
  #   EightBall.enabled? 'feature1', account_id: 1
  def self.enabled?(name, parameters = {})
    feature = provider.features.find { |f| f.name == name }
    return false unless feature

    feature.enabled? parameters
  end

  # "EightBall, is the feature named 'NewFeature' disabled?"
  #
  # @return whether or not the {EightBall::Feature} is disabled.
  # @return [true] if {EightBall::Feature} does not exist.
  #
  # @param name [String] The name of the {EightBall::Feature}.
  # @param parameters [Hash] The parameters the {EightBall::Conditions} of this
  #   {EightBall::Feature} are concerned with.
  #
  # @example
  #   EightBall.disabled? 'feature1', account_id: 1
  def self.disabled?(name, parameters = {})
    !enabled? name, parameters
  end

  # Yields to the given block of code if the {EightBall::Feature} is enabled.
  #
  # @return [nil] if block is yielded to
  # @return [false] if no block is given
  #
  # @param name [String] The name of the {EightBall::Feature}.
  # @param parameters [Hash] The parameters the {EightBall::Conditions} of this
  #   {EightBall::Feature} are concerned with.
  #
  # @example
  #   EightBall.with 'feature1', account_id: 1 do
  #     puts 'Feature is enabled!'
  #   end
  def self.with(name, parameters = {})
    return false unless block_given?

    yield if enabled? name, parameters
  end

  # Marshalls the {EightBall::Feature Features}. This can be useful for
  # converting the data to, e.g., a JSON file.
  #
  # If a {EightBall::Marshallers Marshaller} is provided, use it.
  #
  # If no {EightBall::Marshallers Marshaller} is provided, uses the same
  # Marshaller that the Provider is configured with.
  #
  # If the {EightBall::Providers Provider} does not expose a
  # {EightBall::Marshallers Marshaller}, this will default to the
  # {EightBall::Marshallers::Json JSON Marshaller}.
  def self.marshall(marshaller = nil, features = EightBall.features)
    marshaller ||=
      (provider.respond_to?(:marshaller) && provider.marshaller) ||
      EightBall::Marshallers::Json.new

    marshaller.marshall features
  end

  def self.logger
    @logger ||= Logger.new(STDOUT).tap do |log|
      log.progname = name
    end
  end

  def self.logger=(logger)
    @logger = logger
  end
end
