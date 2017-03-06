$gem_path = File.expand_path("../../lib", __FILE__)
$LOAD_PATH.unshift($gem_path) unless $LOAD_PATH.include?($gem_path)

require "bundler/setup"
require "byebug"
require "minitest/autorun"
require "minitest/reporters"
require "active_support/core_ext/string"
require "elements/core"

Minitest::Reporters.use!([Minitest::Reporters::SpecReporter.new])

module Minitest
  class Spec
    def parse(source, opts = {})
      Elements::Template::Parser.parse(source, opts)
    end

    def parse_template(source, opts = {})
      Elements::Template::Parser.parse_template(source, opts)
    end

    def codegen(ast, opts = {})
      Elements::Template::CodeGen.generate(ast, opts)
    end

    def with_log(target, method, &callback)
      log = []
      orig = target.instance_method(method)
      target.class_eval do
        define_method(method) do |*args|
          log << { self: self, args: args }
          orig.bind(self).call(*args)
        end
      end

      yield log
    ensure
      target.class_eval { define_method(method, orig) }
    end

    def with_event_log(&callback)
      with_log(Elements::Core::Events::InstanceMethods, :trigger, &callback)
    end
  end
end
