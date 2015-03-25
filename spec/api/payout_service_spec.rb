# encoding: UTF-8
require 'api/spec_helper'

shared_examples_for "payout requests" do
  it "includes the merchant account handle" do
    text('./payout:merchantAccount').should == 'SuperShopper'
  end

  it "includes the shopper’s details" do
    text('./payout:shopperReference').should == 'user-id'
    text('./payout:shopperEmail').should == 's.hopper@example.com'
  end

  it "includes the necessary recurring contract info" do
    text('./payout:recurring/payment:contract').should == 'PAYOUT'
  end
end

describe Adyen::API::PayoutService do
  include APISpecHelper

  before { @payout = @object = Adyen::API::PayoutService.new(params) }

  describe 'store_detail' do
    let(:base_path) { '//payout:storeDetail/payout:request' }
    let(:params) do
      {
        :shopper => {
          :email => 's.hopper@example.com',
          :reference => 'user-id'
        },
        :bank => {
          :iban => "NL48RABO0132394782",
          :bic => "RABONL2U",
          :bank_name => 'Rabobank',
          :country_code => 'NL',
          :owner_name => 'Test Shopper'
        }
      }
    end
    describe_request_body_of :store_detail do
      it_should_behave_like "payout requests"

      it "includes the bank details" do
        xpath('./payout:bank') do |bank|
          bank.text('./payment:iban').should == 'NL48RABO0132394782'
          bank.text('./payment:bic').should == 'RABONL2U'
          bank.text('./payment:bankName').should == 'Rabobank'
          bank.text('./payment:countryCode').should == 'NL'
          bank.text('./payment:ownerName').should == 'Test Shopper'
        end
      end

      it_should_validate_request_parameters :merchant_account,
                                            :shopper => [:reference, :email],
                                            :bank => [:iban, :bic, :bank_name, :country_code, :owner_name]

      it_should_validate_request_param(:shopper) do
        @payout.params[:shopper] = nil
      end

      [:reference, :email].each do |attr|
        it_should_validate_request_param(:shopper) do
          @payout.params[:shopper][attr] = ''
        end
      end

      it "includes the right method name" do
        xpath('/payout:storeDetail').should_not be_empty
      end
    end

    describe_response_from :store_detail, STORE_DETAIL_RESPONSE, 'storeDetail' do
      it_should_return_params_for_each_xml_backend({
        :psp_reference => '9913134957760023',
        :result_code => 'Success',
        :recurring_detail_reference => '2713134957760046',
        :refusal_reason => ''
      })

      describe "with a `invalid' response" do
        before do
          stub_net_http(STORE_DETAIL_INVALID_RESPONSE % 'validation 111 Invalid BankCountryCode specified')
          @response = @payout.store_detail
        end

        it "returns that the request was not successful" do
          @response.should_not be_success
        end

        it "it returns that the request was invalid" do
          @response.should be_invalid_request
        end

        it "returns the fault message from #refusal_reason" do
          @response.refusal_reason.should == 'validation 111 Invalid BankCountryCode specified'
          @response.params[:refusal_reason].should == 'validation 111 Invalid BankCountryCode specified'
        end

        it "returns bank validation errors" do
          [
            ["validation 111 Invalid BankCountryCode specified", [:country_code, 'is not a valid country code']],
            ["validation 161 Invalid iban", [:iban, 'is not a valid IBAN']]
          ].each do |message, error|
            response_with_fault_message(message).error.should == error
          end
        end

        private

        def response_with_fault_message(message)
          stub_net_http(STORE_DETAIL_INVALID_RESPONSE % message)
          @response = @payout.store_detail
        end
      end
    end
  end

  describe '#submit' do
    let(:base_path) { '//payout:submit/payout:request' }
    let(:params) do
      {
        :reference => 'PayoutPayment-0001',
        :amount => {
          :currency => 'EUR',
          :value => '1234'
        },
        :shopper => {
          :email => 's.hopper@example.com',
          :reference => 'user-id'
        },
        :selected_recurring_detail_reference => 'LATEST'
      }
    end

    describe_request_body_of :submit do
      it_should_behave_like "payout requests"

      it "includes the given amount of `currency'" do
        xpath('./payout:amount') do |amount|
          amount.text('./common:currency').should == 'EUR'
          amount.text('./common:value').should == '1234'
        end
      end

      it "includes the payout reference" do
        text('./payout:reference').should == 'PayoutPayment-0001'
      end

      it "includes the recurring detail reference" do
        text('./payout:selectedRecurringDetailReference').should == 'LATEST'
      end

      it "includes the right method name" do
        xpath('/payout:submit').should_not be_empty
      end

      it_should_validate_request_parameters :reference,
                                            :selected_recurring_detail_reference,
                                            :merchant_account,
                                            :amount => [:currency, :value],
                                            :shopper => [:reference, :email]

    end

    describe_response_from :submit, SUBMIT_PAYOUT_RESPONSE, 'submit' do
      it_should_return_params_for_each_xml_backend({
        :psp_reference => '9913140798220028',
        :refusal_reason => '',
        :result_code => '[payout-submit-received]'
      })

      it 'returns request success' do
        @response.should be_success
      end

      it 'returns request received' do
        @response.should be_received
      end

      describe'whit an invalid response' do
        before do
          stub_net_http(SUBMIT_PAYOUT_INVALID_RESPONSE % 'security 010 Not allowed')
          @response = @payout.submit
        end

        it 'returns that the request was not successful' do
          @response.should_not be_success
        end

        it 'returns request not recieved' do
          @response.should_not be_received
        end

        it "it returns that the request was invalid" do
          @response.should be_invalid_request
        end
      end
    end
  end

  private

  def node_for_current_method
    node_for_current_object_and_method.xpath(base_path)
  end
end
