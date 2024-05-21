# typed: true
# frozen_string_literal: true

require "cask_dependent"

# Helper functions for dependencies.
module DependenciesHelpers
  def args_includes_ignores(args)
    includes = [:required?, :recommended?] # included by default
    includes << :build? if args.include_build?
    includes << :test? if args.include_test?
    includes << :optional? if args.include_optional?

    ignores = []
    ignores << :recommended? if args.skip_recommended?
    ignores << :satisfied? if args.missing?

    recursive_ignores = []
    recursive_ignores << :build? if args.respond_to?(:direct_build?) && args.direct_build?
    recursive_ignores << :test? if args.respond_to?(:direct_test?) && args.direct_test?

    [includes, ignores, recursive_ignores]
  end

  def recursive_includes(klass, root_dependent, includes, ignores, recursive_ignores: nil, skip: nil)
    raise ArgumentError, "Invalid class argument: #{klass}" if klass != Dependency && klass != Requirement

    cache_key = "recursive_includes_#{includes}_#{ignores}"
    cache_key = "#{cache_key}_#{recursive_ignores}" if recursive_ignores.present?
    cache_key = "#{cache_key}_#{skip}" if skip.present?
    recursive_ignores = Array(recursive_ignores)
    # Ignore indirect test dependencies
    recursive_ignores << :test? if recursive_ignores.exclude?(:test?)

    klass.expand(root_dependent, cache_key:) do |dependent, dep|
      klass.prune if skip&.include?(dep.name)
      klass.prune if ignores.any? { |ignore| dep.public_send(ignore) }
      klass.prune if includes.none? do |include|
        next if recursive_ignores.include?(include) && dependent != root_dependent

        dep.public_send(include)
      end

      # If a tap isn't installed, we can't find the dependencies of one of
      # its formulae and an exception will be thrown if we try.
      Dependency.keep_but_prune_recursive_deps if klass == Dependency && dep.tap && !dep.tap.installed?
    end
  end

  def select_includes(dependables, ignores, includes, skip: nil)
    dependables.select do |dep|
      next false if skip&.include?(dep.name)
      next false if ignores.any? { |ignore| dep.public_send(ignore) }

      includes.any? { |include| dep.public_send(include) }
    end
  end

  def dependents(formulae_or_casks)
    formulae_or_casks.map do |formula_or_cask|
      if formula_or_cask.is_a?(Formula)
        formula_or_cask
      else
        CaskDependent.new(formula_or_cask)
      end
    end
  end
  module_function :dependents
end
