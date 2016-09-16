class Hbc::CLI::Info < Hbc::CLI::Base
  def self.run(*args)
    cask_tokens = cask_tokens_from(args)
    raise Hbc::CaskUnspecifiedError if cask_tokens.empty?
    cask_tokens.each do |cask_token|
      odebug "Getting info for Cask #{cask_token}"
      cask = Hbc.load(cask_token)

      info(cask)
    end
  end

  def self.help
    "displays information about the given Cask"
  end

  def self.info(cask)
    puts "#{cask.token}: #{cask.version}"
    puts formatted_url(cask.homepage) if cask.homepage
    installation_info(cask)
    puts "From: #{formatted_url(repo_info(cask))}" if repo_info(cask)
    name_info(cask)
    artifact_info(cask)
    Hbc::Installer.print_caveats(cask)
  end

  def self.formatted_url(url)
    "#{Tty.em}#{url}#{Tty.reset}"
  end

  def self.installation_info(cask)
    if cask.installed?
      cask.versions.each do |version|
        versioned_staged_path = cask.caskroom_path.join(version)

        puts versioned_staged_path.to_s
          .concat(" (")
          .concat(versioned_staged_path.exist? ? versioned_staged_path.abv : "#{Tty.red}does not exist#{Tty.reset}")
          .concat(")")
      end
    else
      puts "Not installed"
    end
  end

  def self.name_info(cask)
    ohai cask.name.size > 1 ? "Names" : "Name"
    puts cask.name.empty? ? "#{Tty.red}None#{Tty.reset}" : cask.name
  end

  def self.repo_info(cask)
    user, repo, token = Hbc::QualifiedToken.parse(Hbc.all_tokens.detect { |t| t.split("/").last == cask.token })
    remote = Tap.fetch(user, repo).remote
    return "#{remote}/blob/master/Casks/#{token}.rb" if remote.include? "github.com"
    "#{remote}"
  end

  def self.artifact_info(cask)
    ohai "Artifacts"
    Hbc::DSL::ORDINARY_ARTIFACT_TYPES.each do |type|
      next if cask.artifacts[type].empty?
      cask.artifacts[type].each do |artifact|
        activatable_item = type == :stage_only ? "<none>" : artifact.first
        puts "#{activatable_item} (#{type})"
      end
    end
  end
end
