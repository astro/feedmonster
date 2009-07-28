require 'nokogiri'

module StackMonster
  class ParseError < RuntimeError; end

  class Parser
    def initialize(&definition)
      @listener = ParserListener.new(definition.call)
      @parser = Nokogiri::XML::SAX::PushParser.new @listener
    end
    def <<(s)
      @parser << s
    end
    def finish
      begin
        @parser.finish
      rescue Exception
        # We're not as picky
      end
    end
    def result
      @listener.result
    end
  end

  class ParserListener < Nokogiri::XML::SAX::Document
    def initialize(child=nil)
      @child = child
    end

    def result
      if @child
        @child.result
      else
        nil
      end
    end

    def event(m, *a)
      if @child
        @child.event m, *a
      end
    end

    def done?
      # Consume everything by default
      false
    end

    def start_element(name, attributes)
      event :start_element, name
      while attributes.size > 1
        k = attributes.shift
        v = attributes.shift
        event :attribute, k, v
      end
    end
    def end_element(name)
      event :end_element, name
    end
    def cdata_block(s)
      characters s
    end
    def characters(s)
      event :characters, s
    end
  end

  class Element < ParserListener
    def initialize(name, &continuation)
      @wanted_name = name
      @continuation = continuation
      # :waiting | :active | :done
      @state = :waiting
      @childstack = []
      super()
    end

    def event(m, *a)
      case @state
      when :waiting
        # Haven't yet seen myself
        case m
        when  :start_element
          name, = a
          if name != @wanted_name
            # That's not the expected name
            raise ParseError.new("Expected element #{@wanted_name}, got #{name}")
          else
            # Match!
            @state = :active
            @child = @continuation.call if @continuation
          end
        when :characters
          # ignore
        when :attributes
          # ignore
        when :end_element
          raise ParseError
        end
      when :active
        case m
        when :start_element
          name, = a
          @childstack << name
          # This goes to the child
          super
        when :end_element
          if @childstack.size > 0
            name, = a
            if (n = @childstack.pop) != name
              raise "Expected end of #{n}, got #{name}"
            end
            # This goes to the child
            super
          else
            # Ended myself
            @state = :done
          end
        else
          # This goes to the child
          super
        end
      when :done
        if m == :start_element
          raise ParseError.new("Did not expect a new element")
        else
          # Ignore
        end
      end
    end

    def done?
      @state == :done
    end
  end

  class Text < ParserListener
    attr_reader :result

    def initialize
      super(nil)
      @result = ""
    end

    def event(m, *a)
      if m == :characters
        @result += a[0]
      end
    end
  end

  class Attribute < ParserListener
    attr_reader :result

    def initialize(name)
      @name = name
      @result = nil
      @look = true
    end

    def event(m, *a)
      if @look && m == :attribute
        if a[0] == @name
          @result = a[1]
          @look = false
        end
      else
        # No attribute means we're done
        @look = false
      end
    end

    def done?
      not @look
    end
  end

  class Attributes < ParserListener
    attr_reader :result

    def initialize
      @result = {}
      @look = true
    end

    def event(m, *a)
      if @look && m == :attribute
        @result[a[0]] = a[1]
      else
        # No attribute means we're done
        @look = false
      end
    end

    def done?
      not @look
    end
  end

  class Many < ParserListener
    attr_reader :result

    def initialize(&continuation)
      @result = []
      @continuation = continuation
      @child = nil
    end

    def event(m, *a)
      @child = @continuation.call unless @child
      super
      if @child.done?
        @result << @child.result
        @child = nil
      end
    end
  end

  class Constraint < ParserListener
    def initialize(getter, expected, &continuation)
      @checked = false
      @child = getter.call
      @expected = expected
      @continuation = continuation
    end

    def event(m, *a)
      super

      if (not @checked) && @child.done?
        @checked = true
        match = if @expected.respond_to?(:call)
                  @expected.call(@child.result)
                else
                  @expected == @child.result
                end
        if match
          @child = @continuation ? @continuation.call : nil
        else
          raise ParseError.new("Constraint not matched")
        end
      end
    end

    def done?
      @checked && (@child.nil? || @child.done?)
    end
  end

  module Combinators

    # Expects element and ends with it
    def element(name, &continuation)
      Element.new(name, &continuation)
    end

    # Gets one attribute
    def attribute(name)
      Attribute.new(name)
    end

    def attributes
      Attributes.new
    end

    # Collects all text
    def text
      Text.new
    end

    # Array
    def many(&continuation)
      Many.new(&continuation)
    end

    def constraint(getter, checker, &continuation)
      Constraint.new(getter, checker, &continuation)
    end
  end
end
