ARG RUBY_VERSION=3.3.6
FROM ruby:${RUBY_VERSION} AS base

WORKDIR /rails

RUN gem install rails && \
  rails new . --minimal --name terminalwire-integration

FROM base AS local

COPY ./containers/rails/app/models /rails/app/models
COPY ./gem /gem

RUN bundle config local.terminalwire-core /gem/terminalwire-core && \
    bundle config local.terminalwire-server /gem/terminalwire-server && \
    bundle config local.terminalwire-rails /gem/terminalwire-rails && \
    bundle config local.terminalwire /gem/terminalwire

RUN bundle add terminalwire

RUN bin/rails generate terminalwire:install hello

EXPOSE 3000
CMD ["bin/rails", "server", "--port", "3000", "--binding", "0.0.0.0"]
