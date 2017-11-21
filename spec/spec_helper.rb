$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'runscope_ci'
require 'factory_bot'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
  end
end
