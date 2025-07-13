FROM ubuntu:22.04

RUN apt update && apt install -y \
    python3 \
    unzip \
    cpio mtd-utils liblzo2-dev python3-pip \
    vim &&  pip3 install python-lzo && pip3 install ubi_reader

# Create user with UID 1001 to match host
RUN useradd -m -u 1001 firmware

WORKDIR /workspace
COPY . /workspace

# Default command is bash for interactive work
CMD ["/bin/bash"]
