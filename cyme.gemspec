#!/usr/bin/env gem build
# encoding: utf-8

require "base64"
require File.expand_path("../lib/cyme/meta", __FILE__)

meta = Cyme::Meta.new()

Gem::Specification.new do |s|
    meta.contribute_to_spec(s)
end
