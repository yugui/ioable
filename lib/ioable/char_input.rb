#-*- encoding: US-ASCII -*-
module IOable; end
class IOable::BufferredInput
  SUPPORT_ENCODING = RUBY_VERSION >= "1.9"
  def initialize(byte_input,
                 external = Encoding::default_external, internal = nil,
                 opt = nil)
    @byte_input = byte_input
    @buf = "".force_encoding(Encoding::ASCII_8BIT)
    @buf.instance_eval do
      def shift(len = 1)
        self[0, len].tap{ self[0, len] = "" }
      end
    end
    return unless SUPPORT_ENCODING

    @external_encoding =
      external.kind_of?(Encoding) ? external : Encoding.find(external)
    @internal_encoding =
      (internal.nil? || internal.kind_of?(Encoding)) ? internal : Encoding.find(internal)
    @opt = opt
  end
  private :initialize_encodings
  attr_reader :external_encoding, :internal_encoding

  def initialize_inputtable
    @pos = 0
    @lineno = 1
  end
  private :initialize_inputtable
  attr_accessor :pos, :lineno

  def lineno=(value)
    seek(value, IO::SEEK_SET)
  end

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
    %w[ byte byte ],
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
    fillbuf if @buf.empty?
    return @buf.shift
  end

  MAX_ASCII_BYTE = 127
  MAX_BYTES_FOR_CHAR = 5
  def getc
    fillbuf if @buf.empty?
    if @external_encoding.ascii_compatible? and @buf[0].ord < MAX_ASCII_BYTE
      char = @buf.shift.force_encoding(@external_encoding)
    else
      (1..MAX_BYTES_FOR_CHAR).each do |length|
        if @buf.length < length
          fillbuf
          redo
        else
          c = @buf[0, length].dup.force_encoding(@external_encoding)
          if c.valid_encoding?
            char = c
            break
          end
        end
      end
    end
    unless internal_encoding.nil? or external_encoding == internal_encoding
      char.encode!(internal_encoding)
    end
    return char
  end

  def gets
    offset = 0
    until index = @buf.index($/, offset)
      offset = @buf.length
      fillbuf
    end
    line = @buf[0..index]
    @buf[0..index] = ""
    return line
  end

  private
  INPUTTABLE_BUF_READ_SIZE = 256
  def fillbuf
    @buf << sysread(INPUTTABLE_BUF_READ_SIZE)
  end
end

