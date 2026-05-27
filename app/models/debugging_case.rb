class DebuggingCase < ApplicationRecord
  belongs_to :user

  encrypts :customer_reference

  has_many :log_sources, dependent: :destroy

  validates :title, presence: true
end
