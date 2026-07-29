# frozen_string_literal: true

require 'awrence'
require 'json'
require 'plissken'

# A JSON marshaller can convert back and forth between JSON and a list of {EightBall::Feature Features}
# The JSON produced will be pretty-printed, as it is assumed the output will be written to a file.
#
# When converting from JSON, the top-level JSON element must be an array and
# its keys must use camel-case; this will be converted to snake-case by EightBall
# in order to adhere to both JSON and Ruby standards.
#
# Below are some examples of valid JSON:
#
# @example A single {EightBall::Feature} is enabled for accounts 1-5 as well as region Europe
#   [{
#     "name": "Feature1",
#     "enabledFor": [{
#       "type": "range",
#       "parameter": "accountId",
#       "min": 1,
#       "max": 5
#     }, {
#       "type": "list",
#       "parameter": "regionName",
#       "values": ["Europe"]
#     }]
#   }]
#
# @example A single {EightBall::Feature} is disabled completely using the {EightBall::Conditions::Always Always} condition
#   [{
#     "name": "Feature1",
#     "disabledFor": [{
#       "type": "always"
#     }]
#   }]
module EightBall::Marshallers
  class Json
    # Convert the given {EightBall::Feature Features} into a JSON array.
    #
    # @param [Array<EightBall::Feature>] features The {EightBall::Feature Features} to convert.
    # @return [String] The resulting JSON string.
    #
    # @example
    #   json_string = <Read from somewhere>
    #
    #   marshaller = EightBall::Marshallers::Json.new
    #   marshaller.marshall [Array<EightBall::Feature>] => json
    def marshall(features)
      JSON.generate(features.map { |feature| feature_to_hash(feature).to_camelback_keys })
    end

    # Convert the given JSON into a list of {EightBall::Feature Features}.
    #
    # @param [String] json The JSON string to convert.
    # @return [Array<EightBall::Feature>] The parsed {EightBall::Feature Features}
    #
    # @example
    #   json_string = <Read from somewhere>
    #
    #   marshaller = EightBall::Marshallers::Json.new
    #   marshaller.unmarshall json_string => [Features]
    def unmarshall(json)
      parsed = JSON.parse(json, symbolize_names: true)

      raise ArgumentError, 'JSON input was not an array' unless parsed.is_a? Array

      parsed.to_snake_keys.filter_map do |feature|
        build_feature feature
      end
    rescue JSON::ParserError => e
      EightBall.logger.error { "Failed to parse JSON: #{e.message.inspect}" }
      []
    end

    private

    def build_feature(feature)
      unless feature.is_a?(Hash)
        EightBall.logger.warn { "Skipping non-object feature entry: #{feature.inspect}" }
        return nil
      end

      enabled_for = create_conditions_from_json feature[:enabled_for]
      disabled_for = create_conditions_from_json feature[:disabled_for]
      built = EightBall::Feature.new feature[:name], enabled_for, disabled_for, metadata: feature[:metadata]

      unparseable = (enabled_for + disabled_for).select { |condition| condition.is_a?(EightBall::Conditions::Opaque) }

      # A nameless flag can't be looked up, and its flag-name-salted conditions raise at eval; fail it closed.
      if feature[:name].nil?
        EightBall.logger.warn { 'Feature entry has no name; marking it un-evaluable (OFF)' }
        built.un_evaluable!
      elsif !unparseable.empty?
        EightBall.logger.warn { "Feature #{feature[:name].inspect} has unparseable condition(s) #{unparseable.map(&:raw).inspect}; marking it un-evaluable (OFF)" }
        built.un_evaluable!
      end

      built
    end

    def feature_to_hash(feature)
      hash = {
        name: feature.name
      }

      enabled_for = feature.enabled_for.compact
      hash[:enabled_for] = enabled_for.map(&:to_wire) unless enabled_for.empty?

      disabled_for = feature.disabled_for.compact
      hash[:disabled_for] = disabled_for.map(&:to_wire) unless disabled_for.empty?
      hash[:metadata] = feature.metadata unless feature.metadata.nil?

      hash
    end

    def create_conditions_from_json(json_conditions)
      return [] if json_conditions.nil?
      return [EightBall::Conditions::Opaque.new(json_conditions)] unless json_conditions.is_a?(Array)

      json_conditions.map { |condition| build_condition condition }
    end

    # Build one condition, or wrap anything unbuildable (non-object, unknown type,
    # invalid params) in an Opaque condition so a single bad entry fails only its
    # flag closed instead of aborting the whole parse.
    def build_condition(condition)
      return EightBall::Conditions::Opaque.new(condition) unless condition.is_a?(Hash)

      condition_class = EightBall::Conditions.by_name condition[:type]
      return EightBall::Conditions::Opaque.new(condition) if condition_class.nil?
      # Nothing to match against without a parameter, so fail the flag closed.
      return EightBall::Conditions::Opaque.new(condition) if requires_parameter?(condition_class) && condition[:parameter].to_s.strip.empty?

      condition_class.new condition
    rescue StandardError
      EightBall::Conditions::Opaque.new(condition)
    end

    # A condition that evaluates against a subject value is one that needs a parameter.
    def requires_parameter?(condition_class)
      condition_class.instance_method(:satisfied?).arity.positive?
    end
  end
end
