class DebuggingCase < ApplicationRecord
  belongs_to :user

  encrypts :customer_reference

  validates :title, presence: true
end
