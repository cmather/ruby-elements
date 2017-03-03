module Elements
  module Assertions
    def assert_type(type, *args)
      args.each do |object|
        raise TypeError, "Expected #{object} to be of type #{type}." unless object.is_a?(type)
      end
    end

    def assert_in_types(types, value)
      raise TypeError.new("Got value of type '#{value.class}' but expected one of: [#{types.join(', ')}]") unless types.include?(value.class)
    end

    def assert_type_or_nil(type, *args)
      args.each do |object|
        raise TypeError, "Expected #{object} to be of type #{type}." unless object.is_a?(type) || object.nil?
      end
    end

    def assert_respond_to(method, *args)
      args.each do |object|
        raise TypeError, "Expected #{object} to respond to #{method}." unless object.respond_to?(method)
      end
    end
  end
end
