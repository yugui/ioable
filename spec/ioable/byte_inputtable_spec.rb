#-*- encoding: US-ASCII -*-

require File.expand_path("../../spec_helper", __FILE__)
require File.expand_path("../shared/byte_wide_input_spec.rb", __FILE__)
require File.expand_path("../shared/empty_input_impl_spec.rb", __FILE__)
require 'ioable/byte_inputtable'

describe IOable::ByteInputtable do
  before do
    @io = Object.new
    @io.extend(IOable::ByteInputtable)
  end

  it_should_behave_like 'empty input impl'
  it_should_behave_like 'byte-wide input'
end
