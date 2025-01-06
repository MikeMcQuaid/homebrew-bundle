# frozen_string_literal: true

require "English"

module Bundle
  class << self
    def system(cmd, *args, verbose: false)
      return super cmd, *args if verbose

      logs = []
      success = nil
      IO.popen([cmd, *args], err: [:child, :out]) do |pipe|
        while (buf = pipe.gets)
          logs << buf
        end
        Process.wait(pipe.pid)
        success = $CHILD_STATUS.success?
        pipe.close
      end
      puts logs.join unless success
      success
    end

    def brew(*args, verbose: false)
      system(HOMEBREW_BREW_FILE, *args, verbose:)
    end

    def mas_installed?
      @mas_installed ||= which_formula("mas")
    end

    def vscode_installed?
      @vscode_installed ||= which("code").present?
    end

    def whalebrew_installed?
      @whalebrew_installed ||= which_formula("whalebrew")
    end

    def cask_installed?
      @cask_installed ||= File.directory?("#{HOMEBREW_PREFIX}/Caskroom") &&
                          (File.directory?("#{HOMEBREW_LIBRARY}/Taps/homebrew/homebrew-cask") ||
                           !Homebrew::EnvConfig.no_install_from_api?)
    end

    def services_installed?
      @services_installed ||= which("services.rb").present?
    end

    def which_formula(name)
      formula = Formulary.factory(name)
      ENV["PATH"] = "#{formula.opt_bin}:#{ENV.fetch("PATH", nil)}" if formula.any_version_installed?
      which(name).present?
    end

    def exchange_uid_if_needed!(&block)
      euid = Process.euid
      uid = Process.uid
      return yield if euid == uid

      old_euid = euid
      process_reexchangeable = Process::UID.re_exchangeable?
      if process_reexchangeable
        Process::UID.re_exchange
      else
        Process::Sys.seteuid(uid)
      end

      return_value = with_env("HOME" => Etc.getpwuid(Process.uid).dir, &block)

      if process_reexchangeable
        Process::UID.re_exchange
      else
        Process::Sys.seteuid(old_euid)
      end

      return_value
    end
  end
end

require "bundle/extend/os/bundle"
