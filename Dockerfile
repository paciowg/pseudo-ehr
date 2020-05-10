FROM ruby:2.6.3
#RUN apt-get update -qq && apt-get install -y nodejs postgresql-client
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs

# Configure the main working directory. This is the base
# directory used in any further RUN, COPY, and ENTRYPOINT
# commands.
RUN mkdir /app
WORKDIR /app

# Copy the Gemfile as well as the Gemfile.lock and install
# the RubyGems. 
COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock
RUN gem install -N bundler && bundle install

# Copy the main application.
COPY . /app

# Add a script to be executed every time the container starts.  
# This fixes a Rails-specific issue that prevents the server 
# from restarting when a certain server.pid file pre-exists. 
# This script will be executed every time the container gets started.
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Start the main process.
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]