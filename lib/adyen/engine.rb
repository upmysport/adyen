module Adyen
  class Engine < ::Rails::Engine
    isolate_namespace Adyen
  end

  class EngineConfiguration
    attr_reader :http_username, :http_password, :disable_basic_auth

    def initialize(http_username, http_password, configurator)
      @http_username = http_username
      @http_password = http_password
      @disable_basic_auth = configurator.disable_basic_auth
    end
  end

  # Used to interpret the config run against the engine, and prevents on the fly
  # reconfiguration of things that should not be reconfigured
  class Configurator
    attr_accessor :http_username, :http_password, :disable_basic_auth

    def initialize(&block)
      @disable_basic_auth = false
      raise ConfigMissing.new unless block
      yield self
    end
  end

  class ConfigMissing < Exception
    def message
      'You have not passed a block to the Adyen#setup method!'
    end
  end

  def self.setup(&block)
    config = Configurator.new &block
    @config = EngineConfiguration.new(config.http_username, config.http_password, config)
  end

  def self.config
    @config
  end
end
