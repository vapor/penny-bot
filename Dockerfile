# ================================
# Build image
# ================================
FROM ubuntu:jammy as build

ARG SWIFT_CONFIGURATION
ARG EXEC_NAME

WORKDIR /staging

# Copy .build to staging area
COPY .build ./.build

# Move executable to the root of the staging area
RUN mv .build/$SWIFT_CONFIGURATION/$EXEC_NAME ./

# Copy static swift backtracer binary to staging area
COPY .build/swift-backtrace-static ./

# Copy resources bundled by SPM to staging area
RUN find -L ".build/$SWIFT_CONFIGURATION/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# Remove .build directory
RUN rm -dr .build

# ================================
# Run image
# ================================
FROM ubuntu:jammy

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
