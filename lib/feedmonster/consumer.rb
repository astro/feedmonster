module FeedMonster
  class SAXConsumer < Nokogiri::XML::SAX::Document
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
end
