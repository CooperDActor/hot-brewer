require "requirement"

class MinimumMacOSRequirement < Requirement
  fatal true

  def initialize(tags)
    @version = MacOS::Version.from_symbol(tags.first)
    super
  end

  satisfy(:build_env => false) { MacOS.version >= @version }

  def message
    "#{MacOS.os_name(@version)} #{@version.pretty_name} or newer is required."
  end
end
