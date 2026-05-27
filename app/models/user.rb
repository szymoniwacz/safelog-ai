class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :validatable

  has_many :debugging_cases, dependent: :destroy
end
