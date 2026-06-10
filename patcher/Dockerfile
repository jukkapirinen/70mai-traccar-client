FROM ubuntu:22.04

# Install required packages and clone the Novatek tools
RUN apt update && apt install -y \
    python3 \
    python3-pip \
    python3-dev \
    build-essential \
    unzip \
    cpio \
    mtd-utils \
    liblzo2-dev \
    grep \
    sudo \
    bash \
    git \
    xxd && \
    pip3 install python-lzo ubi_reader && \
    git clone https://github.com/EgorKin/Novatek-FW-info.git /opt/Novatek-FW-info

# Set working directory to the mounted host folder
WORKDIR /workspace

# Entrypoint script
CMD ["/bin/bash", "/workspace/patch_firmware.sh"]
