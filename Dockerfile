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

ENV ROOT="/rp-vol" \
	RP_VOLUME="/workspace"
ENV HF_DATASETS_CACHE="/runpod-volume/huggingface-cache/datasets" \
    HUGGINGFACE_HUB_CACHE="/runpod-volume/huggingface-cache/hub" \
    HF_HOME="/runpod-volume/huggingface-cache" \
    HF_TRANSFER=1

# Update apps
RUN --mount=type=cache,id=dev-apt-cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,id=dev-apt-lib,sharing=locked,target=/var/lib/apt \
	apt update && \
    apt upgrade -y && \
    apt install -y --no-install-recommends \
        build-essential \
        software-properties-common \
        python3.10-venv \
        python3-pip \
        python3-tk \
        python3-dev \
        nodejs \
        npm \
        bash \
        dos2unix \
        git \
        git-lfs \
        ncdu \
        nginx \
        net-tools \
        dnsutils \
        inetutils-ping \
        openssh-server \
        libglib2.0-0 \
        libsm6 \
        libgl1 \
        libxrender1 \
        libxext6 \
        ffmpeg \
        wget \
        curl \
        psmisc \
        rsync \
        vim \
        zip \
        unzip \
        p7zip-full \
        htop \
        screen \
        tmux \
        bc \
        aria2 \
        cron \
        pkg-config \
        plocate \
        libcairo2-dev \
        libgoogle-perftools4 \
        libtcmalloc-minimal4 \
        apt-transport-https \
        ca-certificates

RUN update-ca-certificates

# Install dependencies
RUN pip install -U --no-cache-dir jupyterlab \
        jupyterlab_widgets \
        ipykernel \
        ipywidgets \
        gdown \
        OhMyRunPod --no-cache-dir --prefer-binary

RUN curl https://rclone.org/install.sh | bash

 # Update rclone
RUN rclone selfupdate
RUN curl https://getcroc.schollz.com | bash
RUN curl -s  \
    https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh \
    | bash && \
        apt install -y speedtest

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

# clone the github repo
RUN git clone https://github.com/Stability-AI/StableSwarmUI.git

WORKDIR ${ROOT}/StableSwarmUI
RUN cd launchtools && rm dotnet-install.sh && \
    # https://learn.microsoft.com/en-us/dotnet/core/install/linux-scripted-manual#scripted-install
    wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 8.0 --runtime aspnetcore && \
    ./dotnet-install.sh --channel 8.0

# Install the required python packages
ENV SWARM_NO_VENV = "true"


COPY --chmod=755 ./scripts/* ./

# START
CMD ["./start.sh"]
