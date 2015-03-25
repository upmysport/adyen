module Adyen
  module API
    class PayoutService < SimpleSOAPClient
      # @private
      LAYOUT = <<EOS
<%s xmlns="http://payout.services.adyen.com">
  <request>
    <merchantAccount>%s</merchantAccount>
    %s
    </request>
</%s>
EOS

      # @private
      BANK_PARTIAL = <<EOS
<bank>
  <iban xmlns="http://payment.services.adyen.com">%s</iban>
  <bic xmlns="http://payment.services.adyen.com">%s</bic>
  <bankName xmlns="http://payment.services.adyen.com">%s</bankName>
  <countryCode xmlns="http://payment.services.adyen.com">%s</countryCode>
  <ownerName xmlns="http://payment.services.adyen.com">%s</ownerName>
</bank>
EOS

      # @private
      ENABLE_RECURRING_PAYOUT_CONTRACT_PARTIAL = <<EOS
<recurring>
  <contract xmlns="http://payment.services.adyen.com">PAYOUT</contract>
</recurring>
EOS

      # @private
      SHOPPER_PARTIALS = {
        :reference => '<shopperReference>%s</shopperReference>',
        :email     => '<shopperEmail>%s</shopperEmail>'
      }

      # @private
      AMOUNT_PARTIAL = <<EOS
<amount>
  <currency xmlns="http://common.services.adyen.com">%s</currency>
  <value xmlns="http://common.services.adyen.com">%s</value>
</amount>
EOS
#
      # @private
      REFERENCE_PARTIAL = <<EOS
<reference>%s</reference>
EOS
#
      # @private
      RECURRING_DETAIL_REFERENCE_PARTIAL = <<EOS
<selectedRecurringDetailReference>%s</selectedRecurringDetailReference>
EOS
    end
  end
end
