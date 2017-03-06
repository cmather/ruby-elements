module Elements
  module Core
    module Utils
      def camelize(str)
        str.split(/_|-|\.|\//).map(&:capitalize).join
      end
    end
  end
end
