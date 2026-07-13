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
    rescue UnknownConditionType, ArgumentError => e
      # Fail ONLY this flag closed (OFF) for any unbuildable condition: an unknown
      # type OR a known type with invalid params (e.g. a range missing min). Both
      # would otherwise raise out of unmarshall and black out the whole blob.
      EightBall.logger.warn { "Feature '#{feature[:name]}' has an invalid condition (#{e.message}); marking it un-evaluable (OFF)" }
      # Retain the raw source so re-marshalling re-emits the unparseable flag verbatim
      # (keeps it fail-closed on the next read; never drops the definition).
      EightBall::Feature.new(feature[:name], [], [], metadata: feature[:metadata]).tap { |f| f.un_evaluable! feature }
    end

    def feature_to_hash(feature)
      # An un-evaluable feature re-emits its original raw source verbatim, so a
      # read -> marshall -> persist cycle neither drops the unparseable definition
      # nor flips the flag from fail-closed OFF to fail-open ON.
      return feature.source if feature.un_evaluable? && feature.source

      hash = {
        name: feature.name
      }

      hash[:enabled_for] = feature.enabled_for.map { |condition| condition_to_hash(condition) } unless feature.enabled_for.empty?
      hash[:disabled_for] = feature.disabled_for.map { |condition| condition_to_hash(condition) } unless feature.disabled_for.empty?
      hash[:metadata] = feature.metadata unless feature.metadata.nil?

      hash
    end

    # Fail-closed allowlist: the exact wire fields each condition type serializes,
    # in output order. Anything NOT listed here (e.g. the runtime-only @flag_name
    # salt on percentage) is never written to the persisted blob. A new condition
    # type, or a new wire field, must be added here deliberately; the default is to
    # serialize nothing but the type. This is the opposite of the prior approach,
    # which reflected over instance variables and wrote every truthy one with no
    # exclusion list, leaking any runtime ivar the moment it existed.
    CONDITION_WIRE_FIELDS = {
      'always' => [],
      'never' => [],
      'list' => %i[values parameter],
      'range' => %i[min max parameter],
      'percentage' => %i[percentage parameter]
    }.freeze
    private_constant :CONDITION_WIRE_FIELDS

    def condition_to_hash(condition)
      type = condition.class.name.split('::').last.downcase
      hash = { type: type }

      CONDITION_WIRE_FIELDS.fetch(type, []).each do |field|
        value = condition.public_send(field)
        next if value.nil?

        hash[field.to_s] = value
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
