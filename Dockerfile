# Build image versions
ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=28.0.1
ARG DEBIAN_VERSION=bullseye-20260316-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ---- Build stage ----
FROM ${BUILDER_IMAGE} AS builder

# Node is needed for npm ci (CodeMirror assets)
RUN apt-get update -y && \
    apt-get install -y build-essential git nodejs npm && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

# Install Elixir deps
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Compile deps (separate layer so code changes don't re-compile deps)
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# Install JS deps and build assets
RUN npm ci --prefix assets && mix assets.deploy

# Compile and build release
RUN mix compile
COPY config/runtime.exs config/
COPY rel rel
RUN mix release

# ---- Runtime stage ----
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y \
      # Elixir/OTP runtime
      libstdc++6 openssl libncurses5 locales ca-certificates \
      # Calibre runtime dependencies
      libgl1 libglib2.0-0 libfontconfig1 libdbus-1-3 \
      libxcb1 libxkbcommon0 libegl1 libopengl0 libxrender1 \
      # Calibre installer
      wget xz-utils python3 python-is-python3 \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install Calibre to /opt/calibre (matches COURIER_CALIBRE_PATH default)
RUN wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | \
    sh /dev/stdin install_dir=/opt/calibre

# Run Calibre CLI tools headlessly — no X11 display required
ENV QT_QPA_PLATFORM=offscreen
ENV CALIBRE_NO_NATIVE_FILE_DIALOGS=1
# Allow Calibre to write its config under /tmp when running as nobody
ENV HOME=/tmp

WORKDIR /app
RUN chown nobody /app

ENV MIX_ENV="prod"
# Start in server mode automatically
ENV PHX_SERVER=true

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/courier ./

USER nobody

EXPOSE 4000

CMD ["/app/bin/server"]
