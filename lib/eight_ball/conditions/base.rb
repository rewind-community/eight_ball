# frozen_string_literal: true

module EightBall::Conditions
  class Base
    attr_reader :parameter

    def initialize(_options = [])
      @parameter = nil
    end

    def satisfied?
      raise 'You can never satisfy the Base condition'
    end

    def ==(other)
      other.class == self.class && other.state == state
    end
    alias eql? ==

    def hash
      state.hash
    end

    # The wire-format hash for this condition. Subclasses declare their fields via
    # {wire_fields}; the type is the lower-cased class name, which must match a
    # {EightBall::Conditions.by_name} key so the condition round-trips.
    def to_wire
      wire = { type: self.class.name.split('::').last.downcase }
      wire_fields.each do |field|
        value = public_send(field)
        wire[field.to_s] = value unless value.nil?
      end
      wire
    end

    # The attributes this condition serializes, in output order (default: none).
    def wire_fields
      []
    end

    protected

    def state
      [@parameter]
    end

    def parameter=(parameter)
      return if parameter.nil?

      @parameter = parameter.gsub(/(.)([A-Z])/, '\1_\2').downcase
    end
  end
end
