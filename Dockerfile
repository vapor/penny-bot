FROM swift:5.5-focal as build

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY ./CODE/Package.* ./
RUN swift package resolve

COPY ./CODE .

RUN swift build -c release --static-swift-stdlib --target PennyBOT

WORKDIR /staging

RUN cp "$(swift build --package-path /build -c release --show-bin-path/Run)" ./

RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# ===== RUN IMAGE =====
FROM ubuntu:focal

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    apt-get -q update && apt-get -q dist-upgrade -y && apt-get -q install -y ca-certificates tzdata && \
    rm -r /var/lib/apt/lists/*

RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

WORKDIR /app

COPY --from=build --chown=vapor:vapor /staging /app

USER vapor:vapor

EXPOSE 8080

ENTRYPOINT [ "./Run" ]
CMD [ "serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080" ]