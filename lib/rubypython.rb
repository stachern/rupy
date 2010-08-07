require 'rubypython/pyapi'
require 'rubypython/rubypyproxy'
require 'rubypython/blankobject'
require 'singleton'

if RUBY_VERSION == "1.8.6"
  class String
    #This is necessary for Ruby versions 1.8.6 and below as 
    #String#end_with? is not defined in this case.
    def end_with?(c)
      self[-1].chr == c
    end
  end
end


#This module provides the direct user interface for the RubyPython extension.
#
#The majority of the functionality lies in the {PyAPI} module, which intefaces
#to the Python C API using the Ruby FFI module. However, the end user should
#only worry about dealing with the RubyPython module as that is designed for
#user interaction.
#
#Usage
#-----
#It is important to remember that the Python Interpreter must be
#started before the bridge is functional.  This will start the embedded
#interpreter. If this approach is used, the user should remember to call
#RubyPython.stop when they are finished with Python.
#@example
#  RubyPython.start
#  cPickle = RubyPython.import "cPickle"
#  puts cPickle.dumps "RubyPython is awesome!"
#  RubyPython.stop
module RubyPython

  #Starts ups the Python interpreter. This method **must** be run
  #before using any Python code. The only alternatives are use of the
  #{session} and {run} methods.
  #@return [Boolean] returns true if the interpreter was started here
  #    and false otherwise
  def self.start
    PyAPI.start
  end

  #Stops the Python interpreter if it is running. Returns true if the
  #intepreter is stopped by this invocation. All wrapped Python objects
  #should be considered invalid after invocation of this method.
  #@return [Boolean] returns true if the interpreter was stopped here
  #    and false otherwise
  def self.stop
    PyMain.main = nil
    PyMain.builtin = nil
    PyAPI.stop
  end

  #Import a Python module into the interpreter and return a proxy object
  #for it. This is the preferred way to gain access to Python object.
  #@param [String] mod the name of the module to import
  #@return [PyAPI::RubyPyModule] pymod a proxy object wrapping the requested
  #module
  def self.import(mod)
    pymod = PyAPI.import(mod)
    if(PythonError.error?)
      raise PythonError.handle_error
    end
    PyAPI::RubyPyModule.new(pymod)
  end

  #Switch RubyPython into a mode compatible with versions < 0.3.0. All
  #Python objects returned by method invocations are automatically converted
  #to natve Ruby Types if RubyPython knows how to do this. Only if no such
  #conversion is known are the objects wrapped in proxy objects.
  #@return [void]
  def self.legacy_mode=(on_off)
    PyAPI.legacy_mode = on_off
  end

  #Set RubyPython to automatically wrap all returned objects as an instance
  #of {PyAPI::RubyPyProxy} or one of its subclasses.
  #@return [Boolean]
  def self.legacy_mode
    PyAPI.legacy_mode
  end

  #Execute the given block, starting the Python interperter before its execution
  #and stopping the interpreter after its execution. The last expression of the
  #block is returned; be careful that this is not a Python object as it will
  #become invalid when the interpreter is stopped.
  #@param [Block] block the code to be executed while the interpreter is running
  #@return the result of evaluating the given block
  def self.session
    start
    begin
      result = yield
    ensure
      stop
    end
    result
  end

  #The same as {session} except that the block is executed within the scope 
  #of the RubyPython module.
  def self.run(&block)
    start
    begin
      result = module_eval(&block)
    ensure
      stop
    end
    result
  end
end


# A singleton object providing access to the python \_\_main\_\_ and \_\_builtin\_\_ modules.
# This can be conveniently accessed through the already instaniated PyMain constant.
# The \_\_main\_\_ namespace is searched before the \_\_builtin\_\_ namespace. As such,
# naming clashes will be resolved in that order.
#
# == Block Syntax
# The PyMainClass object provides somewhat experimental block support.
# A block may be passed to a method call and the object returned by the function call
# will be passed as an argument to the block.
class PyMainClass < RubyPython::PyAPI::BlankObject
  include Singleton
  attr_writer :main, :builtin
  def main #:nodoc:
    @main||=RubyPython.import "__main__"
  end
  
  def builtin #:nodoc:
    @builtin||=RubyPython.import "__builtin__"
  end
  
  def method_missing(name,*args,&block) #:nodoc:
    begin
      result=main.__send__(name,*args)
    rescue NoMethodError
      begin
        result=builtin.__send__(name,*args)
      rescue NoMethodError
        super(name,*args)
      end
    end
    if(block)
      return block.call(result)
    end
    return result
  end
end

# See _PyMainClass_
PyMain=PyMainClass.instance
