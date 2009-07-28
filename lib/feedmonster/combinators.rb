require 'feedmonster/consumer'
require 'feedmonster/parse_error'

module FeedMonster
  module Combinators

    class Anything < SAXConsumer
      def initialize(&continuation)
        @consumed = false
        @child = continuation ? continuation.call : nil
      end

      def event(m, *a)
        if @consumed
          super
        else
          @consumed = true
        end
      end

      def result
        @child ? @child.result : nil
      end

      def done?
        @consumed && @child.done?
      end
    end

    class Element < SAXConsumer
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

    class Text < SAXConsumer
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

    class Attribute < SAXConsumer
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

    class Attributes < SAXConsumer
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

    class Many < SAXConsumer
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

    class Constraint < SAXConsumer
      def initialize(getter, expected, &continuation)
        super(getter.call)
        @checked = false
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

    class OneOf < SAXConsumer
      def initialize(children)
        @children = children
      end

      def event(m, *a)
        @children.delete_if do |child|
          begin
            child.event m, *a
            false
          rescue ParseError
            true
          end
        end

        if @children.empty?
          raise ParseError.new('No alternatives left')
        end
      end

      def done?
        @children.any? do |child|
          child.done?
        end
      end

      def result
        @children[0].result
      end
    end

    class Lift < SAXConsumer
      def initialize(child, &lifter)
        super(child)
        @lifter = lifter
      end

      def done?
        @child.done?
      end

      def result
        @lifter.call(@child.result)
      end
    end

    # Consume anything and be done
    def anything(&continuation)
      Anything.new(&continuation)
    end

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

    def one_of(children)
      OneOf.new(children)
    end

    def constraint(getter, checker, &continuation)
      Constraint.new(getter, checker, &continuation)
    end

    def lift(child, &lifter)
      Lift.new(child, &lifter)
    end
  end
end
