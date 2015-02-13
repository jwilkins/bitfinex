Gem::Specification.new do |s|
  s.name        = 'bitfinex'
  s.version     = '0.1.4'
  s.licenses    = ['GPLv2']
  s.summary     = "Bitfinex.com Bitcoin Exchange API"
  s.description = "v1 API library"
  s.authors     = ["Jonathan Wilkins", "Oleh Aldekein"]
  s.email       = 'jwilkins@bitland.net'
  s.files       = ["lib/bitfinex.rb"]
  s.homepage    = 'https://rubygems.org/gems/bitfinex'

#  s.executables = ['timed_tx']
  s.test_files    = %w(test/knock.rb test/test-auth.rb test/test-unauth.rb)
  s.add_dependency             'hashie'
  s.add_dependency             'colored'
  s.add_dependency             'pusher-client'
  s.add_dependency             'chronic'
  s.add_dependency             'httparty'

  s.add_development_dependency 'byebug'
end
