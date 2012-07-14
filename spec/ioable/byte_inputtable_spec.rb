#-*- encoding: US-ASCII -*-

require File.expand_path("../../spec_helper", __FILE__)
require 'ioable/byte_inputtable'

describe IOable::ByteInputtable do
  before do
    @io = Object.new
    @io.extend(IOable::ByteInputtable)
  end

  describe '#getbyte' do
    it "should read a byte from sysread" do
      mock(@io).eof?{ false }
      mock(@io).sysread(1){ binary("a") }
      mock(@io).eof?{ false }
      mock(@io).sysread(1){ binary("b") }

      b = @io.getbyte
      b.should == binary('a').ord
      b = @io.getbyte
      b.should == binary('b').ord
    end

    it "should return nil if eof" do
      mock(@io).eof?{ true }

      @io.getbyte.should be_nil
    end

    it "should advance pos" do
      mock(@io).eof?{ false }
      mock(@io).sysread(1){ binary("a") }
      mock(@io).eof?{ false }
      mock(@io).sysread(1){ binary("a") }

      @io.getbyte
      @io.pos.should == 1
      @io.getbyte
      @io.pos.should == 2
    end
    
    it "should not advance pos if eof" do
      mock(@io).eof?{ true }

      @io.getbyte
      @io.pos.should == 0
    end
  end

  describe '#readbyte' do
    it "should read a byte from sysread and return it" do
      mock(@io).eof?{ false }
      mock(@io).sysread(1){ binary("a") }
      mock(@io).eof?{ false }
      mock(@io).sysread(1){ binary("b") }

      b = @io.readbyte
      b.should == binary('a').ord
      b = @io.readbyte
      b.should == binary('b').ord
    end

    it "should raise EOFError if eof" do
      mock(@io).eof?{ true }

      lambda { @io.readbyte }.should raise_error(EOFError)
    end

    it "should advance pos" do
      mock(@io).eof?{ false }
      mock(@io).sysread(1){ binary("a") }
      mock(@io).eof?{ false }
      mock(@io).sysread(1){ binary("a") }

      @io.readbyte
      @io.pos.should == 1
      @io.readbyte
      @io.pos.should == 2
    end
    
    it "should not advance pos if eof" do
      mock(@io).eof?{ true }

      @io.readbyte rescue nil
      @io.pos.should == 0
    end
  end

  describe '#each_byte' do
    before do
      mock(@io).eof?{ false }
      mock(@io).sysread(1){ binary("a") }
      mock(@io).eof?{ false }
      mock(@io).sysread(1){ binary("b") }
      mock(@io).eof?{ true }
    end

    it "should read a string via sysread and yield it until eof" do
      bytes = []
      @io.each_byte do |b|
        bytes << b
      end
      bytes.should == [ binary('a').ord, binary('b').ord ]
    end

    it "should return an enumerator if no block given" do
      enum = @io.each_byte
      enum.should be_a_kind_of(Enumerator)

      enum.next.should == 'a'.ord
      enum.next.should == 'b'.ord
      lambda { enum.next }.should raise_error(StopIteration)
    end

    it "should advance pos" do
      @io.each_byte{}
      @io.pos.should == 2
    end
  end

  describe '#close' do
    it "should do nothing by default" do
      class << @io = mock!
        include IOable::ByteInputtable
      end
      @io.close
    end
  end

  describe '#close_read' do
    it "should do nothing by default" do
      class << @io = mock!
        include IOable::ByteInputtable
      end
      @io.close_read
    end
  end

  describe '#auto_close?' do
    it "should return false" do
      @io.auto_close?.should be_false
    end

    it "should ignore the value set" do
      @io.auto_close = true
      @io.auto_close?.should be_false
    end
  end

  describe '#close_on_exec?' do
    it "should return false" do
      @io.close_on_exec?.should be_false
    end

    it "should ignore the value set" do
      @io.close_on_exec = true
      @io.close_on_exec?.should be_false
    end
  end

  describe '#closed?' do
    it "should return false" do
      @io.closed?.should be_false
    end
  end
end
