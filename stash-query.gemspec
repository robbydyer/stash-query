Gem::Specification.new do |s|
  s.name        = 'stash-query'
  s.version     = '0.1.0'
  s.date        = '2014-07-22'
  s.summary     = "Gem for querying Logstash and exporting the results"
  s.authors     = ["Robby Dyer"]
  s.email       = 'robby.dyer@gmail.com'
  s.licenses    = [ 'GPL-3.0' ]
  s.files       = Dir[ "bin/*"]
  s.executables <<  "stash-query"
  s.add_runtime_dependency 'elasticsearch', '>=1.0.1'
  s.add_runtime_dependency 'curb', '>= 0.8.5'
  s.add_runtime_dependency 'faraday', '= 0.8.8'
  s.add_runtime_dependency 'progress_bar'
  s.add_runtime_dependency 'typhoeus', '= 0.6.6'
  s.add_development_dependency "bundler"
  s.add_development_dependency "rake"
end
