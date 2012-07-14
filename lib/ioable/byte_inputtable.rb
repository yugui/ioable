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

  def fcntl(cmd, arg = 0)
    raise NotimplementedError
  end
  def ioctl(cmd, arg = 0)
    raise NotimplementedError
  end
  def isatty; false end
  alias tty? isatty
  def pid; nil end
  def fileno; nil end

  def fdatasync; nil end
  def fsync; nil end
  def sync; nil end
  def sync=(value); end

  def reopen(*args)
    raise NotimplementedError
  end

  def to_io
    self
  end
end

module IOable::CommonInputtable
  include IOable::CommonIOable
  alias close_read close
end

# Provides higher level byte-wide input methods to IO-like classes.
# Classes which includes this module must define at least the following methods:
# * sysseek
# * sysread
# * eof?
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
end
