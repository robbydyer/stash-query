Gem::Specification.new do |s|
  s.name        = 'stash-query'
  s.version     = '0.0.2'
  s.date        = '2013-12-05'
  s.summary     = "Gem for querying Logstash and exporting the results"
  s.authors     = ["Robby Dyer"]
  s.email       = 'robby.dyer@gmail.com'
  s.files       = Dir[ "bin/*"]
  s.executables <<  "stash-query"
  s.add_runtime_dependency 'elasticsearch', '>=0.4.1'
  s.add_runtime_dependency 'curb', '>= 0.8.5'
  s.add_runtime_dependency 'progress_bar'
  s.add_runtime_dependency 'typhoeus'
  s.add_development_dependency "geminabox"
end
