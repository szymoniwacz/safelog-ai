class CorrelationSignal < ApplicationRecord
  belongs_to :debugging_case

  encrypts :payload
end
