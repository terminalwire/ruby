class User
  attr_reader :email

  def initialize(email:)
    @email = email
  end
  alias :id :email

  def valid_password?(password)
    true
  end

  def self.find_for_authentication(email:)
    find email
  end

  def self.find(email)
    new email: email
  end

  def self.find_by(id:)
    find id
  end
end
