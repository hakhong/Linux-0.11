# Build environment for Linux 0.11: gcc 4.8 (32-bit via gcc-multilib), make,
# and bin86 (as86/ld86) for the original 16-bit boot code.
FROM ubuntu:14.04

RUN apt-get update && apt-get install -y \
    gcc gcc-multilib make bin86

WORKDIR /build

CMD ["tail", "-f", "/dev/null"]
