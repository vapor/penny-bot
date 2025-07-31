# ================================
# Build image
# ================================
FROM swift:6.1-noble AS build

ARG SWIFT_CONFIGURATION
ARG EXEC_NAME

# Install OS updates
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libjemalloc-dev

# Set up a build area
WORKDIR /build

COPY . .

RUN --mount=type=cache,target=.build \
    du -hs * && \
    swift build \
      --product Penny \
      -c release \
      --force-resolved-versions \
      --static-swift-stdlib \
      -Xlinker -ljemalloc

WORKDIR /staging

# Move executable to the root of the staging area
RUN --mount=type=bind,target=. \
    cp "$(swift build -c $SWIFT_CONFIGURATION --show-bin-path)/$EXEC_NAME" ./

# Copy static swift backtracer binary to staging area
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./

# Copy resources bundled by SPM to staging area
RUN --mount=type=bind,target=.build \
    find -L "$(swift build -c $SWIFT_CONFIGURATION --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# ================================
# Run image
# ================================
FROM ubuntu:noble

# Make sure all system packages are up to date, and install only essential packages.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
      libjemalloc2 \
      ca-certificates \
      tzdata \
# If your app or its dependencies import FoundationNetworking, also install `libcurl4`.
      # libcurl4 \
# If your app or its dependencies import FoundationXML, also install `libxml2`.
      # libxml2 \
    && rm -r /var/lib/apt/lists/*

# Create a vapor user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Switch to the new home directory
WORKDIR /app

# Copy built executable and any staged resources from builder
COPY --from=build --chown=vapor:vapor /staging /app

# Provide configuration needed by the built-in crash reporter and some sensible default behaviors.
ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,symbolicate=fast,swift-backtrace=./swift-backtrace-static

# Ensure all further commands run as the vapor user
USER vapor:vapor

# Let Docker bind to port 8080
EXPOSE 8080

# Start the Penny service when the image is run.
ENTRYPOINT ["./Penny"]
