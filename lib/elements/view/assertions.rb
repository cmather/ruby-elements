module Elements
  module View
    module Assertions
      def assert_type(type, *args)
        args.each do |object|
          raise TypeError, "Expected #{object} to be of type #{type}." unless object.is_a?(type)
        end
      end
    end
  end
end
