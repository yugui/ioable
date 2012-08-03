#-*- encoding: US-ASCII -*-
module IOable; end

module IOable::CommonIOable
  # Does nothing. The subclass overrides this if necessary.
  def advise(advice, offset = 0, len = 0)
    # Do nothing.
  end

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

  # Always returns nil. The subclass overrides this if necessary.
  def fileno; nil end
  alias to_i fileno

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

