#-*- encoding: UTF-8 -*-

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
      seq = [
        binary("abcdefg\n"),
        binary("hijk"),
        binary("あ"),
        binary("lmnopqr\n")
      ]
      stub(@byte_input).eof?{ seq.empty? }
      stub(@byte_input).sysread(is_a(Integer)){|n,| 
        raise RuntimeError, "wrong stub" if n < seq.first.size
        seq.shift
      }
    end

    describe "on no arguments given" do
      it "should call sysread until eof" do
        eof = false
        mock(@byte_input).eof?{ eof }.at_least(1)
        mock(@byte_input).sysread(is_a(Integer)) { binary("abc") }
        mock(@byte_input).sysread(is_a(Integer)) { binary("\ndefg") }
        mock(@byte_input).sysread(is_a(Integer)) { binary("あ") }
        mock(@byte_input).sysread(is_a(Integer)) { 
          eof = true
          binary("hijkl\n")
        }

        @io.read
      end

      it "should return the whole of the contents" do
        @io.read.should == "abcdefg\nhijkあlmnopqr\n"
      end

      it "should return a String in a text encoding" do
        @io.read.encoding.should == Encoding::UTF_8
      end

      it "should convert encoding if the external and the internal differ" do
        @io.set_encoding(Encoding::UTF_8, Encoding::UTF_16LE)
        result = @io.read
        result.encoding.should == Encoding::UTF_16LE
        result.should == "abcdefg\nhijkあlmnopqr\n".encode(Encoding::UTF_16LE)
      end

      it "should not convert encoding if the internal encoding is nil" do
        @io.set_encoding(Encoding::CP932, nil)
        result = @io.read
        result.should == "abcdefg\nhijkあlmnopqr\n".force_encoding(Encoding::CP932)
      end

      it "should return nil if eof" do
        @io.read
        @io.read.should be_nil
      end

      it "should advance #pos by the length of the returned text if no conversion happened" do
        str = @io.read
        @io.pos.should == str.bytesize
      end

      it "should advance #pos by the actually consumed bytesize , but not by the bytesize of the resturned text on a conversion happened" do
        @io.set_encoding(Encoding::CP932, Encoding::UTF_16LE)
        str = @io.read
        @io.pos.should_not == str.bytesize
        @io.pos.should == "abcdefg\nhijkあlmnopqr\n".bytesize
      end

      it "should start reading from #pos" do
        @io.read(3)
        @io.pos.should == 3

        @io.read.should == "defg\nhijkあlmnopqr\n"
      end

      it "does not change the internal state on error" do
        eof = false
        mock(@byte_input).eof?{ eof }.at_least(1)
        mock(@byte_input).sysread(is_a(Integer)) { binary("abc") }
        mock(@byte_input).sysread(is_a(Integer)) { raise Errno::ETIMEDOUT }
        mock(@byte_input).sysread(is_a(Integer)) { eof = true; binary("def") }

        lambda { @io.read }.should raise_error(Errno::ETIMEDOUT)
        @io.pos.should == 0
        @io.read.should == "abcdef"
      end

      it "should replace the second argument and return it if it is given" do
        buf = "something different"
        returned = @io.read(nil, buf)

        returned.should be_equal(buf)
        buf.should == "abcdefg\nhijkあlmnopqr\n"
      end
    end

    describe "on a length given as an argument" do
      it "should return the specified number of bytes if available" do
        @io.read(3).should == binary("abc")
      end

      it "should return a binary string" do
        @io.read(3).encoding.should == Encoding::ASCII_8BIT
      end

      it "should return the all available bytes if eof?" do
        str = @io.read(24)
        str.should == binary("abcdefg\nhijkあlmnopqr\n")
        str.encoding.should == Encoding::ASCII_8BIT
      end

      it "should returns nil if eof" do
        @io.read(24)

        @io.read(3).should be_nil
      end

      it "should return an empty string if eof but the length is zero" do
        @io.read(24)

        @io.read(0).should be_empty
        @io.read(0).encoding.should == Encoding::ASCII_8BIT
      end

      it "does not change the internal state on error" do
        eof = false
        mock(@byte_input).eof?{ eof }.at_least(1)
        mock(@byte_input).sysread(is_a(Integer)) { binary("abc") }
        mock(@byte_input).sysread(is_a(Integer)) { raise Errno::ETIMEDOUT }
        mock(@byte_input).sysread(is_a(Integer)) { eof = true; binary("def") }

        lambda { @io.read(5) }.should raise_error(Errno::ETIMEDOUT)
        @io.pos.should == 0
        @io.read(6).should == binary("abcdef")
      end

      it "should replace the second argument and return it if it is given" do
        buf = "something different"
        returned = @io.read(10, buf)

        returned.should be_equal(buf)
        buf.should == "abcdefg\nhi"

        returned = @io.read(0, buf)
        returned.should be_equal(buf)
        buf.should == ""
      end
    end
  end
end
