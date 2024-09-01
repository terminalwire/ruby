# Use an official Ruby runtime as a parent image
FROM ruby:3.3.0

# Set up environment variables
ENV LANG C.UTF-8

# Install dependencies
RUN apt-get update -qq && apt-get install -y nodejs yarn

# Set up working directory
WORKDIR /app

# Install Bundler
RUN gem install bundler

# Copy Gemfile and Gemfile.lock from the root context
COPY ../../Gemfile ../../Gemfile.lock ./

# Install dependencies
RUN bundle install

# Copy the rest of the application code
COPY ../../ .

# Expose port 3000 for the Rails server
EXPOSE 3000

# Command to run tests
CMD ["bundle", "exec", "rspec"]
