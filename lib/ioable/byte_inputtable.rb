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
#
# And optionally it is recommended to override the following methods if possible:
# #nread::
#   Override this according to your #sysread implementation for providing better information.
# #read_nonblock::
#   Override if your input can be non blockable. The default impelementation of
#   IOable::ByteInputtable#read_nonblock DOES BLOCK.
#
# This module does not provide #ungetbyte. You need to wrap your input with BufferedInput.
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
    if eof?
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

  def nread
    return 0
  end

  def readpartial(maxlen, outbuf = nil)
    outbuf ||= ""
    if eof?
      raise EOFError, "end of file reached"
    else
      return sysread(maxlen, outbuf)
    end
  rescue Errno::EINTR, Errno::EWOULDBLOCK, Errno::EAGAIN
    retry
  end

  def read_nonblock(maxlen, outbuf = nil)
    sysread(*[maxlen, outbuf].compact)
  end
end
