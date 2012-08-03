#-*- encoding: US-ASCII -*-
require 'enumerator'
require 'ioable/convert_helper'
require 'ioable/common_ioable'

module IOable; end

module IOable::CommonInputtable
  include IOable::CommonIOable
  alias close_read close
end

# Provides higher level byte-wide input methods to IO-like classes.
# Classes which includes this module must define at least the following methods:
# * sysseek
# * sysread
# * eof?
# Optionally it would be better to override #nread according to your #sysread implementation.
module IOable::ByteInputtable
  include IOable::CommonInputtable

  def pos
    @pos ||= 0
  end
  alias tell pos

  def pos=(value)
    seek(value, IO::SEEK_SET)
    @pos = value
  end

  def seek(offset, whence = IO::SEEK_SET)
    offset = ConvertHelper.try_convert(offset, Integer, :to_int)
    @pos = sysseek(offset, whence)
    return 0
  end

  def rewind
    self.pos = 0
  end

  def getbyte
    if !@buf.nil?
      b, @buf = @buf, nil
      return b
    elsif eof?
      return nil
    else
      b = sysread(1)[0].ord
      @pos ||= 0
      @pos += 1
      return b
    end
  rescue Errno::EINTR, Errno::EWOULDBLOCK, Errno::EAGAIN
    retry
  end

  def readbyte
    b = getbyte
    raise EOFError, "end of file reached" if b.nil?
    b
  end

  def each_byte
    return enum_for(:each_byte) unless block_given?
    while b = getbyte
      yield b
    end
  end

  def ungetbyte(b)
    case b
    when Integer
      raise TypeError, "must be in 0...256, but got #{b}" unless (0...256).include?(b)
      @buf = b

    when String
      @buf = b[0].ord

    else
      raise TypeError, "expected a byte or a string, but got #{b.class}"
    end
  end

  def nread
    return @buf.nil? ? 0 : 1
  end

  def readpartial(maxlen, outbuf = nil)
    outbuf ||= ""
    if !@buf.nil?
      return outbuf.replace(@buf.chr.force_encoding(Encoding::ASCII_8BIT))
    elsif eof?
      raise EOFError, "end of file reached"
    else
      return sysread(maxlen, outbuf)
    end
  rescue Errno::EINTR, Errno::EWOULDBLOCK, Errno::EAGAIN
    retry
  end
end
