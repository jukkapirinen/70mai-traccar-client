# Novatek Firmware Info Docker Usage

This guide provides instructions for cloning, building, and running the `novatek-fw-info` in a Docker container.

## Clone the Repository

First, clone the `Novatek-FW-info` repository from GitHub:

```bash
git clone https://github.com/EgorKin/Novatek-FW-info.git
cd Novatek-FW-info
```

## Build the Docker Image

Make sure you're in the cloned repository directory where the `Dockerfile` is located, then run:

```bash
sudo docker build -t novatek-fw-info .
```

## Run the Docker Container


```bash
sudo docker run -it --rm \
  -v .:/workspace \
  --user root \
  novatek-fw-info
```

> **Note:** The `-v .:/workspace` option mounts the **current directory** of your current working directory into the container at `/workspace`.

