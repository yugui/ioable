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

def binary(str)
  str.force_encoding(Encoding::ASCII_8BIT)
end

def utf8(str)
  str.force_encoding(Encoding::UTF_8)
end

