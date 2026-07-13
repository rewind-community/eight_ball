# frozen_string_literal: true

module EightBall::Conditions
  # Finds the Condition class based on its name
  # @param [String] name The case insensitive name to find the Condition for
  # @return [EightBall::Conditions] the Condition class represented by the given name
  def self.by_name(name)
    mappings = {
      always: EightBall::Conditions::Always,
      list: EightBall::Conditions::List,
      never: EightBall::Conditions::Never,
      percentage: EightBall::Conditions::Percentage,
      range: EightBall::Conditions::Range
    }
    mappings[name.downcase.to_sym]
  end
end
