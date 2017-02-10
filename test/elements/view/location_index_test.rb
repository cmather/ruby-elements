require "test_helper"
require "elements/view/lexer"

describe "Elements::View::LocationIndex" do
  describe "single line" do
    it "single advance" do
      location_index = Elements::View::LocationIndex.new
      input1 = "hello world"
      location = location_index.advance(input1)
      assert_instance_of Elements::View::Location, location, "location not returned"
      assert_equal 0, location.start.index, "wrong start index"
      assert_equal 0, location.start.column, "wrong start column"
      assert_equal 1, location.start.line, "wrong start line"
      assert_equal input1.size, location.finish.index, "wrong finish index"
      assert_equal input1.size, location.finish.column, "wrong finish column"
      assert_equal 1, location.finish.line, "wrong finish line"
    end

    it "multiple advances" do
      location_index = Elements::View::LocationIndex.new

      input1 = "hello world"
      location = location_index.advance(input1)
      assert_instance_of Elements::View::Location, location, "location not returned"
      assert_equal 0, location.start.index, "wrong start index"
      assert_equal 0, location.start.column, "wrong start column"
      assert_equal 1, location.start.line, "wrong start line"
      assert_equal input1.size, location.finish.index, "wrong finish index"
      assert_equal input1.size, location.finish.column, "wrong finish column"
      assert_equal 1, location.finish.line, "wrong finish line"

      input2 = "another world"
      location = location_index.advance(input2)
      assert_instance_of Elements::View::Location, location, "location not returned"
      assert_equal input1.size, location.start.index, "wrong start index"
      assert_equal input1.size, location.start.column, "wrong start column"
      assert_equal 1, location.start.line, "wrong start line"
      assert_equal input1.size + input2.size, location.finish.index, "wrong finish index"
      assert_equal input1.size + input2.size, location.finish.column, "wrong finish column"
      assert_equal 1, location.finish.line, "wrong finish line"
    end
  end

  describe "multiline" do
    it "newline at the beginning" do
      location_index = Elements::View::LocationIndex.new

      input1 = "\nhello"
      location = location_index.advance(input1)
      assert_instance_of Elements::View::Location, location, "location not returned"

      # start
      assert_equal 0, location.start.index, "wrong start index"
      assert_equal 0, location.start.column, "wrong start column"
      assert_equal 1, location.start.line, "wrong start line"

      # finish
      assert_equal input1.size, location.finish.index, "wrong finish index"
      assert_equal 5, location.finish.column, "wrong finish column"
      assert_equal 2, location.finish.line, "wrong finish line"
    end

    it "newline at the beginning and middle" do
      location_index = Elements::View::LocationIndex.new

      input1 = "\nhello\nworld"
      location = location_index.advance(input1)
      assert_instance_of Elements::View::Location, location, "location not returned"

      # start
      assert_equal 0, location.start.index, "wrong start index"
      assert_equal 0, location.start.column, "wrong start column"
      assert_equal 1, location.start.line, "wrong start line"

      # finish
      assert_equal input1.size, location.finish.index, "wrong finish index"
      assert_equal 5, location.finish.column, "wrong finish column"
      assert_equal 3, location.finish.line, "wrong finish line"
    end

    it "newline in middle" do
      location_index = Elements::View::LocationIndex.new

      input1 = "hello\nworld"
      location = location_index.advance(input1)
      assert_instance_of Elements::View::Location, location, "location not returned"

      # start
      assert_equal 0, location.start.index, "wrong start index"
      assert_equal 0, location.start.column, "wrong start column"
      assert_equal 1, location.start.line, "wrong start line"

      # finish
      assert_equal input1.size, location.finish.index, "wrong finish index"
      assert_equal 5, location.finish.column, "wrong finish column"
      assert_equal 2, location.finish.line, "wrong finish line"
    end

    it "newline at end" do
      location_index = Elements::View::LocationIndex.new

      input1 = "world\n"
      location = location_index.advance(input1)
      assert_instance_of Elements::View::Location, location, "location not returned"

      # start
      assert_equal 0, location.start.index, "wrong start index"
      assert_equal 0, location.start.column, "wrong start column"
      assert_equal 1, location.start.line, "wrong start line"

      # finish
      assert_equal input1.size, location.finish.index, "wrong finish index"
      assert_equal 0, location.finish.column, "wrong finish column"
      assert_equal 2, location.finish.line, "wrong finish line"
    end
  end
end
