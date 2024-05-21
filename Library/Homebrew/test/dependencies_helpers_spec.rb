# frozen_string_literal: true

require "dependencies_helpers"

RSpec.describe DependenciesHelpers do
  let(:default_includes) { [:required?, :recommended?] }
  let(:includes_with_build) { default_includes + [:build?] }

  describe "#args_includes_ignores" do
    include described_class

    let(:args) { Homebrew::CLI::Args.new }

    it "returns default includes when no extra args are provided" do
      expect(args_includes_ignores(args)).to eq [default_includes, [], []]
    end

    it "returns includes and ignores matching the provided args" do
      args[:include_build?] = true
      args[:skip_recommended?] = true
      args[:direct_build?] = true
      expect(args_includes_ignores(args)).to eq [includes_with_build, [:recommended?], [:build?]]
    end
  end

  describe "#recursive_includes" do
    include described_class

    let(:dependency_formulae) do
      deps = (0..7).map do |i|
        formula "f#{i}" do
          url "f#{i}-1.0"
        end
      end
      deps << formula("d1") do
        url "d1-1.0"
        depends_on "f0" => :build
        depends_on "f1" => :test
        depends_on "f2"
      end
      deps << formula("d2") do
        url "d2-1.0"
        depends_on "f3" => :build
        depends_on "f4"
      end
      deps << formula("d3") do
        url "d3-1.0"
        depends_on "f5" => :test
        depends_on "f6"
      end
      deps
    end

    let(:test_formula) do
      formula("test_formula") do
        url "test_formula-1.0"
        depends_on "d1" => :build
        depends_on "d2" => [:recommended, :test]
        depends_on "d3"
        depends_on "f7"
      end
    end

    before do
      dependency_formulae.each { |f| stub_formula_loader f }
      stub_formula_loader test_formula
    end

    it "returns an empty array when provided empty `includes`" do
      expect(recursive_includes(Dependency, test_formula, [], [])).to eq []
    end

    it "selects required and recommended dependencies using `includes`" do
      deps = recursive_includes(Dependency, test_formula, default_includes, [])
      expect(deps.map(&:name).sort).to eq %w[d2 d3 f4 f6 f7]
    end

    it "selects required, recommended and build dependencies using `includes`" do
      deps = recursive_includes(Dependency, test_formula, includes_with_build, [])
      expect(deps.map(&:name).sort).to eq %w[d1 d2 d3 f0 f2 f3 f4 f6 f7]
    end

    it "does not select recommended dependencies when recommended is in both `includes` and `ignores`" do
      deps = recursive_includes(Dependency, test_formula, default_includes, [:recommended?])
      expect(deps.map(&:name).sort).to eq %w[d3 f6 f7]
    end

    it "does not return any dependency in `skip`" do
      deps = recursive_includes(Dependency, test_formula, default_includes, [], skip: %w[d2 f6])
      expect(deps.map(&:name).sort).to eq %w[d3 f7]
    end

    it "can ignore recursive build dependencies using `recursive_ignores`" do
      deps = recursive_includes(Dependency, test_formula, includes_with_build, [], recursive_ignores: [:build?])
      expect(deps.map(&:name).sort).to eq %w[d1 d2 d3 f2 f4 f6 f7]
    end
  end

  describe "#select_includes" do
    include described_class

    let(:runtime_dep) { Dependency.new("runtime_dep") }
    let(:optional_dep) { Dependency.new("optional_dep", [:optional]) }
    let(:build_dep) { Dependency.new("build_dep", [:build]) }
    let(:recommended_dep) { Dependency.new("recommended_dep", [:recommended]) }
    let(:build_test_dep) { Dependency.new("build_test_dep", [:build, :test]) }
    let(:build_recommended_dep) { Dependency.new("build_recommended_dep", [:build, :recommended]) }
    let(:dependables) do
      [runtime_dep, optional_dep, build_dep, recommended_dep, build_test_dep, build_recommended_dep]
    end

    it "returns an empty array when provided empty `includes`" do
      expect(select_includes(dependables, [], [])).to eq []
    end

    it "selects required and recommended dependencies using `includes`" do
      expect(select_includes(dependables, [], default_includes))
        .to eq [runtime_dep, recommended_dep, build_recommended_dep]
    end

    it "selects required, recommended and build dependencies using `includes`" do
      expect(select_includes(dependables, [], includes_with_build))
        .to eq [runtime_dep, build_dep, recommended_dep, build_test_dep, build_recommended_dep]
    end

    it "does not select recommended dependencies when recommended is in both `includes` and `ignores`" do
      expect(select_includes(dependables, [:recommended?], default_includes)).to eq [runtime_dep]
    end

    it "does not return any dependency in `skip`" do
      expect(select_includes(dependables, [], includes_with_build, skip: ["runtime_dep", "build_test_dep"]))
        .to eq [build_dep, recommended_dep, build_recommended_dep]
    end
  end

  specify "#dependents" do
    foo = formula "foo" do
      url "foo"
      version "1.0"
    end

    foo_cask = Cask::CaskLoader.load(+<<-RUBY)
      cask "foo_cask" do
      end
    RUBY

    bar = formula "bar" do
      url "bar-url"
      version "1.0"
    end

    bar_cask = Cask::CaskLoader.load(+<<-RUBY)
      cask "bar-cask" do
      end
    RUBY

    methods = [
      :name,
      :full_name,
      :runtime_dependencies,
      :deps,
      :requirements,
      :recursive_dependencies,
      :recursive_requirements,
      :any_version_installed?,
    ]

    dependents = described_class.dependents([foo, foo_cask, bar, bar_cask])

    dependents.each do |dependent|
      methods.each do |method|
        expect(dependent.respond_to?(method))
          .to be true
      end
    end
  end
end
