def processor_for(method)
  processor_class = processor_mapping[method.to_s] || InvalidMethodProcessor
  processor_class.new(reservation, payment_params)
end

# 支払い方法とプロセッサクラスのマッピング
def processor_mapping
  {
    "credit_card" => CreditCardProcessor,
    "bank_transfer" => BankTransferProcessor,
    "convenience_store" => ConvenienceStoreProcessor
  }
end
