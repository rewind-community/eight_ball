# frozen_string_literal: true

module EightBall::Conditions
  # Wraps a condition entry that could not be built (unknown type, invalid params,
  # or a non-object entry). It is never satisfiable and re-serializes to its
  # original raw input, so a Feature holding one is failed closed yet round-trips
  # verbatim. Not registered in {by_name}; produced only as a parse fallback.
  class Opaque < Base
    attr_reader :raw

    def initialize(raw)
      @raw = raw
    end

    def satisfied?(*)
      false
    end

    # Re-emit the original entry unchanged.
    def to_wire
      @raw
    end

    protected

    def state
      [@raw]
    end
  end
end
