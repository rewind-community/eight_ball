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
    # Raised internally by create_conditions_from_json when a Condition type is
    # not recognized. Caught per-feature by unmarshall so a single bad Feature
    # is failed closed (OFF) instead of taking down the whole feature set.
    UnknownConditionType = Class.new(StandardError)
    private_constant :UnknownConditionType

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
      parsed = JSON.parse(json, symbolize_names: true).to_snake_keys

      raise ArgumentError, 'JSON input was not an array' unless parsed.is_a? Array

      parsed.map do |feature|
        build_feature feature
      end
    rescue JSON::ParserError => e
      EightBall.logger.error { "Failed to parse JSON: #{e.message}" }
      []
    end

    private

    def build_feature(feature)
      enabled_for = create_conditions_from_json feature[:enabled_for]
      disabled_for = create_conditions_from_json feature[:disabled_for]

      EightBall::Feature.new feature[:name], enabled_for, disabled_for, metadata: feature[:metadata]
    rescue UnknownConditionType => e
      EightBall.logger.warn { "Feature '#{feature[:name]}' has unknown condition type '#{e.message}'; marking it un-evaluable (OFF)" }
      EightBall::Feature.new(feature[:name], [], [], metadata: feature[:metadata]).tap(&:un_evaluable!)
    end

    def feature_to_hash(feature)
      hash = {
        name: feature.name
      }

      hash[:enabled_for] = feature.enabled_for.map { |condition| condition_to_hash(condition) } unless feature.enabled_for.empty?
      hash[:disabled_for] = feature.disabled_for.map { |condition| condition_to_hash(condition) } unless feature.disabled_for.empty?
      hash[:metadata] = feature.metadata unless feature.metadata.nil?

      hash
    end

    def condition_to_hash(condition)
      hash = {
        type: condition.class.name.split('::').last.downcase
      }
      condition.instance_variables.each do |var|
        next unless condition.instance_variable_get(var)

        hash[var.to_s.delete('@')] = condition.instance_variable_get(var)
      end

      hash
    end

    def create_conditions_from_json(json_conditions)
      return [] unless json_conditions&.is_a?(Array)

      json_conditions.map do |condition|
        condition_class = EightBall::Conditions.by_name condition[:type]
        raise UnknownConditionType, condition[:type].to_s if condition_class.nil?

        condition_class.new condition
      end
    end
  end
end
