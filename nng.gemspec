# frozen_string_literal: true

require_relative 'lib/nng/version'

Gem::Specification.new do |s|
  s.name        = 'nng'
  s.version     = NNG::VERSION
  s.authors     = ['Adib Saad']
  s.email       = ['adib.saad@gmail.com']
  s.licenses    = ['MIT']
  s.summary     = 'Ruby bindings for nng (nanomsg-ng).'
  s.description = 'Native C extension providing Ruby bindings for nng ' \
                  '(nanomsg next generation), a lightweight broker-less ' \
                  'messaging library. Supports all scalability protocols, ' \
                  'TLS transport, and async I/O.'
  s.homepage    = 'https://github.com/adibsaad/rbnng'

  s.metadata = {
    'source_code_uri'   => 'https://github.com/adibsaad/rbnng',
    'changelog_uri'     => 'https://github.com/adibsaad/rbnng/blob/main/CHANGELOG.md',
    'bug_tracker_uri'   => 'https://github.com/adibsaad/rbnng/issues',
    'rubygems_mfa_required' => 'true'
  }

  s.required_ruby_version = '>= 3.2'
  s.files       = Dir['ext/**/*.{c,h,rb}', 'lib/**/*.rb', 'CHANGELOG.md', 'LICENSE', 'README.md']
  s.extensions  = ['ext/rbnng/extconf.rb']
  s.require_paths = ['lib']
end
