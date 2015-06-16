require 'adyen/api/simple_soap_client'
require 'adyen/api/templates/payout_service'

module Adyen
  module API
    # This is the class that maps actions to Adyen’s Payout SOAP service.
    #
    # It’s encouraged to use the shortcut methods on the {API} module.
    # Henceforth, for extensive documentation you should look at the {API} documentation.
    #
    # The most important difference is that you instantiate a {PayoutService} with the parameters
    # that are needed for the call that you will eventually make.
    #
    # @example
    #  payout = Adyen::API::PayoutService.new({
    #    :shopper => {
    #      :email => "user@example.com",
    #      :reference => "example_user_1"
    #    },
    #    :bank => {
    #      :iban => "NL48RABO0132394782",
    #      :bic => "RABONL2U",
    #      :bank_name => 'Rabobank',
    #      :country_code => 'NL',
    #      :owner_name => 'Test Shopper'
    #    }
    #  })
    #  response = payout.store_detail
    #  response.detail_stored? # => true
    #
    class PayoutService < SimpleSOAPClient
      # The Adyen Payout SOAP service endpoint uri.
      ENDPOINT_URI = 'https://pal-%s.adyen.com/pal/servlet/soap/Payout'

      # @see API.store_detail
      def store_detail
        call_webservice_action('storeDetail', store_detail_request_body, StoreDetailResponse)
      end

      # @see API.submit_payout
      def submit
        call_webservice_action('submit', submit_request_body, SubmitResponse, payout_credentials)
      end

      private

      def payout_credentials
        @payout_credentials ||= {
          api_username: Adyen.configuration.payout_api_username,
          api_password: Adyen.configuration.payout_api_password
        }
      end

      def submit_request_body
        content = amount_partial
        content << reference_partial
        content << recurring_detail_reference_partial
        content << ENABLE_RECURRING_PAYOUT_CONTRACT_PARTIAL
        payout_request_body(content, 'submit')
      end

      def store_detail_request_body
        content = bank_partial
        content << ENABLE_RECURRING_PAYOUT_CONTRACT_PARTIAL
        payout_request_body(content, 'storeDetail')
      end

      def payout_request_body(content, method)
        validate_parameters!(:merchant_account)
        content << shopper_partial
        LAYOUT % [method, @params[:merchant_account], content, method]
      end

      def bank_partial
        validate_parameters!(:bank => [:iban, :bic, :bank_name, :country_code, :owner_name])
        bank  = @params[:bank].values_at(:iban, :bic, :bank_name, :country_code, :owner_name)
        BANK_PARTIAL % bank
      end

      def shopper_partial
        validate_parameters!(:shopper => [:email, :reference])
        @params[:shopper].map { |k, v| SHOPPER_PARTIALS[k] % v }.join("\n")
      end

      def reference_partial
        validate_parameters!(:reference)
        reference = @params[:reference]
        REFERENCE_PARTIAL % reference
      end

      def recurring_detail_reference_partial
        validate_parameters!(:selected_recurring_detail_reference)
        recurring_detail = @params[:selected_recurring_detail_reference]
        RECURRING_DETAIL_REFERENCE_PARTIAL % recurring_detail
      end

      def amount_partial
        validate_parameters!(:amount => [:currency, :value])
        amount = @params[:amount].values_at(:currency, :value)
        AMOUNT_PARTIAL % amount
      end

      class StoreDetailResponse < Response
        ERRORS = {
          "validation 111 Invalid BankCountryCode specified" => [:country_code, 'is not a valid country code'],
          "validation 161 Invalid iban" => [:iban, 'is not a valid IBAN']
        }

        class << self
          # @private
          def base_xpath
            '//payout:storeDetailResponse/payout:response'
          end
        end

        response_attrs :psp_reference, :result_code, :recurring_detail_reference, :refusal_reason

        # This only returns whether or not the request has been successfully received. Check the
        # subsequent notification to see if the payment was actually mutated.
        def success?
          super && params[:result_code] == 'Success'
        end

        alias_method :detail_stored?, :success?

        # In the case of a validation error, or SOAP fault message, this method will return an
        # array describing what attribute failed validation and the accompanying message. If the
        # errors is not of the common user validation errors, then the attribute is +:base+ and the
        # full original message is returned.
        #
        # An optional +prefix+ can be given so you can seamlessly integrate this in your
        # ActiveRecord model and copy over errors.
        #
        # @param [String,Symbol] prefix A string that should be used to prefix the error key.
        # @return [Array<Symbol, String>] A name-message pair of the attribute with an error.
        def error(prefix = nil)
          if error = ERRORS[fault_message]
            prefix ? ["#{prefix}_#{error[0]}".to_sym, error[1]] : error
          elsif fault_message
            [:base, fault_message]
          else
            [:base, 'Request failed for unkown reasons.']
          end
        end

        def params
          @params ||= xml_querier.xpath(self.class.base_xpath) do |result|
            {
              :psp_reference              => result.text('./payout:pspReference'),
              :result_code                => result.text('./payout:resultCode'),
              :recurring_detail_reference => result.text('./payout:recurringDetailReference'),
              :refusal_reason => (invalid_request? ? fault_message : '')
            }
          end
        end
      end

      class SubmitResponse < Response
        BASE_XPATH = '//payout:submitResponse/payout:response'

        response_attrs :psp_reference, :refusal_reason, :result_code

        def params
          @params ||= xml_querier.xpath(BASE_XPATH) do |result|
            {
              :psp_reference              => result.text('./payout:pspReference'),
              :refusal_reason             => result.text('./payout:refusalReason'),
              :result_code                => result.text('./payout:resultCode'),
            }
          end
        end

        def received?
          params[:result_code] == '[payout-submit-received]'
        end

        def success?
          super && received?
        end
      end
    end
  end
end
