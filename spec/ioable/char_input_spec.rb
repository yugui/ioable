#-*- encoding: US-ASCII -*-

require File.expand_path("../../spec_helper", __FILE__)
require File.expand_path("../shared/empty_input_impl_spec.rb", __FILE__)

require 'ioable/char_input'

describe IOable::CharInput do
  before do
    @byte_input = Object.new
    @io = IOable::CharInput.new(@byte_input, Encoding::UTF_8)
  end

  it_should_behave_like 'empty input impl'

  describe '#getbyte' do
    it "should read a chunk of bytes from the internal byte stream" do
      mock(@byte_input).eof?{ false }
      mock(@byte_input).sysread(is_a(Integer)){ binary("abc") }
      mock(@byte_input).eof?{ false }
      mock(@byte_input).sysread(is_a(Integer)){ binary("defg") }

      @io.getbyte.should == ?a.ord
      @io.getbyte.should == ?b.ord
      @io.getbyte.should == ?c.ord
      @io.getbyte.should == ?d.ord
      @io.getbyte.should == ?e.ord
      @io.getbyte.should == ?f.ord
      @io.getbyte.should == ?g.ord
    end

    it "should return nil if eof" do
      mock(@byte_input).eof?{ true }

      @io.getbyte.should be_nil
    end

    it "should advance pos" do
      mock(@byte_input).eof?{ false }
      mock(@byte_input).sysread(is_a(Integer)){ binary("abc") }

      @io.getbyte
      @io.pos.should == 1
      @io.getbyte
      @io.pos.should == 2
    end
    
    it "should not advance pos if eof" do
      mock(@byte_input).eof?{ true }

      @io.getbyte
      @io.pos.should == 0
    end
  end

  describe '#pos' do
    before do
      stub(@byte_input).sysseek(is_a(Integer), anything)
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

    it "should call #sysseek on called" do
      mock(@io).sysseek(10, IO::SEEK_SET)

      @io.pos = 10
    end
  end

  describe "#seek" do
    before do
      stub(@io).sysseek(is_a(Integer), anything)
    end

    it "should call #sysseek" do
      mock(@io).sysseek(10, IO::SEEK_CUR)
      
      @io.seek(10, IO::SEEK_CUR)
    end

    it "should use IO::SEEK_SET if not specified the argument" do
      mock(@io).sysseek(10, IO::SEEK_SET)
      
      @io.seek(10)
    end

    it "should set #pos to the given position" do
      mock(@io).sysseek(10, IO::SEEK_SET) { 10 }
      @io.seek(10)
      @io.pos.should == 10

      mock(@io).sysseek(10, IO::SEEK_CUR) { 20 }
      @io.seek(10, IO::SEEK_CUR)
      @io.pos.should == 20
    end
    
    it 'should pass through the error sysseek rises' do
      mock(@io).sysseek(10, IO::SEEK_SET) { raise Errno::ESPIPE }
      lambda { @io.seek(10) }.should raise_error(Errno::ESPIPE)

      mock(@io).sysseek(100, IO::SEEK_SET) { raise Errno::EINVAL }
      lambda { @io.seek(100) }.should raise_error(Errno::EINVAL)
    end

    it 'should not change #pos on error' do
      stub(@io).sysseek(is_a(Integer), anything) { raise Errno::EBADF }
      @io.seek(10) rescue nil

      @io.pos.should == 0
    end

    it "should return zero" do
      @io.seek(10).should == 0
      @io.seek(10).should == 0
    end
  end

  describe '#rewind' do
    before do
      stub(@io).sysseek(is_a(Integer), anything)
    end
    it "should change #pos to zero" do
      @io.pos = 10
      @io.rewind
      @io.pos.should == 0
    end
    it "should call sysseek on called" do
      mock(@io).sysseek(0, IO::SEEK_SET)

      @io.rewind
    end
    it "should return zero" do
      @io.rewind.should == 0
    end
  end

  describe "#to_io" do
    it "should return self" do
      @io.to_io.should be_equal(@io)
    end
  end

  describe "#ungetbyte" do
    it "should accept an integer" do
      lambda { @io.ungetbyte(1) }.should_not raise_error
    end
    it "should not accept any negative integer" do
      lambda { @io.ungetbyte(0) }.should_not raise_error
      lambda { @io.ungetbyte(-1) }.should raise_error(TypeError)
    end
    it "should not accept >= 256" do
      lambda { @io.ungetbyte(255) }.should_not raise_error
      lambda { @io.ungetbyte(256) }.should raise_error(TypeError)
    end
    it "should accept a single byte string" do
      lambda { @io.ungetbyte("a") }.should_not raise_error
    end

    it "should make the next call of #getbyte return the given byte" do
      @io.ungetbyte(1)
      @io.getbyte.should == 1

      @io.ungetbyte("a")
      @io.getbyte.should == ?a.ord
    end
  end

  describe '#getc' do
    it "should return a character for each call" do
      mock(@byte_input).eof? { false }
      mock(@byte_input).sysread(is_a(Integer)){ binary("a") }
      mock(@byte_input).eof? { false }
      mock(@byte_input).sysread(is_a(Integer)){ binary("b") }

      c = @io.getc
      c.should == utf8('a')
      c.encoding.should == Encoding::UTF_8
      c = @io.getc
      c.should == utf8('b')
      c.encoding.should == Encoding::UTF_8
    end

    it "should return nil if sysread reached EOF" do
      mock(@byte_input).eof? { false }
      mock(@byte_input).sysread(is_a(Integer)){ binary("a") }
      mock(@byte_input).eof? { true }

      @io.getc.should == utf8('a')
      @io.getc.should be_nil
    end

    it "should return a byte fragment if the input is a broken character sequence" do
      eof = false
      stub(@byte_input).eof? { eof }
      mock(@byte_input).sysread(is_a(Integer)){
        eof = true
        binary("\xFF\xE3\x81\x82\xC3\x80\xC3A\xC3")
      }

      [
        [ 0xFF ],
        [ 0xE3, 0x81, 0x82 ],
        [ 0xC3, 0x80 ],
        [ 0xC3 ],
        [ ?A.ord ],
        [ 0xC3 ],
      ].each do |expected_bytes|
        c = @io.getc
        c.encoding.should == Encoding::UTF_8
        c.bytes.to_a.should == expected_bytes
      end
      @io.getc.should be_nil
    end
  end

  describe '#read' do
    before do
      mock(@byte_input).eof?{ false }
      mock(@byte_input).sysread(is_a(Integer)){ binary("abcdefg\n") }
      mock(@byte_input).eof?{ false }
      mock(@byte_input).sysread(is_a(Integer)){ binary("hijk") }
      mock(@byte_input).eof?{ false }
      mock(@byte_input).sysread(is_a(Integer)){ binary("lmnopqr\n") }
      mock(@byte_input).eof?{ true }
    end

    describe "on no arguments given" do
      it "should return the whole of the contents" do
        @io.read.should == "abcdefg\nhijklmnopqr\n"
      end
      it "should return a String in a text encoding" do
        @io.read.encoding.should == Encoding::UTF_8
      end
      it "should convert encoding if the external and the internal differ" do
        @io.set_encoding(Encoding::CP932, Encoding::UTF_16LE)
        result = @io.read
        result.should == "abcdefg\nhijklmnopqr\n".encode(Encoding::UTF_16LE)
      end
    end
  end
end
