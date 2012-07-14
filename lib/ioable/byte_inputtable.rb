#-*- encoding: US-ASCII -*-
require 'enumerator'

module IOable; end

module IOable::CommonIOable
  # Always returns false. The subclass overrides this if necessary.
  def auto_close?
    false
  end

  # Ignores the given value. The subcless overrides this if necessary.
  def auto_close=(value)
    # Do nothing.
  end

  # Always returns false. The subclass overrides this if necessary.
  def close_on_exec?
    false
  end

  # Ignores the given value. The subcless overrides this if necessary.
  def close_on_exec=(value)
    # Do nothing.
  end

  # Does nothing by default. The subclass overrides this if necessary.
  def close
    # Do nothing.
  end

  # Always returns false. The subclass overrides this if necessary.
  def closed?
    return false
  end

  def eof
    eof?
  end

  def fcntl(cmd, arg = 0) end
  def ioctl(cmd, arg = 0) end
  def isatty; false end
  alias tty? isatty
  def pid; nil end
end

module IOable::CommonInputtable
  include IOable::CommonIOable
  alias close_read close
end

tellable = Module.new do
  def pos
    @pos ||= 0
  end

  alias tell pos
end

IOable::Seekable = Module.new do
  include tellable
  def pos=(value)
    seek(value, IO::SEEK_SET)
    @pos = value
  end

  def rewind
    self.pos = 0
  end
end

IOable::NonSeekable = Module.new do
  include tellable
  def pos=(value)
    raise Errno::ESPIPE, 'Illegal seek'
  end
  def rewind
    raise Errno::ESPIPE, 'Illegal seek'
  end
  def seek(pos, offset)
    raise Errno::ESPIPE, 'Illegal seek'
  end
end

# Provides higher level byte-wide input methods to IO-like classes.
# Classes which includes this module must define at least the following methods:
# * seek
# * sysread
IOable::ByteInputtable = Module.new do
  include IOable::CommonInputtable
  include tellable

  def pos
    @pos ||= 0
  end
  alias tell pos

  def getbyte
    if eof?
      return nil
    else
      b = sysread(1)[0].ord
      @pos ||= 0
      @pos += 1
      return b
    end
  rescue Errno::EAGAIN
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
end
