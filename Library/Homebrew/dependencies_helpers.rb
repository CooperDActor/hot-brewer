# typed: true
# frozen_string_literal: true

require "cask_dependent"

# Helper functions for dependencies.
#
# @api private
module DependenciesHelpers
  def args_includes_ignores(args)
    includes = []
    ignores = []

    if args.include_build?
      includes << "build?"
    else
      ignores << "build?"
    end

    if args.include_test?
      includes << "test?"
    else
      ignores << "test?"
    end

    if args.include_optional?
      includes << "optional?"
    else
      ignores << "optional?"
    end

    ignores << "recommended?" if args.skip_recommended?

    [includes, ignores]
  end

  def recursive_includes(
    klass,
    root_dependent,
    includes,
    ignores,
    used_formulae = [],
    skip_recursive_build_dependents: false
  )
    raise ArgumentError, "Invalid class argument: #{klass}" if klass != Dependency && klass != Requirement

    cache_key = +"recursive_includes_#{includes.join("_")}_#{ignores.join("_")}"
    cache_key << "_#{root_dependent}" if includes.include?("test?")
    cache_key << "_#{root_dependent}_no_recursive_build_#{used_formulae.join("_")}" if skip_recursive_build_dependents
    cache_key.freeze

    klass.expand(root_dependent, cache_key: cache_key) do |dependent, dep|
      if dep.recommended?
        klass.prune if ignores.include?("recommended?") || dependent.build.without?(dep)
      elsif dep.optional?
        klass.prune if includes.exclude?("optional?") && !dependent.build.with?(dep)
      elsif dep.build? || dep.test?
        keep = false
        keep ||= dep.test? && includes.include?("test?") && dependent == root_dependent
        keep ||= dep.build? && includes.include?("build?")
        klass.prune unless keep

        next unless skip_recursive_build_dependents
        next unless dep.build?
        next if dependent == root_dependent && used_formulae.include?(dep.to_formula)

        klass.prune
      end

      # If a tap isn't installed, we can't find the dependencies of one of
      # its formulae, and an exception will be thrown if we try.
      if klass == Dependency &&
         dep.is_a?(TapDependency) &&
         !dep.tap.installed?
        Dependency.keep_but_prune_recursive_deps
      end
    end
  end

  def reject_ignores(dependables, ignores, includes)
    dependables.reject do |dep|
      next false unless ignores.any? { |ignore| dep.send(ignore) }

      includes.none? { |include| dep.send(include) }
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
