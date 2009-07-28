$: << File.dirname(__FILE__) + '/../lib'
require 'feedmonster/parser'
require 'feedmonster/combinators'

describe FeedMonster do
  include FeedMonster::Combinators

  context "on simple documents" do
    def parse(s, &definition)
      parser = FeedMonster::Parser.new(&definition)
      parser << s
      parser.finish
      parser.result
    end

    it "should parse an element" do
      r = parse("<p/>") {
        element "p"
      }
      r.should be_nil
    end

    it "should not parse the wrong element" do
      lambda do
        parse("<x/>") {
          element "p"
        }
      end.should raise_error(FeedMonster::ParseError)
    end

    it "should parse text content" do
      r = parse("<p>Foobar</p>") {
        element("p") {
          text
        }
      }
      r.should == "Foobar"
    end

    it "should not parse beyond element bounds" do
      r = parse("<body><p>Foobar</p>baz</body>") {
        element("body") {
          element("p") {
            text
          }
        }
      }
      r.should == "Foobar"
    end

    it "should parse incomplete documents" do
      r = parse("<p>Foobar</") {
        element("p") {
          text
        }
      }
      r.should == "Foobar"
    end

    it "should parse element lists" do
      r = parse("<body><p>One</p><p>Two</p><p>Three</p></body>") {
        element("body") {
          many {
            element("p") {
              text
            }
          }
        }
      }
      r.should == ["One", "Two", "Three"]
    end

    it "should parse attribute content" do
      r = parse("<p id='toto'>Foobar</p>") {
        element("p") {
          attribute "id"
        }
      }
      r.should == "toto"
    end

    it "should parse all attributes" do
      r = parse("<p id='toto' class='head'>Foobar</p>") {
        element("p") {
          attributes
        }
      }
      r['id'].should == 'toto'
      r['class'].should == 'head'
    end

    it "should accept constraints" do
      parse("<p class='head'>x</p>") {
        element("p") {
          constraint(lambda { attribute("class") },
                     "head")
        }
      }
    end
    it "should deny unsatisfied constraints" do
      lambda do
        parse("<p class='foot'>x</p>") {
          element("p") {
            constraint(lambda { attribute("class") },
                       "head")
          }
        }
      end.should raise_error(FeedMonster::ParseError)
    end

    it "should choose the right content" do
      def parse1(s)
        parse(s) {
          element("body") {
            one_of [
                    element("p") { text },
                    element("img") { attribute "src" }
                   ]
          }
        }
      end
      parse1("<body><img src='foo.jpg'/></body>").should == 'foo.jpg'
      parse1("<body><p>Foobar</p></body>").should == 'Foobar'
    end

    it "should lift result values" do
      r = parse("<p>Foobar</p>") {
        element("p") {
          lift(text) { |s| {:text => s} }
        }
      }
      r.should == {:text => "Foobar"}
    end

    it "should ignore anything" do
      r = parse("<body><img src='foo.jpg'/><p>Bar</p>") {
        element("body") {
          anything {      # <img>
            anything {    # src='foo.jpg'
              anything {  # </img>
                element("p") { text }
              }
            }
          }
        }
      }
      r.should == "Bar"
    end
  end
end
