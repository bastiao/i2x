class SeedMapping < ActiveRecord::Base
  belongs_to	:agent
  belongs_to	:seed
end