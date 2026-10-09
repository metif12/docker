# V built from source on a Nix-pinned toolchain.
#
# Two things differ from Dockerfile.alpine / Dockerfile.debian:
#
#   1. The toolchain comes from a pinned nixpkgs revision, so the image is
#      reproducible in a way `apk add` / `apt install` never is.
#   2. The container carries a working Nix, so any nixpkgs library can be made
#      available at build time without root and without a second base image:
#        docker run --rm -it thevlang/vlang:nix sh -c 'nix-shell -p openssl --run "v run main.v"'
#
# The source is built in /opt/vlang and installed at the same path on purpose.
# V bakes the location of its own stdlib into the binary at compile time (see
# vlib/v/pref/pref.v:detect_vroot and the @VMODROOT handling in
# vlib/v/parser/parser.v:12149). Building anywhere other than the install path
# produces a compiler that cannot find vlib.
#
# NIXPKGS_REV is deliberately not redeclared here: the pin lives in
# Dockerfile.nix.build, which is the image this one stands on.
ARG USER=thevlang
# Which V revision is built; see Dockerfile.alpine.
ARG V_REV=master

# Stage 1 - build the V compiler
FROM ${USER}/vlang:nix-build AS builder

ARG V_REV

WORKDIR /opt/vlang

RUN git clone --depth 1 https://github.com/vlang/v . && \
    git fetch --quiet --depth 1 origin "${V_REV}" && \
    git checkout --quiet FETCH_HEAD && \
    make VFLAGS='-cc gcc' && v -version

# Stage 2 - the shipped image. The same base image, so /nix/store holds every
#           store path the freshly built compiler needs.
FROM ${USER}/vlang:nix-build AS runtime

COPY --from=builder /opt/vlang /opt/vlang

ENV VFLAGS="-cc gcc"

WORKDIR /src
