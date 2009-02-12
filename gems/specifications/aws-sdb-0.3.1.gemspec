Gem::Specification.new do |s|
  s.name = %q{aws-sdb}
  s.version = "0.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Tim Dysinger"]
  s.date = %q{2008-08-01}
  s.description = %q{Amazon SDB API}
  s.email = %q{tim@dysinger.net}
  s.extra_rdoc_files = ["README", "LICENSE"]
  s.files = ["LICENSE", "README", "Rakefile", "lib/aws_sdb", "lib/aws_sdb/error.rb", "lib/aws_sdb/service.rb", "lib/aws_sdb.rb", "spec/aws_sdb", "spec/aws_sdb/service_spec.rb", "spec/spec_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://aws-sdb.rubyforge.org}
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{aws-sdb}
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{Amazon SDB API}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if current_version >= 3 then
      s.add_runtime_dependency(%q<uuidtools>, [">= 0"])
    else
      s.add_dependency(%q<uuidtools>, [">= 0"])
    end
  else
    s.add_dependency(%q<uuidtools>, [">= 0"])
  end
end
