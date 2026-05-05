# -*- encoding: utf-8 -*-
# stub: down 5.6.0 ruby lib

Gem::Specification.new do |s|
  s.name = "down".freeze
  s.version = "5.6.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Janko Marohni\u0107".freeze]
  s.date = "1980-01-02"
  s.email = ["janko.marohnic@gmail.com".freeze]
  s.homepage = "https://github.com/janko/down".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "4.0.3".freeze
  s.summary = "Robust streaming downloads using Net::HTTP, http.rb or HTTPX.".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<addressable>.freeze, ["~> 2.8".freeze])
  s.add_runtime_dependency(%q<base64>.freeze, ["~> 0.3".freeze])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 6.0".freeze])
  s.add_development_dependency(%q<mocha>.freeze, ["~> 1.5".freeze])
  s.add_development_dependency(%q<cgi>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<httpx>.freeze, ["~> 1.0".freeze, "< 1.4.4".freeze])
  s.add_development_dependency(%q<http>.freeze, ["~> 6.0".freeze])
  s.add_development_dependency(%q<warning>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<csv>.freeze, [">= 0".freeze])
end
