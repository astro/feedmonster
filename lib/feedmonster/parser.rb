require 'nokogiri'

module FeedMonster
  class Parser
    def initialize(&definition)
      @listener = SAXConsumer.new(definition.call)
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
end
