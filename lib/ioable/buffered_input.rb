#-*- encoding: US-ASCII -*-
require 'forwardable'
require 'ioable/byte_inputtable'

# A wrapper class to provides a full input functionalities based on a wrapped
# byte stream.
#
# The wrapped byte stream must implement at least the following methods:
# * #eof?
# * #sysseek
# * #sysread
#
class IOable::BufferedInput
  include IOable::ByteInputtable
  extend Forwardable

  SUPPORT_ENCODING = RUBY_VERSION >= "1.9"

  # byte_input:: The byte stream to wrap.
  # external:: External encoding of this input. Ignored if the Ruby is a 1.8.x.
  # internal:: Internal encoding of this input. Ignored if the Ruby is a 1.8.x.
  # opt:: Character conversion options for this input. Ignored if the Ruby is a 1.8.x.
  def initialize(byte_input,
                 external = Encoding::default_external, internal = nil,
                 opt = nil)
    @pos = 0
    @lineno = 0
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

  def initialize_encodings(external, internal = nil, opt = nil)
    @external_encoding =
      external.kind_of?(Encoding) ? external : Encoding.find(external)
    @internal_encoding =
      (internal.nil? || internal.kind_of?(Encoding)) ? internal : Encoding.find(internal)
    @opt = opt || {}
    @convert_options = @opt.select{|key, value|
      [
        :invalid, :undef, :replace, :fallback, :xml, 
        :cr_newline, :crlf_newline, :universal_newline
      ].include?(key)
    }
  end
  private :initialize_encodings

  attr_reader :external_encoding, :internal_encoding
  attr_accessor :lineno
  def_delegators :@byte_input, :sysread

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

    @pos -= 1
  end

  def seek(amount, whence = IO::SEEK_SET)
    @buf.clear
    if whence == IO::SEEK_CUR
      @pos += amount
      return super(@pos, IO::SEEK_SET)
    else
      return super
    end
  end

  def sysseek(amount, whence = IO::SEEK_SET)
    raise Errno::EINVAL, "sysseek for buffered IO" unless @buf.empty?
    @pos = @byte_input.sysseek(amount, whence)
  end

  MAX_ASCII_BYTE = 127
  # The maximum # of bytes per character in the encoding Ruby supports
  MAX_BYTES_FOR_CHAR = 5
  def getc
    if char = getc_raw
      @pos += char.bytesize
      char = to_internal(char)
    end
    return char
  end

  def gets(*args)
    case args.length
    when 0
      rs, limit = $/, nil
    when 1
      rs, limit = $/, nil
      case
      when args[0].kind_of?(String), args[0].nil?
        rs = args[0]
      when args[0].kind_of?(Integer)
        limit = args[0]
      when args[0].respond_to?(:to_str)
        rs = args[0].to_str
        raise TypeError, "#{args[0]}.to_str did not return an String" unless limit.kind_of?(String)
      when args[0].respond_to?(:to_int)
        limit = args[0].to_int
        raise TypeError, "#{args[0]}.to_int did not return an Integer" unless limit.kind_of?(Integer)
      end
    when 2
      rs, limit = *args
    else
      raise ArgumentError, "wrong number of arguments #{args.size} for 0..2"
    end

    io_enc = @internal_encoding || Encoding.default_internal || @external_encoding

    unless rs.nil? or rs.encoding == io_enc or 
      (rs.ascii_only? and (rs.empty? or io_enc.ascii_compatible?)) then
      if rs == "\n"
        rs = "\n".encode(io_enc)
      else
        raise ArgumentError, "encoding mismatch: #{io_enc.name} IO with #{rs.encoding.name} RS"
      end
    end

    if @buf.empty? and @byte_input.eof?
      return limit == 0 ?
        "".force_encoding(@internal_encoding || Encoding.default_internal || @external_encoding) :
        nil
    end
    if rs.nil?
      if limit.nil?
        return read
      else
        line = read_chars_limited_length(limit)
      end
    else
      rs = rs.empty? ? "\n\n" : rs
      if limit.nil?
        if rs.length == 1 and rs.ascii_only? and @external_encoding.ascii_compatible?
          line = fast_gets_raw(rs)
        else
          line = naive_gets_raw(rs, Float::INFINITY)
        end
      else
        line = naive_gets_raw(rs, limit)
      end
    end
    @pos += line.bytesize
    line.force_encoding(@external_encoding)
    line = to_internal(line)

    @lineno += 1
    $. = @lineno
    return line
  end

  def read(length = nil, outbuf = "")
    return read_full_contents(outbuf) if length.nil?
    length = ConvertHelper.try_convert(length, Integer, :to_int)

    case length <=> 0
    when -1
      raise ArgumentError, "the given length is negative"

    when 0
      return outbuf.clear.force_encoding(Encoding::ASCII_8BIT)

    when 1
      outbuf.clear.force_encoding(Encoding::ASCII_8BIT)
      return nil if @buf.empty? and @byte_input.eof?

      read_length_bytes(length, outbuf)
      @pos += outbuf.bytesize
      return outbuf
    end
  end

  private

  INPUTTABLE_BUF_READ_SIZE = 256
  def fillbuf
    raise unless @buf.encoding == Encoding::ASCII_8BIT
    @buf << @byte_input.sysread(INPUTTABLE_BUF_READ_SIZE).force_encoding(Encoding::ASCII_8BIT)
    nil
  rescue Errno::EAGAIN
    retry
  end

  # Similar to getc but:
  # * Does not convert the result to the internal string even if necessary.
  # * Does not advance #pos
  def getc_raw
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
    return char
  end

  # Similar to gets but:
  # * Does not convert the result to the internal string even if necessary.
  # * Does not advance #pos
  # * The algorithm is not efficient
  def naive_gets_raw(rs, limit)
    line = "".force_encoding(@external_encoding)
    while line.bytesize < limit and c = getc_raw
      line << c
      break if to_internal(line).end_with?(rs)
    end
    return line
  end

  # A fast implementation of gets(rs).
  # Works only if _rs_ is an ASCII character and the external_encoding is ASCII-compatible.
  # But this catches the most use case of #gets.
  def fast_gets_raw(rs)
    index = -1
    begin
      start_index = index + 1
      until index = @buf.index(rs, start_index)
        start_index = @buf.size
        if @byte_input.eof?
          index = -1
          line = @buf.clone
          @buf.clear
          return line
        end
        fillbuf
      end
      line = @buf[0..index]
    end until line.force_encoding(@external_encoding)[-1] == rs
    @buf[0..index] = ""
    return line
  end

  # Precondition: str.encoding must be in @external_encoding
  def to_internal(str, opt = {})
    raise ArgumentError if str.encoding != @external_encoding
    internal = @internal_encoding || Encoding.default_internal
    if internal.nil? or internal == @external_encoding
      str
    else
      str.encode(internal, @convert_options.merge(opt))
    end
  end

  # Reads until eof. Return the result in the external encoding.
  def read_full_contents_raw(outbuf)
    outbuf.replace(@buf)
    @buf.clear

    until @byte_input.eof?
      fillbuf
      outbuf << @buf
      @buf.clear
    end
    outbuf.force_encoding(@external_encoding)
  rescue Object
    @buf[0...0] = outbuf
    raise
  end

  # Implementation of read(nil, outbuf)
  def read_full_contents(outbuf)
    if @buf.empty? and @byte_input.eof?
      outbuf.clear.force_encoding(@external_encoding)
      return nil
    end

    read_full_contents_raw(outbuf)
    @pos += outbuf.bytesize
    outbuf = to_internal(outbuf)
    return outbuf
  end

  # Read bytes at most the specified length.
  def read_length_bytes(length, outbuf)
    loop do
      new_chunk = @buf[0...length]
      outbuf << new_chunk
      length -= new_chunk.length
      @buf[0...new_chunk.length] = ""
      break if length == 0 or @byte_input.eof?
      fillbuf
    end
    return outbuf
  rescue Object
    @buf[0...0] = outbuf
    raise
  end

  # @return encoded in @external_encoding
  def read_chars_limited_length(limit)
    line = "".force_encoding(Encoding::ASCII_8BIT)
    line = read_length_bytes(limit, line)

    MAX_BYTES_FOR_CHAR.times do
      line_ext = line.dup.force_encoding(@external_encoding)
      break if line_ext[-1].valid_encoding?

      # tries to fix the broken character by reading more.
      b = getbyte
      break unless b
      line << b
    end
    return line.force_encoding(@external_encoding)
  rescue Object
    @buf[0...0] = line
    raise
  end
end
