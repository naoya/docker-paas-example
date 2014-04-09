#!/usr/bin/env ruby

require 'yaml'

release = YAML.load_file(ARGV[0])
ENV['PORT'] = "8080"

exec release["default_process_types"]["web"]
