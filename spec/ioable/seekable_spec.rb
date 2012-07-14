#-*- encoding: US-ASCII -*-

require File.expand_path("../../spec_helper", __FILE__)
require 'ioable/byte_inputtable'

describe IOable::Seekable do
  before do
    @io = Object.new
    @io.extend(IOable::Seekable)
  end

  describe '#pos' do
    before do
      stub(@io).seek(is_a(Integer), anything)
    end
    it "should return 0 at first" do
      @io.pos.should == 0
    end

    it "should return the given value on set" do
      (@io.pos = 10).should == 10
    end

    it "should remember the given value" do
      @io.pos = 10
      @io.pos.should == 10
    end

    it "should call #seek on called" do
      mock(@io).seek(10, IO::SEEK_SET)

      @io.pos = 10
    end
  end

  describe '#rewind' do
    before do
      stub(@io).seek(is_a(Integer), anything)
    end
    it "should change #pos to zero" do
      @io.pos = 10
      @io.rewind
      @io.pos.should == 0
    end
    it "should call seek on called" do
      mock(@io).seek(0, IO::SEEK_SET)

      @io.rewind
    end
  end
end

