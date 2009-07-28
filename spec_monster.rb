require 'parser'

describe StackMonster do
  include StackMonster::Combinators

  context "on a simple document" do
    def parse(s, &definition)
      parser = StackMonster::Parser.new(&definition)
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
      end.should raise_error(StackMonster::ParseError)
    end

    it "should parse text content" do
      r = parse("<p>Foobar</p>") {
        element("p") {
          text
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
      end.should raise_error(StackMonster::ParseError)
    end
  end
end
