#!/usr/bin/env gem build
# encoding: utf-8

require "base64"
require File.expand_path("../lib/cyme/version", __FILE__)

Gem::Specification.new do |s|
    s.name = "cyme"
    s.version = Cyme::VERSION.dup
    s.authors = ["Ask Solem"]
    s.email = [Base64.decode64("YXNrQGNlbGVyeXByb2plY3Qub3Jn\n")]
    s.homepage = "http://github.com/ask/cyme-ruby"
    s.summary = "Celery Instance Manager client for Ruby"
    s.description = s.summary

    # files
    s.files = `git ls-files`.split("\n").reject { |file|
        file =~ /^(?:vendor|gemfiles)\//
    }
    s.require_paths = ["lib"]
    s.extra_rdoc_files = ["README.textile"]

    # dependencies
    s.add_dependency "restclient"

    # RubyForge
    s.rubyforge_project = "cyme"
end
