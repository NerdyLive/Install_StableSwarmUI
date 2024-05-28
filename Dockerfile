# Main image
FROM nvcr.io/nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1

ENV ROOT="/workspace"
ENV HF_DATASETS_CACHE="/runpod-volume/huggingface-cache/datasets" \
    HUGGINGFACE_HUB_CACHE="/runpod-volume/huggingface-cache/hub" \
    HF_HOME="/runpod-volume/huggingface-cache" \
    HF_TRANSFER=1

# Update apps
RUN --mount=type=cache,id=dev-apt-cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,id=dev-apt-lib,sharing=locked,target=/var/lib/apt \
	apt update && \
    apt upgrade -y && \
    apt install -y \
      python3-pip \
      fonts-dejavu-core \
      rsync \
      git \
      jq \
      moreutils \
      aria2 \
      wget \
      curl \
      libglib2.0-0 \
      libsm6 \
      libgl1 \
      libxrender1 \
	  libjpeg-dev \
      libpng-dev \
      libxext6 \
      ffmpeg \
      libglfw3-dev libgles2-mesa-dev pkg-config \
      libcairo2 libcairo2-dev \
      libgoogle-perftools4 \
      libtcmalloc-minimal4 \
      build-essential \
      procps

# Install Python dependencies
RUN pip install --upgrade pip setuptools pickleshare --no-cache-dir --prefer-binary

# Upgrade apt packages and install required dependencies

ARG TCMALLOC="/usr/lib/x86_64-linux-gnu/libtcmalloc.so.4"
ENV LD_PRELOAD=${TCMALLOC}

RUN mkdir -vp ${ROOT}/.cache

# Cleanup section (Worker Template)
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# Set Python
RUN ln -s /usr/bin/python3.11 /usr/bin/python
RUN pip cache purge

# Build files
WORKDIR ${ROOT}

ENV NVIDIA_VISIBLE_DEVICES=all

RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
RUN /bin/bash -c 'chmod +x dotnet-install.sh'
RUN ./dotnet-install.sh --channel 7.0
RUN ./dotnet-install.sh --channel 8.0

# remove the dotnet-install
RUN rm dotnet-install.sh

# clone the github repo
RUN git clone https://github.com/Stability-AI/StableSwarmUI.git

WORKDIR ${ROOT}/StableSwarmUI
RUN git pull

# START
ENTRYPOINT ["/bin/bash", "--host 0.0.0.0", "--port 2254", "--launch_mode none"]
