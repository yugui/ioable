#-*- encoding: UTF-8 -*-

require File.expand_path("../../spec_helper", __FILE__)
require File.expand_path("../shared/empty_input_impl_spec.rb", __FILE__)

require 'ioable/buffered_input'

describe IOable::BufferedInput do
  before do
    @byte_input = Object.new
    @io = IOable::BufferedInput.new(@byte_input, Encoding::UTF_8)
  end

  it_should_behave_like 'empty input impl'

  shared_examples_for '#read() family' do
    before do
      is_eof = false
      stub(@byte_input).eof? { is_eof }
      stub(@byte_input).sysread.with_any_args { is_eof = true; binary("a") }
    end

    it "should raise an ArgumentError if the first argument is negative" do
      lambda { @io.send(@read_method, *@read_args, -1) }.should raise_error(ArgumentError, /negative/)
    end

    it "should send #to_int to the first argument if it is not an integer" do
      len = Object.new
      mock(len).to_int { 1 }
      @io.send(@read_method, *@read_args, len).should == 'a'
    end
  end

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

    it "should not accept anything else" do
      something_else = Object.new
      lambda { @io.ungetc(something_else) }.should raise_error(TypeError)
    end

    describe "with side effects to the buffer" do
      before do
        @data = []
        stub(@byte_input).sysread(is_a(Integer)) { @data.shift }
        stub(@byte_input).eof?{ @data.empty? }
      end

      it "should let the next call of #getbyte return the given byte" do
        @io.ungetbyte(1)
        dont_allow(@byte_input).eof?
        dont_allow(@byte_input).sysread.with_any_args
        @io.getbyte.should == 1

        @io.ungetbyte("a")
        dont_allow(@byte_input).eof?
        dont_allow(@byte_input).sysread.with_any_args
        @io.getbyte.should == ?a.ord
      end


      it "should let the next call of a buffered input method combine the given byte to the buffer" do
        @data = [ binary("\x81\x82\x81\x82") ]
        @io.ungetbyte(0xE3)
        @io.getc.should == "あ"

        @io.ungetbyte("\xE3")
        @io.getc.should == "あ"
      end

      it "should decrease #pos by 1" do
        @io.ungetbyte(1)
        @io.pos.should == -1
        @io.getbyte
        @io.pos.should == 0

        @data = [ binary("a") ]
        @io.getbyte
        @io.pos.should == 1
        @io.ungetbyte("b")
        @io.pos.should == 0
      end
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

    it "should call #sysseek with SEEK_SET" do
      mock(@byte_input).sysseek(10, IO::SEEK_SET)

      @io.pos = 10
    end
  end

  describe "#seek" do
    before do
      stub(@byte_input).sysseek(is_a(Integer), anything) { 0 }
    end

    it "should call @byte_input#sysseek" do
      mock(@byte_input).sysseek(10, IO::SEEK_END)

      @io.seek(10, IO::SEEK_END)
    end

    it "should use IO::SEEK_SET if not specified the argument" do
      mock(@byte_input).sysseek(10, IO::SEEK_SET)

      @io.seek(10)
    end

    it "should set #pos to the given position" do
      mock(@byte_input).sysseek(10, IO::SEEK_SET) { 10 }
      @io.seek(10)
      @io.pos.should == 10

      mock(@byte_input).sysseek(-10, IO::SEEK_END) { 20 }
      @io.seek(-10, IO::SEEK_END)
      @io.pos.should == 20
    end

    it 'should pass through the error sysseek rises' do
      mock(@byte_input).sysseek(10, IO::SEEK_SET) { raise Errno::ESPIPE }
      lambda { @io.seek(10) }.should raise_error(Errno::ESPIPE)

      mock(@byte_input).sysseek(100, IO::SEEK_SET) { raise Errno::EINVAL }
      lambda { @io.seek(100) }.should raise_error(Errno::EINVAL)
    end

    it 'should not change #pos on error' do
      stub(@byte_input).sysseek(is_a(Integer), anything) { raise Errno::EBADF }
      @io.seek(10) rescue nil

      @io.pos.should == 0
    end

    it "should return zero" do
      @io.seek(10).should == 0
      @io.seek(10).should == 0
    end

    it "should clear the buffer" do
      eof = false
      stub(@byte_input).eof? { eof }
      mock(@byte_input).sysread(is_a(Integer)) { binary("abcde") }
      mock(@byte_input).sysseek(1, IO::SEEK_SET) { 1 }
      mock(@byte_input).sysread(is_a(Integer)) { eof = true; binary("bcde") }

      @io.read(3).should == binary("abc")
      @io.ungetbyte("A")
      @io.seek(1, IO::SEEK_SET)
      @io.read.should == "bcde"
    end

    it "should calculate the target position from #pos" do
      stub(@byte_input).eof? { false }
      mock(@byte_input).sysread(is_a(Integer)) { binary("abcde") }
      mock(@byte_input).sysseek(1, IO::SEEK_SET) { 1 }
      mock(@byte_input).sysread(is_a(Integer)) { binary("bcde") }

      @io.read(3).should == binary("abc")
      @io.ungetbyte(1)
      @io.pos.should == 2
      @io.seek(-1, IO::SEEK_CUR)
      @io.read(3).should == binary("bcd")
    end

    it "should accept an object responding to #to_int" do
      offset = Object.new
      stub(offset).to_int { 1 }
      mock(@byte_input).sysseek(1, IO::SEEK_SET) { 1 }

      @io.seek(offset)
    end
  end

  describe "#sysseek" do
    it "is delegated to the wrapped byte stream" do
      mock(@byte_input).sysseek(10, IO::SEEK_CUR) { 1 }

      @io.sysseek(10, IO::SEEK_CUR)
    end

    it "raises an Errno::EINVAL if the buffer is not empty" do
      dont_allow(@byte_input).sysseek.with_any_args
      @io.ungetbyte(1)
      lambda { @io.sysseek(10) }.should raise_error(Errno::EINVAL, /sysseek for buffered IO/)
    end

    it "should use IO::SEEK_SET if not specified the argument" do
      mock(@byte_input).sysseek(10, IO::SEEK_SET)
      
      @io.sysseek(10)
    end

    it "should set #pos to the given position" do
      mock(@byte_input).sysseek(10, IO::SEEK_SET) { 10 }
      @io.sysseek(10)
      @io.pos.should == 10

      mock(@byte_input).sysseek(-10, IO::SEEK_END) { 20 }
      @io.sysseek(-10, IO::SEEK_END)
      @io.pos.should == 20
    end
    
    it 'should pass through the error sysseek rises' do
      mock(@byte_input).sysseek(10, IO::SEEK_SET) { raise Errno::ESPIPE }
      lambda { @io.sysseek(10) }.should raise_error(Errno::ESPIPE)

      mock(@byte_input).sysseek(100, IO::SEEK_SET) { raise Errno::EINVAL }
      lambda { @io.sysseek(100) }.should raise_error(Errno::EINVAL)
    end

    it 'should not change #pos on error' do
      stub(@byte_input).sysseek(is_a(Integer), anything) { raise Errno::EBADF }
      @io.sysseek(10) rescue nil

      @io.pos.should == 0
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

    it "should advance #pos by -1" do
      @io.ungetbyte(1)
      @io.pos.should == -1
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

    it "should advance #pos by the length of the returned string" do
      data = [ binary("aあ") ]
      stub(@byte_input).sysread(is_a(Integer)) { data.shift }
      stub(@byte_input).eof? { data.empty? }

      @io.getc
      @io.pos.should == 1
      @io.getc
      @io.pos.should == 4
    end

    it "should not advance #pos if eof" do
      stub(@byte_input).eof? { true }
      @io.getc
      @io.pos.should == 0
    end

    it "should convert the result to the internal encoding if necessary" do
      data = [ binary("あ") ]
      stub(@byte_input).sysread(is_a(Integer)) { data.shift }
      stub(@byte_input).eof? { data.empty? }

      @io.set_encoding(Encoding::UTF_8, Encoding::CP932)
      @io.getc.should == "あ".encode(Encoding::CP932)
    end

    it "should raise an InvalidByteSequenceError by default for a broken byte fragments" do
      data = [ binary("\xFF\xFF") ]
      stub(@byte_input).sysread(is_a(Integer)) { data.shift }
      stub(@byte_input).eof? { data.empty? }

      @io.set_encoding(Encoding::UTF_8, Encoding::CP932)
      lambda { @io.getc }.should raise_error(Encoding::InvalidByteSequenceError)
    end

    it "should apply the specified convertion options if available" do
      data = [ binary("\xFF\xFF") ]
      stub(@byte_input).sysread(is_a(Integer)) { data.shift }
      stub(@byte_input).eof? { data.empty? }

      @io.set_encoding(Encoding::UTF_8, Encoding::CP932, invalid: :replace)
      @io.getc.should == '?'
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

    describe "on fulltext reading mode" do
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
        @io.set_encoding(Encoding::UTF_8, Encoding::UTF_32LE)
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

      it "should make the second argument empty but return nil if eof" do
        @io.read

        buf = "something different"
        returned = @io.read(nil, buf)
        returned.should be_nil
        buf.should be_empty
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

      it "should advance #pos by the length of the read bytes" do
        @io.read(3)
        @io.pos.should == 3

        @io.read(1000)
        @io.pos.should == 23
      end

      it "should not change the internal state on error" do
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

      it "should make the second argument empty if it is given but eof" do
        @io.read

        buf = "something different"
        returned = @io.read(3, buf)
        returned.should be_nil
        buf.should be_empty
      end

      it_should_behave_like('#read() family') do
        before do
          @read_method = :read
        end
      end
    end
  end

  describe "#lineno" do
    it "should be 0 at first" do
      @io.lineno.should == 0
    end
  end

  describe "#gets" do
    before do
      @data = []
      stub(@byte_input).sysread(is_a(Integer)) { @data.shift }
      stub(@byte_input).eof?{ @data.empty? }

      @orig_separator = $/
    end

    after do
      $/ = @orig_separator
    end

    describe "on separator not specified" do
      it "should return a line" do
        @data = [ binary("abcde"), binary("fg\nhi") ]

        @io.gets.should == "abcdefg\n"
      end

      it "should return a line in the external encoding if the internal encoding is nil" do
        @data = [ binary("abcde"), binary("fg\nhi") ]

        @io.gets.encoding.should == Encoding::UTF_8
      end

      it "can return a broken charater" do
        @data = [ binary("a\xFF\xFF\nc"), binary("d") ]

        @io.gets.should == "a\xFF\xFF\n"
      end

      it "should return a line in the internal encoding if the internal encoding is not nil" do
        @io.set_encoding(Encoding::UTF_8, Encoding::ISO_2022_JP)
        @data = [ binary("abcdeあ"), binary("fg\nhi") ]

        line = @io.gets
        line.should == "abcdeあfg\n".encode(Encoding::ISO_2022_JP)
        line.encoding.should == Encoding::ISO_2022_JP
      end

      it "should advance #lineno" do
        @data = [ binary("abcde"), binary("fg\nhi") ]

        @io.gets
        @io.lineno.should == 1

        @io.gets
        @io.lineno.should == 2
      end

      it "should set $. to #lineno" do
        @data = [ binary("abcdeあ"), binary("fg\nhi") ]

        @io.gets
        $..should == 1

        $. = 1000

        @io.gets
        $..should == 2
      end

      it "should return nil if eof" do
        @io.gets.should be_nil
      end

      it "should advance #pos by the length of the read bytes" do
        @data = [ binary("abあ"), binary("d\nef") ]

        @io.set_encoding(Encoding::UTF_8, Encoding::CP932)
        @io.gets
        @io.pos.should == 7
        @io.gets
        @io.pos.should == 9
      end

      it "should advance #lineno by 1" do
        @data = [ binary("abc"), binary("d\nef") ]

        @io.gets
        @io.lineno.should == 1
        @io.gets
        @io.lineno.should == 2
      end

      it "should read at most the specified bytes" do
        @data = [ binary("abc\nd"), binary("efgh\ni"), binary("\njk") ]
        @io.gets(2).should == "ab"
        @io.gets(3).should == "c\n"
        @io.gets(nil, 9).should == "defgh\ni\nj"
      end

      it "should not break a character to fit to limit" do
        @data = [ binary("あabc") ]

        @io.gets(2).should == "あ"
      end

      it "should return an empty string when limit == 0 even if eof" do
        @data = []
        @io.gets(0).should == ""
      end

      it "should count the specified bytes in the external encoding" do
        @data = [ binary("abc"), binary("あいう".encode(Encoding::CP932)), binary("abc") ]
        @io.set_encoding(Encoding::CP932, Encoding::UTF_8)

        @io.gets(6).should == "abcあい"
      end

      it "should accept an object responding to #to_int as a limit" do
        @data = [ binary("abc"), binary("de\ng") ]
        len = Object.new
        stub(len).to_int { 4 }

        @io.gets(len).should == "abcd"
      end

      it_should_behave_like '#read() family' do
        before do
          @read_method = :gets
        end
      end
    end

    describe "with an alternative line separator" do
      it "should read the separator from $/ if not specified in argumetns" do
        @data = [ binary("a"), binary("baba"), binary("abbaba"), binary("bab/ba/bab") ]
        $/ = 'ab'

        @io.gets.should == "ab"
        @io.gets.should == "ab"
        @io.gets.should == "aab"
        @io.gets.should == "bab"
        @io.gets.should == "ab"
        @io.gets.should == "ab"
        @io.gets.should == "/ba/bab"
      end

      it "should use the argument as the separator if specified" do
        @data = [ binary("a"), binary("baba"), binary("abbaba"), binary("bab/ba/bab") ]

        @io.gets("ab").should == "ab"
        @io.gets("ab").should == "ab"
        @io.gets("ab").should == "aab"
        @io.gets("ab").should == "bab"
        @io.gets("ab").should == "ab"
        @io.gets("ab").should == "ab"
        @io.gets("ab").should == "/ba/bab"
      end

      it "should accept multibyte characters as a separator" do
        @data = [ binary("a"), binary("bあいc\xE3"), binary("\x81\x82d") ]

        @io.gets("あ").should == "abあ"
        @io.gets("あ").should == "いcあ"
        @io.gets("あ").should == "d"
      end

      it "should accept multibyte separator in the internal encoding if internal encoding is not nil" do
        @data = [ binary("a"), binary("bあいc\xE3"), binary("\x81\x82d") ]
        @io.set_encoding(Encoding::UTF_8, Encoding::ISO_2022_JP)

        @io.gets("あ".encode(Encoding::ISO_2022_JP)).should == "abあ".encode(Encoding::ISO_2022_JP)
        @io.gets("あ".encode(Encoding::ISO_2022_JP)).should == "いcあ".encode(Encoding::ISO_2022_JP)
      end

      it "should raise an ArgumentError if the encoding of the separator does not match to the IO's" do
        @data = [ binary("a"), binary("bあいc\xE3"), binary("\x81\x82d") ]
        @io.set_encoding(Encoding::UTF_8)
        lambda { @io.gets("\xE3\x81\x82".force_encoding(Encoding::CP932)) }.should \
          raise_error(ArgumentError, /encoding mismatch/)

        @data = [ binary("a"), binary("bあいc\xE3"), binary("\x81\x82d") ]
        @io.set_encoding(Encoding::UTF_8, Encoding::CP932)
        lambda { @io.gets("あ") }.should raise_error(ArgumentError, /encoding mismatch/)
      end

      it "should not raise an ArgumentError for ascii RS even if the encoding of the separator does not match to the IO's" do
        @data = [ binary("a"), binary("bあいc\xE3"), binary("\x81\x82d") ]
        @io.set_encoding(Encoding::UTF_8)
        lambda { @io.gets("c".force_encoding(Encoding::CP932)) }.should_not raise_error
      end

      it "should return nil if eof" do
        @io.gets("あ").should == nil
      end

      it "should advance #pos by the length of the read bytes" do
        @data = [ binary("abあ"), binary("d\nef") ]

        @io.set_encoding(Encoding::UTF_8, Encoding::CP932)
        @io.gets("あ".encode(Encoding::CP932))
        @io.pos.should == 5
        @io.gets("あ".encode(Encoding::CP932))
        @io.pos.should == 9
      end

      it "should advance #lineno by 1" do
        @data = [ binary("abあ"), binary("d\nef") ]

        @io.gets("あ")
        @io.lineno.should == 1
        @io.gets("あ")
        @io.lineno.should == 2
      end

      it "should not recognize a part of char as a separator" do
        # "表" contains \x5c
        @data = [ "バイト表現に0x5C(\\)".encode(Encoding::CP932).force_encoding(Encoding::ASCII_8BIT) ]

        @io.set_encoding(Encoding::CP932)
        @io.gets('\\').should == "バイト表現に0x5C(\\".encode(Encoding::CP932)
        @io.gets('\\').should == ")".encode(Encoding::CP932)

        # \x82 is valid as both a leading byte and a following byte in CP932.
        @data = [ "\x81\x82\x82\x82".force_encoding(Encoding::CP932) ]
        @io.gets("\x82\x82".force_encoding(Encoding::CP932)).should ==
          "\x81\x82\x82\x82".force_encoding(Encoding::CP932)
      end

      it_should_behave_like '#read() family' do
        before do
          @read_method = :gets
          @read_args = [ "b" ]
        end
      end
    end

    describe "with nil separator" do
      it "should return the whole of file if $/ is nil" do
        @data = [ binary("abcd"), binary("efgh\ni"), binary("jk") ]
        $/ = nil
        line = @io.gets
        line.should == "abcdefgh\nijk"
      end

      it "should return the whole of file if the specified separator is nil" do
        @data = [ binary("abcd"), binary("efgh\ni"), binary("jk") ]
        line = @io.gets(nil)
        line.should == "abcdefgh\nijk"
      end

      it "should return a string in the external encoding if the internal encoding is nil" do
        @data = [ binary("abcd"), binary("efgh\ni"), binary("jk") ]
        line = @io.gets(nil)
        line.encoding.should == Encoding::UTF_8
      end

      it "should convert the returned string to the internal encoding unless the internal encoding is nil" do
        @data = [ binary("abcd"), binary("eあfgh\ni"), binary("jk") ]
        @io.set_encoding(Encoding::UTF_8, Encoding::CP932)

        line = @io.gets(nil)
        line.should == "abcdeあfgh\nijk".encode(Encoding::CP932)
      end

      it "should return nil if eof" do
        @io.gets(nil).should == nil
      end

      it "should return at most the specified number of bytes if limit is specified" do
        @data = [ binary("abcd"), binary("eあfgh\ni"), binary("jk") ]
        @io.set_encoding(Encoding::UTF_8, Encoding::CP932)

        line = @io.gets(nil, 10)
        line.should == "abcdeあfg".encode(Encoding::CP932)
      end

      it "should not break a multibyte character at the specified limit" do
        @data = [ binary("abあcd\xFF\xFF"), binary("eあfgh\ni\xE3"), binary("\x81\x82jk") ]
        @io.set_encoding(Encoding::UTF_8, Encoding::CP932, invalid: :replace)

        line = @io.gets(nil, 5)
        line.should == "abあ".encode(Encoding::CP932)
        line = @io.gets(nil, 6)
        line.should == "cd\xFF\xFFeあ".encode(Encoding::CP932, invalid: :replace)
        line = @io.gets(nil, 6)
        line.should == "fgh\niあ".encode(Encoding::CP932)
      end

      it_should_behave_like '#read() family' do
        before do
          @read_method = :gets
          @read_args = [ nil ]
        end
      end
    end

    describe "on paragraph mode" do
      it "should use empty lines as the separator if $/ is an empty string" do
        @data = [ binary("abc\n\nd"), binary("efgh\ni\n"), binary("\njk") ]
        $/ = ""

        @io.gets.should == "abc\n\n"
        @io.gets.should == "defgh\ni\n\n"
        @io.gets.should == "jk"
      end

      it "should use empty lines as the separator if rs is an empty string" do
        @data = [ binary("abc\n\nd"), binary("efgh\ni\n"), binary("\njk") ]

        @io.gets("").should == "abc\n\n"
        @io.gets("").should == "defgh\ni\n\n"
        @io.gets("").should == "jk"
      end

      it "can handle more than one empty lines" do
        @data = [ binary("abc\n\ndef\n\n\nghi\n\n\n\njkl\n") ]
        @io.gets("").should == "abc\n\n"
        @io.gets("").should == "def\n\n"
        @io.gets("").should == "ghi\n\n"
        @io.gets("").should == "jkl\n"
        @io.gets("").should == nil
      end


      it "should ignore the preceeding empty lines" do
        @data = [ binary("\nabc\n"), binary("\nd") ]

        @io.gets("").should == "abc\n\n"
        @io.gets("").should == "d"
        @io.gets("").should == nil
      end

      it "should ignore the trailing empty lines" do
        @data = [ binary("abc\n"), binary("\nd\n\n\n\n") ]

        @io.gets("").should == "abc\n\n"
        @io.gets("").should == "d\n\n"
        @io.gets("").should == nil
      end


      it "should return at most the specified number of bytes if limit is specified" do
        @data = [ binary("abc\n\nd"), binary("efgh\ni\n"), binary("\njk") ]
        @io.gets("", 3).should == "abc"
        @io.gets("", 1).should == "d"
        @io.gets("", 2).should == "ef"
        @io.gets("", 4).should == "gh\ni"
        @io.gets("", 2).should == "jk"
      end

      it "should not break a multibyte character at the specified limit" do
        @data = [ binary("\nabあ\n\ncd\xFF\xFF"), binary("あ\ni\n\xE3"), binary("\x81\x82\xFF\n\n") ]
        @io.set_encoding(Encoding::UTF_8, Encoding::CP932, invalid: :replace)

        line = @io.gets("", 3)
        line.should == "abあ".encode(Encoding::CP932)
        line = @io.gets("", 4)
        line.should == "cd\xFF\xFF".encode(Encoding::CP932, invalid: :replace)
        line = @io.gets("", 2)
        line.should == "あ".encode(Encoding::CP932)
        line = @io.gets("", 3)
        line.should == "i\nあ".encode(Encoding::CP932)
        line = @io.gets("", 2)
        line.should == "\xFF\n".encode(Encoding::CP932, invalid: :replace)
        @io.gets("", 2).should == nil
      end

      it "should count the specified length in #external_encoding" do
        @data = [ binary("aあい"), ]
        @io.set_encoding(Encoding::UTF_8, Encoding::CP932, invalid: :replace)

        line = @io.gets("", 4)
        line.should == "aあ".encode(Encoding::CP932)
      end

      it_should_behave_like '#read() family' do
        before do
          @read_method = :gets
          @read_args = [ "" ]
        end
      end
    end
  end

  describe "#ungetc" do
    it "should accept a single byte character" do
      lambda { @io.ungetc("a") }.should_not raise_error
    end

    it "should accept a multibyte character" do
      lambda { @io.ungetc("あ") }.should_not raise_error
    end

    it "should accept a byte for compatibility" do
      lambda { @io.ungetc(1) }.should_not raise_error
    end

    it "should not accept any negative integer" do
      lambda { @io.ungetc(0) }.should_not raise_error
      lambda { @io.ungetc(-1) }.should raise_error(TypeError)
    end

    it "should not accept >= 256" do
      lambda { @io.ungetc(255) }.should_not raise_error
      lambda { @io.ungetc(256) }.should raise_error(TypeError)
    end

    it "should not accept anything else" do
      something_else = Object.new
      lambda { @io.ungetc(something_else) }.should raise_error(TypeError)
    end

    describe "with side effects to the buffer" do
      before do
        @data = []
        stub(@byte_input).sysread(is_a(Integer)) { @data.shift }
        stub(@byte_input).eof?{ @data.empty? }
      end

      it "should let the next call of #getc return the given byte" do
        @io.ungetc("あ")
        dont_allow(@byte_input).eof?
        dont_allow(@byte_input).sysread.with_any_args
        @io.getc.should == "あ"

        @io.ungetbyte(?a.ord)
        dont_allow(@byte_input).eof?
        dont_allow(@byte_input).sysread.with_any_args
        @io.getc.should == 'a'
      end

      it "should let the next call of a buffered input method combine the given byte to the buffer" do
        @data = [ binary("\x81\x82\x81\x82") ]
        @io.ungetc(0xE3)
        @io.getc.should == "あ"

        @io.ungetc("\xE3")
        @io.getc.should == "あ"
      end

      it "should decrease #pos by the byte length of the given character" do
        @io.ungetc("あ")
        @io.pos.should == -3
        @io.getc
        @io.pos.should == 0

        @data = [ binary("a") ]
        @io.getbyte
        @io.pos.should == 1
        @io.ungetbyte("b")
        @io.pos.should == 0
      end
    end
  end

  describe "#readpartial" do
    before do
      @data = []
      stub(@byte_input).sysread(is_a(Integer)) { @data.shift }
      stub(@byte_input).eof?{ @data.empty? }
    end

    it "should return at most the specified number of bytes" do
      @data = [ binary("abcdef") ]
      @io.readpartial(2).should == binary("ab")
      @io.readpartial(2).should == binary("cd")
      @io.readpartial(2).should == binary("ef")
    end

    it "should return a binary string" do
      @data = [ binary("abcdef") ]
      @io.readpartial(2).encoding.should == Encoding::ASCII_8BIT
    end

    it "should return the buffered bytes if available" do
      stub(@byte_input).eof? { false }

      mock(@byte_input).sysread(is_a(Integer)) { binary("abc") }
      @io.getbyte

      dont_allow(@byte_input).sysread.with_any_args
      @io.readpartial(10).should == binary("bc")

      @io.ungetc("あ")
      @io.readpartial(10).should == binary("あ")
    end

    it "should read from @byte_input if no bytes available from the buffer" do
      eof = false
      stub(@byte_input).eof? { eof }

      mock(@byte_input).sysread(is_a(Integer)) { binary("abc") }
      @io.readpartial(4).should == binary("abc")

      mock(@byte_input).sysread(is_a(Integer)) { eof = true; binary("defg") }
      @io.readpartial(10).should == binary("defg")
    end

    it "should keep the remaining bytes in the buffer" do
      @data = [ binary("abc"), binary("defg") ]
      @io.readpartial(2)
      @io.ungetbyte(?d.ord)
      @io.read(3).should == binary("dcd")
      @io.ungetbyte(?f.ord)
      @io.readpartial(10).should == binary("fefg")
    end

    it "should not tries to read again if have succeeded to read something from @byteinput" do
      dont_allow(@byte_input).sysread.with_any_args

      @io.ungetbyte(?a.ord)
      @io.readpartial(1024).should == binary("a")
    end

    it "should raise neither EINTR nor EWOULDBLOCK even if @byte_input raise it" do
      eof = false
      stub(@byte_input).eof? { eof }

      mock(@byte_input).sysread(is_a(Integer)) { raise Errno::EINTR }
      mock(@byte_input).sysread(is_a(Integer)) { binary("abc") }
      mock(@byte_input).sysread(is_a(Integer)) { raise Errno::EWOULDBLOCK }
      mock(@byte_input).sysread(is_a(Integer)) { eof = true; binary("def") }

      bytes = nil
      lambda { bytes = @io.readpartial(4) }.should_not raise_error
      bytes.should == binary("abc")

      bytes = nil
      lambda { bytes = @io.readpartial(4) }.should_not raise_error
      bytes.should == binary("def")
    end

    it "should advance #pos by the length of the returned bytes" do
      @data = [ binary("abc"), binary("defg"), binary("hijk"), binary("lm") ]

      @io.readpartial(3)
      @io.pos.should == 3
      @io.readpartial(2)
      @io.pos.should == 5
      @io.readpartial(10)
      @io.pos.should == 7
      @io.readpartial(10)
      @io.pos.should == 11
      @io.readpartial(1)
      @io.pos.should == 12
    end

    it "should return nil if eof" do
      @io.readpartial(10).should be_nil
    end

    it "should return an empty string even if eof when the required length is zero" do
      @io.readpartial(0).should == ""
    end

    it "should replace the second argument and return it if it is given" do
      @data = [ binary("abc") ]
      output = "あいう"
      returned = @io.readpartial(100, output)
      returned.should be_equal(output)
      output.encoding.should == Encoding::ASCII_8BIT
      output.should == binary("abc")
    end

    it "should make the second argument empty but return nil if eof" do
      output = "あいう"
      @io.readpartial(100, output).should be_nil
      output.should be_empty
    end

    it_should_behave_like '#read() family' do
      before do
        @read_method = :readpartial
      end
    end
  end

  describe "#sysread" do
    it "should be forwrded to @byte_input" do
      len = Object.new
      outbuf = Object.new
      mock(@byte_input).sysread(len, outbuf) { outbuf }

      @io.sysread(len, outbuf)
    end

    it "should raise an IOError if the buffer is not empty" do
      @io.ungetbyte(1)
      lambda { @io.sysread(1) }.should raise_error(IOError, "sysread for a buffered IO")
    end

    it "should not rescue any error" do
      stub(@byte_input).sysread(is_a(Integer)) { raise Errno::EAGAIN }
      lambda { @io.sysread(3) }.should raise_error(Errno::EAGAIN)

      stub(@byte_input).sysread(is_a(Integer)) { raise EOFError }
      lambda { @io.sysread(3) }.should raise_error(EOFError)
    end
  end

  describe "#nread"
  describe "#read_nonblock"
end
