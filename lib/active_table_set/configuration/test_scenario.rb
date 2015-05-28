module ActiveTableSet
  module Configuration
    class TestScenario < DatabaseConfig
      value_attr :scenario_name, required: true
    end
  end
end
