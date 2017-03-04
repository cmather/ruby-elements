$gem_path = File.expand_path("../../lib", __FILE__)
$LOAD_PATH.unshift($gem_path) unless $LOAD_PATH.include?($gem_path)

require "bundler/setup"
require "byebug"
require "minitest/autorun"
require "minitest/reporters"
require "elements/template/parser"
require "elements/template/code_gen"
require "active_support/core_ext/string"

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
  end
end
