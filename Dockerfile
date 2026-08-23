FROM ghcr.io/clacky-ai/rails-base-template:latest AS base

WORKDIR /app

# Set production environment
ENV RAILS_ENV="production" \
    NODE_ENV="production" \
    PORT="3000"

# Install ImageMagick for image_processing gem (微信封面/正文图格式转换 webp→jpg)
# 兼容 debian/ubuntu (apt) 和 alpine (apk)
USER root
RUN (command -v apt-get >/dev/null && apt-get update -qq && apt-get install -y --no-install-recommends imagemagick && rm -rf /var/lib/apt/lists/*) \
    || (command -v apk >/dev/null && apk add --no-cache imagemagick) \
    || echo "WARN: failed to install imagemagick, image conversion may fail at runtime"
USER ruby

FROM base AS gems

# Check and install only missing gems (if Gemfile changed)
# bundle check returns 0 if all gems are satisfied, otherwise install
COPY --chown=ruby:ruby Gemfile Gemfile.lock ./
RUN bundle check || bundle install --jobs=4 --retry=3

FROM gems AS build

# Check and install only missing npm packages (if package.json changed)
COPY --chown=ruby:ruby package.json package-lock.json ./
RUN npm ci --production=false

# Copy application code
COPY --chown=ruby:ruby . .

# Precompile assets (use local storage and fake database to avoid runtime dependencies)
RUN echo 'SECRET_KEY_BASE: "dummy"' > config/application.yml \
    && mkdir -p app/assets/builds \
    && DATABASE_URL=postgresql://user:pass@localhost/dbname \
       SECRET_KEY_BASE_DUMMY=1 \
       ACTIVE_STORAGE_SERVICE=local \
       bundle exec rails assets:precompile \
    && rm -rf node_modules config/application.yml

# Keep build-only npm dependencies and temporary Figaro config out of the
# runtime image. The gems stage is reused so installed gems remain cached.
FROM gems AS runtime

ARG APP_REVISION=unknown
ENV APP_REVISION="${APP_REVISION}"

COPY --from=build --chown=ruby:ruby /app /app

ENTRYPOINT ["/app/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE ${PORT}
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
