require File.expand_path("../../spec_helper", __FILE__)
require 'ioable/byte_inputtable'

describe IOable::NonSeekable do
  before do
    @io = Object.new
    @io.extend(IOable::NonSeekable)
  end

  describe '#pos' do
    it "should return 0 at first" do
      @io.pos.should == 0
    end

    it "should raise an error on set" do
      lambda { @io.pos = 10 }.should raise_error(Errno::ESPIPE)
    end
  end

  describe '#rewind' do
    it "should raise an error on called" do
      lambda { @io.rewind }.should raise_error(Errno::ESPIPE)
    end
  end
end

