#-*- encoding: US-ASCII -*-

require File.expand_path("../../spec_helper", __FILE__)
require 'ioable/inputtable'

def binary(str)
  str.force_encoding(Encoding::ASCII_8BIT)
end

def utf8(str)
  str.force_encoding(Encoding::UTF_8)
end

describe IOable::Inputtable do
  before do
    @byte_input = Object.new
    @io = IOable::BufferredInput.new(@byte_input, Encoding::UTF_8)
  end

  describe '#getc' do
    it "should return a character for each call" do
      mock(@byte_input).sysread(is_a(Integer)){ binary("a") }
      mock(@byte_input).sysread(is_a(Integer)){ binary("b") }

      c = @io.getc
      c.should == utf8('a')
      c.encoding.should == Encoding::UTF_8
      c = @io.getc
      c.should == utf8('b')
      c.encoding.should == Encoding::UTF_8
    end

    it "should return nil if readpartial returns nil" do
      mock(@byte_input).sysread(is_a(Integer)){ binary("a") }
      mock(@byte_input).sysread(is_a(Integer)){ raise EOFError }

      @io.getc.should == utf8('a')
      @io.getc.should be_nil
    end
  end
end
