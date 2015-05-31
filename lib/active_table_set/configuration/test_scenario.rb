module ActiveTableSet
  module Configuration
    class TestScenario < DatabaseConnection
      value_attr :scenario_name, required: true
    end
  end
end
