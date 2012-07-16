#-*- encoding: US-ASCII -*-
require 'forwardable'
require 'ioable/byte_inputtable'

class IOable::CharInput
  include IOable::ByteInputtable
  extend Forwardable

  SUPPORT_ENCODING = RUBY_VERSION >= "1.9"

  def initialize(byte_input,
                 external = Encoding::default_external, internal = nil,
                 opt = nil)
    @pos = 0
    @lineno = 1
    @byte_input = byte_input
    @buf = "".force_encoding(Encoding::ASCII_8BIT)
    @buf.instance_eval do
      def shift(len = 1)
        self[0, len].tap{ self[0, len] = "" }
      end
    end
    return unless SUPPORT_ENCODING
    initialize_encodings(external, internal, opt)
  end

  def initialize_encodings(external, internal = nil, opt = {})
    @external_encoding =
      external.kind_of?(Encoding) ? external : Encoding.find(external)
    @internal_encoding =
      (internal.nil? || internal.kind_of?(Encoding)) ? internal : Encoding.find(internal)
    @opt = opt
  end
  private :initialize_encodings

  attr_reader :external_encoding, :internal_encoding
  attr_accessor :lineno
  def_delegators :@byte_input, :sysread, :sysseek

  def set_encoding(*args)
    unless (1..3).include? args.size
      raise ArgumentError, "wrong number of arguments #{args.size} for 1..3"
    end
    opt = args.last.kind_of?(Hash) ? args.pop : {}
    case args.size
    when 1 
      if args[0].kind_of?(Encoding)
        initialize_encodings(args[0], Encoding::default_internal, opt)
      else
        external, internal = *args[0].split(':', 2)
        initialize_encodings(external, internal, opt)
      end
    when 2
      initialize_encodings(args[0], args[1], opt)
    else
      raise TypeError, "The last arguent must be a Hash"
    end
  end

  [
    %w[ char c ],
    %w[ line s ]
  ].each do |unit, get_suffix|
    eval(<<-EOF, nil, __FILE__, __LINE__+1)
      def each_#{unit}
        return enum_for(:each_#{unit}) unless block_given?
        while unit_value = get#{get_suffix}
          yield unit_value
        end
      end
      alias #{unit}s each_#{unit}

      def read#{unit}
        value = get{get_suffix}
        if value.nil?
          return value
        else
          raise EOFError, "end of file reached"
        end
      end
      EOF
  end

  def getbyte
    if @buf.empty?
      return nil if @byte_input.eof?
      fillbuf 
    end
    b = @buf.shift.ord
    @pos += 1
    return b
  end

  def ungetbyte(b)
    case b
    when Integer
      raise TypeError, "must be in 0...256, but got #{b}" unless (0...256).include?(b)
      @buf[0...0] = b.chr

    when String
      @buf[0...0] = b.chr

    else
      raise TypeError, "expected a byte or a string, but got #{b.class}"
    end
  end

  MAX_ASCII_BYTE = 127
  MAX_BYTES_FOR_CHAR = 5
  def getc
    if @buf.empty?
      return nil if @byte_input.eof?
      fillbuf
    end

    if @external_encoding.ascii_compatible? and @buf[0].ord < MAX_ASCII_BYTE
      char = @buf.shift.force_encoding(@external_encoding)
    else
      (1..MAX_BYTES_FOR_CHAR).each do |length|
        if @buf.length < length
          if @byte_input.eof?
            break
          else
            fillbuf
            redo
          end
        else
          c = @buf[0, length].force_encoding(@external_encoding)
          if c.valid_encoding?
            char = c
            @buf[0, length] = ""
            break
          end
        end
      end

      char = @buf.shift.force_encoding(@external_encoding) if char.nil?
    end
    unless internal_encoding.nil? or external_encoding == internal_encoding
      char.encode!(internal_encoding)
    end
    return char
  end

  def gets
    start_offset = 0
    until index = @buf.index($/, start_offset)
      start_offset = @buf.length
      fillbuf
    end
    line = @buf[0..index]
    @buf[0..index] = ""
    return line
  end

  def read(length = nil, outbuf = "")
    if @buf.empty? and @byte_input.eof?
      return length == 0 ? outbuf.replace("".force_encoding(Encoding::ASCII_8BIT)) : nil
    end

    if length.nil?
      outbuf.replace(@buf)
      @buf.clear
      begin
        until @byte_input.eof?
          fillbuf
          outbuf << @buf
          @buf.clear
        end
      rescue Object
        @buf[0...0] = outbuf
        raise
      end
      outbuf.force_encoding(@external_encoding)
      @pos += outbuf.bytesize

      if @internal_encoding and @internal_encoding != @external_encoding
        outbuf.encode!(@internal_encoding)
      end
      return outbuf
    else
      outbuf.replace("".force_encoding(Encoding::ASCII_8BIT))
      begin
        loop do
          new_chunk = @buf[0...length]
          outbuf << new_chunk
          length -= new_chunk.length
          @buf[0...new_chunk.length] = ""
          break if length == 0 or @byte_input.eof?
          fillbuf
        end
      rescue Object
        @buf[0...0] = outbuf
        raise
      end
      @pos += outbuf.bytesize
      return outbuf
    end
  end

  private
  INPUTTABLE_BUF_READ_SIZE = 256
  def fillbuf
    raise unless @buf.encoding == Encoding::ASCII_8BIT
    @buf << @byte_input.sysread(INPUTTABLE_BUF_READ_SIZE).force_encoding(Encoding::ASCII_8BIT)
  rescue Errno::EAGAIN
    retry
  end
end

