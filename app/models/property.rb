class Property < ApplicationRecord

  def full_url
    "https://www.rightmove.co.uk" + self.url
  end
end
