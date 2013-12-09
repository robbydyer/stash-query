Gem::Specification.new do |s|
  s.name        = 'es-query'
  s.version     = '0.0.1'
  s.date        = '2013-12-05'
  s.summary     = "Gem for querying Logstash and running CDR reports"
  s.authors     = ["Robby Dyer"]
  s.email       = 'ops@tropo.com'
  s.files       = Dir[ "bin/*"] + Dir["etc/*"]
  s.executables <<  "es-query"
  s.add_runtime_dependency 'elasticsearch', '>=0.4.1'
  s.add_runtime_dependency 'curb', '>= 0.8.5'
  s.add_runtime_dependency 'progress_bar'
  s.add_runtime_dependency 'typhoeus'
  s.add_development_dependency "geminabox"
end
