begin
  require 'rspec'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rspec'
  require 'rspec'
end

gem 'rr'
RSpec.configure do |config|
  config.mock_with :rr
end

$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'ioable'
