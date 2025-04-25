# Terminalwire

Unlike most command-line tools for web services that require an API, Terminalwire streams terminal I/O between a web server and client over WebSockets. This means you can use your preferred command-line parser within your favorite web server framework to deliver a delightful CLI experience to your users.

## What's in this repo?

This is a monolithic repository with several Terminalwire components, including the Terminalwire thin-client and Ruby & Rails servers.

### Terminalwire Client

The Terminalwire thin-client is pacakged using Tebako and is installed on end-user workstations. The thin-client connects to a Terminalwire server and streams stdio, browser, filesystem, and other commands between the server and client via WebSockets through an entitlement-based security layer.

[Read the Terminalwire-client manual](https://terminalwire.com/docs/client)

### Terminalwire Ruby & Rails servers

Terminalwire servers can run on any platform or framework. This repo has source for the Ruby Terminalwire server, specifically targeting Ruby on Rails.

[Read the Terminalwire Ruby on Rails manual](https://terminalwire.com/docs/rails)

## Installation

### Client

The Terminalwire thin-client may be installed by running:

    $ curl -sSL https://terminalwire.sh/ | bash

This installs the Tebako packaged version of the Terminalwire client, which is recommended for production use.

#### RubyGem client

The Terminalwire thin-client gem may be installed for development purposes by running:

    $ gem install terminalwire

*This approach is not recommended for production use since developer workstations likely don't have the correct Ruby dependencies installed*

## Rails

Run the intallation command:

    $ rails g terminalwire:install my-app

This generates the `./bin/my-app` file. Run it to verify that it connects to the server.

    $ bin/my-app
    Commands:
      my-app help [COMMAND]  # Describe available commands or one specific command

To edit the command-line, open `./app/cli/main_cli.rb` and make changes to the `MainCLI` class.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/terminalwire/ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/terminalwire/ruby/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as a propietary license. The tl;dr is that it's free for personal use and for commercial use email brad@terminalwire.com to discuss licensing.

## Code of Conduct

Everyone interacting in the Terminalwire project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/terminalwire/ruby/blob/main/CODE_OF_CONDUCT.md).
