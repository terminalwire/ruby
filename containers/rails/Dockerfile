ARG RUBY_VERSION=3.3.6
FROM ruby:${RUBY_VERSION} AS base

WORKDIR /rails

RUN gem install rails && \
    rails new . --minimal --name terminalwire-integration

FROM base AS local

# Ensure our local gem executables are on the PATH.
COPY ./containers/rails/app /rails/app/
COPY ./gem/*/pkg/*.gem /gem/
RUN gem install /gem/terminalwire*.gem

# Remove the remote source from the Gemfile so that nothing is fetched remotely.
RUN sed -i '/^source/d' Gemfile

# This will add the local terminalwire-raisl gem.
RUN bundle add terminalwire-rails

RUN bin/rails generate terminalwire:install hello

# Add IntegrationTerminal as a Thor subcommand to MainTerminal
RUN sed -i '$i\  desc "integration", "Integration tests"\n  subcommand "integration", IntegrationTerminal'  app/terminal/main_terminal.rb

CMD ["bin/rails", "server", "--port", "3000", "--binding", "0.0.0.0"]
