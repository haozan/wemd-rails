# -*- encoding: utf-8 -*-
# stub: omniauth-twitter2 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "omniauth-twitter2".freeze
  s.version = "1.0.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/unasuke/omniauth-twitter2/blob/main/CHANGELOG.md", "homepage_uri" => "https://github.com/unasuke/omniauth-twitter2", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/unasuke/omniauth-twitter2" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Yusuke Nakamura".freeze]
  s.bindir = "exe".freeze
  s.date = "2025-08-02"
  s.description = "Twitter OAuth2 strategy for OmniAuth. '2' means OAuth 2.0.".freeze
  s.email = ["yusuke1994525@gmail.com".freeze]
  s.homepage = "https://github.com/unasuke/omniauth-twitter2".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.6.0".freeze)
  s.rubygems_version = "3.6.2".freeze
  s.summary = "Twitter OAuth2 strategy for OmniAuth".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<omniauth>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<omniauth-oauth2>.freeze, ["~> 1.0".freeze])
end
