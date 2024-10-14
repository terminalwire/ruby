class MainTerminal < ApplicationTerminal
  desc "hello NAME", "say hello to NAME"
  def hello(name)
    puts "Hello #{name}"
  end

  desc "login", "Login to your account"
  def login
    print "Email: "
    email = gets.chomp

    print "Password: "
    password = getpass

    # Replace this with your own authentication logic; this is an example
    # of how you might do this with Devise.
    user = User.find_for_authentication(email: email)
    if user && user.valid_password?(password)
      self.current_user = user
      puts "Successfully logged in as #{current_user.email}."
    else
      puts "Could not find a user with that email and password."
    end
  end

  desc "whoami", "Displays current user information."
  def whoami
    if self.current_user
      puts "Logged in as #{current_user.email}."
    else
      puts "Not logged in. Run `#{self.class.basename} login` to login."
    end
  end

  desc "logout", "Logout of your account"
  def logout
    session.reset
    puts "Successfully logged out."
  end
end
