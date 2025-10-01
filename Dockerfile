# STAGE 1: Build stage
FROM ruby:3.3.6 AS builder

# Install build dependencies, Node.js for the asset pipeline, yarn, and postgres client
RUN apt-get update -qq && apt-get install -y build-essential nodejs npm libpq-dev
RUN npm install -g yarn

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

# Build Tailwind CSS first to ensure the output file exists for Sprockets
RUN RAILS_ENV=production SECRET_KEY_BASE=dummy bundle exec rails tailwindcss:build

# Precompile assets, which will now find the generated tailwind.css
RUN RAILS_ENV=production SECRET_KEY_BASE=dummy bundle exec rails assets:precompile

# STAGE 2: Final runtime stage
FROM ruby:3.3.6

# Install only essential runtime dependencies
RUN apt-get update -qq && apt-get install -y libpq-dev --no-install-recommends && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

# Copy installed gems and application code with precompiled assets from the builder stage
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=builder /usr/src/app .

# Expose port 3000 to be accessible from the host machine
EXPOSE 3000

# The main command to run when the container starts.
# It starts the Rails server and binds it to all IP addresses.
CMD ["rails", "server", "-b", "0.0.0.0"]
