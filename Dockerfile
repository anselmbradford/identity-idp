# Use Ubuntu 20.04 as the base image
FROM ubuntu:20.04

# Set environment variables
ENV RAILS_ROOT /app
ENV RAILS_ENV production
ENV NODE_ENV production
ENV RAILS_SERVE_STATIC_FILES true
ENV RAILS_LOG_TO_STDOUT true
ENV LOGIN_CONFIG_FILE $RAILS_ROOT/tmp/application.yml
ENV RAILS_LOG_LEVEL debug
ENV BUNDLE_PATH /usr/local/bundle
ENV PATH="/app/bin:${PATH}"
ENV YARN_VERSION 1.22.5
ENV RUBY_VERSION 3.2.2
ENV NODE_VERSION 16.20.0
ENV BUNDLER_VERSION 2.4.4
ENV NVM_DIR /home/app/.nvm
ENV RVM_DIR /home/app/.rvm
USER root

# Create a new user and set up the working directory
RUN addgroup --gid 1000 app && \
    adduser --uid 1000 --gid 1000 --disabled-password --gecos "" app && \
    mkdir -p $RAILS_ROOT && \
    mkdir -p $RVM_DIR && \
    mkdir -p $NVM_DIR && \
    mkdir -p $BUNDLE_PATH && \
    chown -R app:app $RAILS_ROOT && \
    chown -R app:app $BUNDLE_PATH

# Setup timezone data
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    libpq-dev \
    libssl-dev \
    libyaml-dev \
    postgresql-client \
    tzdata \
    openssl \
    gnupg2

WORKDIR /home/app

# Install RVM, Ruby, and Bundler
RUN command curl -sSL https://rvm.io/mpapis.asc | gpg2 --import - && \
    command curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import - && \
    \curl -sSL https://get.rvm.io | bash -s stable && \
    /bin/bash -l -c "source /etc/profile.d/rvm.sh && rvm install $RUBY_VERSION" && \
    echo 'source "/etc/profile.d/rvm.sh"' >> /etc/bash.bashrc && \
    /bin/bash -l -c "gem install bundler -v $BUNDLER_VERSION"

# Install NVM, Node.js
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> /home/app/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> $NVM_DIR/.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> $NVM_DIR/.bashrc && \
    /bin/bash -l -c ". $NVM_DIR/nvm.sh && nvm install $NODE_VERSION && nvm alias default $NODE_VERSION && nvm use default"

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarn-archive-keyring.gpg >/dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y yarn=1.22.5-1

# Copy the application code
USER root
COPY --chown=app:app . $RAILS_ROOT

# Copy application.yml.default to application.yml
COPY --chown=app:app ./config/application.yml.default.docker $RAILS_ROOT/config/application.yml

# Setup config files
COPY --chown=app:app config/agencies.localdev.yml $RAILS_ROOT/config/agencies.yaml
COPY --chown=app:app config/iaa_gtcs.localdev.yml $RAILS_ROOT/config/iaa_gtcs.yaml
COPY --chown=app:app config/iaa_orders.localdev.yml $RAILS_ROOT/config/iaa_orders.yaml
COPY --chown=app:app config/iaa_statuses.localdev.yml $RAILS_ROOT/config/iaa_statuses.yaml
COPY --chown=app:app config/integration_statuses.localdev.yml $RAILS_ROOT/config/integration_statuses.yaml
COPY --chown=app:app config/integrations.localdev.yml $RAILS_ROOT/config/integrations.yaml
COPY --chown=app:app config/partner_account_statuses.localdev.yml $RAILS_ROOT/config/partner_account_statuses.yaml
COPY --chown=app:app config/partner_accounts.localdev.yml $RAILS_ROOT/config/partner_accounts.yaml
COPY --chown=app:app config/service_providers.localdev.yml $RAILS_ROOT/config/service_providers.yaml

# Copy keys
COPY --chown=app:app keys.example $RAILS_ROOT/keys

# Copy pwned_passwords.txt
COPY --chown=app:app pwned_passwords/pwned_passwords.txt.sample $RAILS_ROOT/pwned_passwords/pwned_passwords.txt

# Copy robots.txt
COPY --chown=app:app public/ban-robots.txt $RAILS_ROOT/public/robots.txt

# Set user
USER app
WORKDIR $RAILS_ROOT

# Precompile assets
RUN /bin/bash -l -c "bundle config build.nokogiri --use-system-libraries"
RUN /bin/bash -l -c "bundle config set --local deployment 'true'"
RUN /bin/bash -l -c "bundle config set --local path $BUNDLE_PATH"
RUN /bin/bash -l -c "bundle config set --local without 'deploy development doc test'"
RUN /bin/bash -l -c "bundle install --jobs $(nproc)"
RUN /bin/bash -l -c ". $NVM_DIR/nvm.sh && nvm use default && yarn install --production=true --frozen-lockfile --cache-folder .yarn-cache"
RUN /bin/bash -l -c "bundle binstubs --all"
RUN /bin/bash -l -c ". $NVM_DIR/nvm.sh && nvm use default && bundle exec rake assets:precompile --trace"

# Expose the port the app runs on
EXPOSE 3000

# Start the application
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
