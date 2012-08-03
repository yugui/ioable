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

    io_enc = @internal_encoding || @external_encoding

    unless rs.nil? or rs.encoding == io_enc or 
      (rs.ascii_only? and (rs.empty? or io_enc.ascii_compatible?)) then
      if rs == "\n"
        rs = "\n".encode(io_enc)
      else
        raise ArgumentError, "encoding mismatch: #{io_enc.name} IO with #{rs.encoding.name} RS"
      end
    end

    return nil if @buf.empty? and @byte_input.eof?
    if rs.nil?
      line = read(limit)
    elsif limit
      line = naive_gets_raw(rs, limit)
    else
       rs = rs.empty? ? "\n\n" : rs
      line = naive_gets_raw(rs, Float::INFINITY)
#       start_index = 0
#       until index = @buf.dup.force_encoding(@external_encoding).index(rs, start_index)
#         if @byte_input.eof?
#           index = @buf.dup.force_encoding(@external_encoding).length
#           break
#         end
#         start_index = [@buf.length - rs.bytesize + 1, 0].max
#         fillbuf
#       end
#       end_index = index + rs.length
#       line = @buf.dup.force_encoding(@external_encoding)[0...end_index]
#       @buf[0...line.bytesize] = ""
    end

    @pos += line.bytesize
    line.force_encoding(@external_encoding)
    line = to_internal(line)

    @lineno += 1
    $. = @lineno
    return line
  end

  def read(length = nil, outbuf = "")
    case
    when length.nil?
      outbuf.replace(@buf)
      return nil if @buf.empty? and @byte_input.eof?
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

    when length == 0
      return outbuf.clear.force_encoding(Encoding::ASCII_8BIT)

    when length < 0
      raise ArgumentError, "the given length is negative"

    when length.kind_of?(Integer) ||
      (length.repond_to?(:to_int) and (length = length.to_int).kind_of?(Integer))

      outbuf.clear.force_encoding(Encoding::ASCII_8BIT)
      return nil if @buf.empty? and @byte_input.eof?

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

  # Precondition: str.encoding must be in @external_encoding
  def to_internal(str)
    raise ArgumentError if str.encoding != @external_encoding
    if @internal_encoding.nil? or @internal_encoding == @external_encoding
      str
    else
      str.encode(@internal_encoding)
    end
  end
end

