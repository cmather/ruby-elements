module Elements
  module Assertions
    def assert_type(type, *args)
      args.each do |object|
        raise TypeError, "Expected #{object} to be of type #{type}." unless object.is_a?(type)
      end
    end

    def assert_type_or_nil(type, *args)
      args.each do |object|
        raise TypeError, "Expected #{object} to be of type #{type}." unless object.is_a?(type) || object.nil?
      end
    end
  end
end
