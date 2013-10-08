module Adyen
  class Engine < ::Rails::Engine
    isolate_namespace Adyen
  end

  class EngineConfiguration
    attr_reader :http_username, :http_password, :disable_basic_auth

    def payment_result_redirect(controller)
      @payment_result_redirect.call(controller)
    end

    def initialize(http_username, http_password, configurator)
      @http_username = http_username
      @http_password = http_password
      @disable_basic_auth = configurator.disable_basic_auth
      @payment_result_redirect = configurator.payment_result_redirect
      @skins = {}
      if main_skin = configurator.main_skin
        Adyen.configuration.register_form_skin(:main, main_skin[:code], main_skin[:secret])
      end
    end
  end

  class FailureConfig
    def method_missing(method, *args)
      raise NotConfigured.new
    end
  end

  # Used to interpret the config run against the engine, and prevents on the fly
  # reconfiguration of things that should not be reconfigured (well, okay, doesn't
  # prevent, but makes it a bit less likely to happen accidentally)
  class Configurator
    attr_accessor :http_username, :http_password, :disable_basic_auth

    def redirect_payment_with(&block)
      @payment_result_redirect_block = lambda {|c| block.call(c) }
    end

    def payment_result_redirect
      @payment_result_redirect_block
    end

    def initialize(&block)
      @skins ||= {}
      raise ConfigMissing.new unless block
      yield self
      # set defaults if they haven't already been set
      @disable_basic_auth ||= false
      @payment_result_redirect_block ||= lambda {|c| c.payments_complete_path()}
    end

    def add_main_skin(skin_code, secret)
      @skins[:main] = {code: skin_code, secret: secret}
    end

    def main_skin
      @skins[:main]
    end

    def method_missing method, *args
      Rails.logger.error "Your Adyen configuration is incorrect.  There is no setting called #{method}"
      super
    end
  end

  class ConfigMissing < StandardError
    def initialize
      super 'You have not passed a block to the Adyen#setup method!'
    end
  end

  class NotConfigured < StandardError
    def initialize
      super "You have not configured the Adyen engine.  Please add an Adyen#setup block into your enovironments/#{Rails.env}.rb file."
    end
  end

  def self.setup(&block)
    config = Configurator.new &block
    @config = EngineConfiguration.new(config.http_username, config.http_password, config)
  end

  def self.config
    @config ||= FailureConfig.new
  end
end
