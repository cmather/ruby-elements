$gem_path = File.expand_path("../../lib", __FILE__)
$LOAD_PATH.unshift($gem_path) unless $LOAD_PATH.include?($gem_path)

require "bundler/setup"
require "byebug"
require "minitest/autorun"
require "minitest/reporters"

Minitest::Reporters.use!([Minitest::Reporters::SpecReporter.new])
