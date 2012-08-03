shared_examples_for 'byte-wide input' do
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
      dont_allow(@io).eof?
      dont_allow(@io).sysread.with_any_args
      @io.getbyte.should == 1

      @io.ungetbyte("a")
      dont_allow(@io).eof?
      dont_allow(@io).sysread.with_any_args
      @io.getbyte.should == ?a.ord
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

    it "should read a string from #sysread and yield it until eof" do
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

  describe '#pos' do
    before do
      stub(@io).sysseek(is_a(Integer), anything)
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

    it "should accept an object responding to #to_int" do
      len = Object.new
      stub(len).to_int { 1 }
      mock(@io).sysseek(1, IO::SEEK_SET)

      @io.seek(len)
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

  describe "readpartial" do
    it "should return the buffered content if available" do
      @io.ungetbyte(1)
      dont_allow(@io).eof?
      @io.readpartial(100).should == binary("\x1")
    end

    it "replaces the given buffer if given" do
      @io.ungetbyte(1)

      buf = "abcde"
      @io.readpartial(100, buf).should be_equal(buf)
      buf.should == binary("\x1")
    end

    it "calls #sysread if the buffer is empty" do
      stub(@io).eof? { false }
      mock(@io).sysread(100, is_a(String)) { binary("abcde") }

      @io.readpartial(100).should == binary("abcde")
    end

    it "retries #sysread if EINTR" do
      stub(@io).eof? { false }
      mock(@io).sysread(100, is_a(String)) { raise Errno::EINTR }
      mock(@io).sysread(100, is_a(String)) { binary("abcde") }

      @io.readpartial(100).should == binary("abcde")
    end

    it "raises EOFError if eof" do
      stub(@io).eof? { true }
      dont_allow(@io).sysread.with_any_args

      lambda { @io.readpartial(100) }.should raise_error(EOFError)
    end
  end

  describe "readnonblock"
  describe "nread" do
    it "should return 0 at first" do
      @io.nread.should == 0
    end

    it "should return 1 if called #ungetbyte" do
      @io.ungetbyte(32)
      @io.nread.should == 1
    end
  end
end

