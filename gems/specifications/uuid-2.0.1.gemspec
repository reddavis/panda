Gem::Specification.new do |s|
  s.name = %q{uuid}
  s.version = "2.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Assaf Arkin", "Eric Hodel"]
  s.date = %q{2008-08-28}
  s.description = %q{UUID generator for producing universally unique identifiers based on RFC 4122 (http://www.ietf.org/rfc/rfc4122.txt).}
  s.email = %q{assaf@labnotes.org}
  s.extra_rdoc_files = ["README.rdoc", "MIT-LICENSE"]
  s.files = ["test/test-uuid.rb", "lib/uuid.rb", "README.rdoc", "MIT-LICENSE", "Rakefile", "CHANGELOG"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/assaf/uuid}
  s.rdoc_options = ["--main", "README.rdoc", "--title", "UUID generator", "--line-numbers"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{reliable-msg}
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{UUID generator}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if current_version >= 3 then
      s.add_runtime_dependency(%q<macaddr>, ["~> 1.0"])
    else
      s.add_dependency(%q<macaddr>, ["~> 1.0"])
    end
  else
    s.add_dependency(%q<macaddr>, ["~> 1.0"])
  end
end
