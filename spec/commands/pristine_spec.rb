# frozen_string_literal: true
require "fileutils"

RSpec.describe "bundle pristine" do
  before :each do
    build_lib "baz", :path => bundled_app do |s|
      s.version = "1.0.0"
      s.add_development_dependency "baz-dev", "=1.0.0"
    end

    build_repo2 do
      build_gem "weakling"
      build_gem "baz-dev", "1.0.0"
      build_git "foo", :path => lib_path("foo")
      build_lib "bar", :path => lib_path("bar")
    end

    install_gemfile! <<-G
      source "file://#{gem_repo2}"
      gem "weakling"
      gem "foo", :git => "#{lib_path("foo")}"
      gem "bar", :path => "#{lib_path("bar")}"

      gemspec
    G
  end

  context "when sourced from RubyGems" do
    it "reverts using cached .gem file" do
      spec = Bundler.definition.specs["weakling"].first
      changes_txt = Pathname.new(spec.full_gem_path).join("lib/changes.txt")

      FileUtils.touch(changes_txt)
      expect(changes_txt).to be_file

      bundle "pristine"
      expect(changes_txt).to_not be_file
    end

    it "does not delete the bundler gem" do
      system_gems :bundler
      bundle! "install"
      bundle! "pristine", :system_bundler => true
      bundle! "-v", :system_bundler => true
      expect(out).to end_with(Bundler::VERSION)
    end
  end

  context "when sourced from git repo" do
    it "reverts by resetting to current revision`" do
      spec = Bundler.definition.specs["foo"].first
      changed_file = Pathname.new(spec.full_gem_path).join("lib/foo.rb")
      diff = "#Pristine spec changes"

      File.open(changed_file, "a") {|f| f.puts "#Pristine spec changes" }
      expect(File.read(changed_file)).to include(diff)

      bundle "pristine"
      expect(File.read(changed_file)).to_not include(diff)
    end
  end

  context "when sourced from gemspec" do
    it "displays warning and ignores changes when sourced from gemspec" do
      spec = Bundler.definition.specs["baz"].first
      changed_file = Pathname.new(spec.full_gem_path).join("lib/baz.rb")
      diff = "#Pristine spec changes"

      File.open(changed_file, "a") {|f| f.puts "#Pristine spec changes" }
      expect(File.read(changed_file)).to include(diff)

      bundle "pristine"
      expect(File.read(changed_file)).to include(diff)
      expect(out).to include("Cannot pristine #{spec.name} (#{spec.version}#{spec.git_version}). Gem is sourced from local path.")
    end

    it "reinstall gemspec dependency" do
      spec = Bundler.definition.specs["baz-dev"].first
      changed_file = Pathname.new(spec.full_gem_path).join("lib/baz-dev.rb")
      diff = "#Pristine spec changes"

      File.open(changed_file, "a") {|f| f.puts "#Pristine spec changes" }
      expect(File.read(changed_file)).to include(diff)

      bundle "pristine"
      expect(File.read(changed_file)).to_not include(diff)
    end
  end

  context "when sourced from path" do
    it "displays warning and ignores changes when sourced from local path" do
      spec = Bundler.definition.specs["bar"].first
      changes_txt = Pathname.new(spec.full_gem_path).join("lib/changes.txt")
      FileUtils.touch(changes_txt)
      expect(changes_txt).to be_file
      bundle "pristine"
      expect(out).to include("Cannot pristine #{spec.name} (#{spec.version}#{spec.git_version}). Gem is sourced from local path.")
      expect(changes_txt).to be_file
    end
  end
end
