= ioable

* http://github.com/yugui/ioable

== DESCRIPTION:

IOable helps you to implement IO-like class.
 
Sometimes you need to write a IO-like object, e.g. StringIO or a network
protocol wrapper. But IO has many methods to implement. So this library implies
those methods from a limited number of basic methods.

== FEATURES/PROBLEMS:

-- IOable
All-in-one module to define the methods.

-- IOable::CharInput
Wrapper class to define character-wise, line-wise and encoding-aware input
methods from byte-wide input methods.

-- IOable::CharOutput
Ditto, but for outputs.

== SYNOPSIS:

 require 'ioable'
 class YourCharacterStream
   include IOable

   def getc
     # ...
   end
   def syswrite(buf)
     # ...
   end
 end

== INSTALL:

 % gem install ioable

== LICENSE:

(The MIT License)

Copyright (c) 2010 FIXME full name

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
