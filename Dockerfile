# Use the same Ruby version as your Gemfile
FROM ruby:3.3.6

# Install build dependencies, Node.js for the asset pipeline, yarn, and postgres client
RUN apt-get update -qq && apt-get install -y build-essential nodejs npm libpq-dev
RUN npm install -g yarn

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy the Gemfile and Gemfile.lock to leverage Docker's layer caching.
# This will prevent re-installing gems on every code change.
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install

# Copy package.json and yarn.lock to leverage caching
COPY package.json yarn.lock ./
# Install node modules
RUN yarn install

# Copy the main application code
COPY . .

# Precompile assets
RUN RAILS_ENV=production bundle exec rails assets:precompile

# Expose port 3000 to be accessible from the host machine
EXPOSE 3000

# The main command to run when the container starts.
# It starts the Rails server and binds it to all IP addresses.
CMD ["rails", "server", "-b", "0.0.0.0"]
