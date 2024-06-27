#!/usr/bin/env bash
# ---------------------------------------------------------------------------- #
#                          Function Definitions                                #
# ---------------------------------------------------------------------------- #
 if [ -d "/workspace/venv" ]; then
    echo "venv already exists [ NOT CREATING VENV ]"
    source /workspace/venv/bin/activate
    . /workspace/venv/bin/activate
  fi
start_jupyter() {
    . /workspace/venv/bin/activate
    # Allow a password to be set by providing the JUPYTER_PASSWORD environment variable
    if [[ -z ${JUPYTER_PASSWORD} ]]; then
        JUPYTER_PASSWORD=${JUPYTER_LAB_PASSWORD}
    fi

    echo "Starting Jupyter Lab..."
    mkdir -p /workspace/logs
    cd / && \
    nohup jupyter lab --allow-root \
      --no-browser \
      --port=7888 \
      --ip=* \
      --FileContentsManager.delete_to_trash=False \
      --ContentsManager.allow_hidden=True \
      --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
      --ServerApp.token="${JUPYTER_PASSWORD}" \
      --ServerApp.password="${JUPYTER_PASSWORD}" \
      --ServerApp.allow_origin=* \
      --ServerApp.preferred_dir=/workspace &> /workspace/logs/jupyter.log &
    echo "Jupyter Lab started"
}

start_cron() {
    echo "Starting Cron service..."
    service cron start &
}

start_ssh() {
    echo "Starting SSH service..."
    # Function to print in color
    print_color() {
        COLOR=$1
        TEXT=$2
        TEXT="\033[1m[SSH]\033[0m ${TEXT}"
        case $COLOR in
            "green") echo -e "\e[32m$TEXT\e[0m" ;;
            "red") echo -e "\e[31m$TEXT\e[0m" ;;
            "yellow") echo -e "\e[33m$TEXT\e[0m" ;;
            "blue") echo -e "\e[34m$TEXT\e[0m" ;;
            *) echo "$TEXT" ;;
        esac
    }

    # Check for OS Type and install SSH Server
    os_info=$(cat /etc/*release)
    print_color "yellow" "OS Detected: $os_info"

    # Check for SSH Server and install if necessary
    if ! command -v sshd >/dev/null; then
        print_color "yellow" "SSH server not found. Installing..."
        if [[ $os_info == *"debian"* || $os_info == *"ubuntu"* ]]; then
            apt-get update && apt-get install -y openssh-server
        elif [[ $os_info == *"redhat"* || $os_info == *"centos"* ]]; then
            yum install -y openssh-server
        else
            print_color "red" "Unsupported Linux distribution for automatic SSH installation."
            exit 1
        fi
        print_color "green" "SSH Server Installed Successfully."
    else
        print_color "green" "SSH Server is already installed."
    fi

    # Configure SSH to allow root login
    print_color "blue" "Configuring SSH to allow root login with a password..."
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    service ssh restart
    print_color "green" "SSH Configuration Updated."
    mkdir -p /rp-vol/ssh

    # Generate random password for root and save it
    print_color "blue" "Generating a secure random password for root..."
    root_password=$(openssl rand -base64 12)
    echo "root:$root_password" | chpasswd
    echo "$root_password" > /rp-vol/ssh/root_password.txt
    print_color "green" "Root password generated and saved"

    # Check if environment variables are set
    print_color "blue" "Checking environment variables..."
    if [ -z "$RUNPOD_PUBLIC_IP" ] || [ -z "$RUNPOD_TCP_PORT_22" ]; then
        print_color "red" "Environment variables RUNPOD_PUBLIC_IP or RUNPOD_TCP_PORT_22 are missing."
        exit 1
    fi
    print_color "green" "Environment variables are set."

    # Create connection script for Windows (.bat)
    print_color "blue" "Creating connection script for Windows..."
    echo "@echo off" > /rp-vol/ssh/connect_windows.bat
    echo "echo Root password: $root_password" >> /rp-vol/ssh/connect_windows.bat
    echo "ssh root@$RUNPOD_PUBLIC_IP -p $RUNPOD_TCP_PORT_22" >> /rp-vol/ssh/connect_windows.bat
    print_color "green" "Windows connection script created."

    # Create connection script for Linux/Mac (.sh)
    print_color "blue" "Creating connection script for Linux/Mac..."
    echo "#!/bin/bash" > /rp-vol/ssh/connect_linux.sh
    echo "echo Root password: $root_password" >> /rp-vol/ssh/connect_linux.sh
    echo "ssh root@$RUNPOD_PUBLIC_IP -p $RUNPOD_TCP_PORT_22" >> /rp-vol/ssh/connect_linux.sh
    chmod +x /rp-vol/ssh/connect_linux.sh
    print_color "green" "Linux/Mac connection script created in."

    print_color "green" "Setup Completed Successfully!"
    echo "SSH service started"
    print_color "green"  "Check \033[1m/rp-vol/ssh\033[0m for instructions/scripts for connecting"
}
start_jupyter
start_cron
start_ssh

sync_workspace() {
  echo "Syncing workspace..."
  # if directory still exists
  if [ -d "${RP_VOLUME}/StableSwarmUI" ]; then
    echo "StableSwarmUI already exists [ NOT CREATING ]"
    rm -rf "${ROOT}/StableSwarmUI"
  else
    rsync --remove-source-files -rlptDu "${ROOT}"/* "${RP_VOLUME}"
  fi

  if [ ! -d "/workspace/venv" ]; then
    echo "Creating and activating venv"
    python3 -m venv /workspace/venv
    pip install --no-cache-dir rembg matplotlib opencv_python_headless imageio-ffmpeg \
              spandrel dill ultralytics -q -q -q  &
    echo "pip installing some packages... Restart after 10 minutes of running if some packages aren't found"
  fi

  # for serverless and pods files
  ln -s /workspace /runpod-volume
  echo "Workspace is synced"
}

export_env_vars() {
    echo "Exporting environment variables..."
    printenv | grep -E '^RUNPOD_|^PATH=|^_=' | awk -F = '{ print "export " $1 "=\"" $2 "\"" }' >> /etc/rp_environment
    echo 'source /etc/rp_environment' >> ~/.bashrc
}

EXPERIMENT_FASTER_COMFYUI() {
  echo "[Faster ComfyUI] Experimenting with Faster ComfyUI..."
  echo "[Faster ComfyUI] use /rp-vol/ComfyUI as backend"
  ComfyUI_installation="${RP_VOLUME}/ComfyUI"

  # if directory not found
  if [ ! -d "${ComfyUI_installation}" ]; then
      ComfyUI_installation="${RP_VOLUME}/StableSwarmUI/dlbackend/comfy/ComfyUI"
  fi

  echo "[Faster ComfyUI] ComfyUI installation: ${ComfyUI_installation}"
  mkdir -p "${ROOT}/ComfyUI"
  rsync --progress -rltDu "${ComfyUI_installation}/models/checkpoints" "${ROOT}/ComfyUI/models/" &
  rsync --progress -rltDu --exclude="ComfyUI/models" "${RP_VOLUME}/ComfyUI" "${ROOT}/" &
  find "${RP_VOLUME}/ComfyUI/models" -mindepth 1 -maxdepth 1 -type d ! -name checkpoints \
   -exec ln -s '{}' "${ROOT}/ComfyUI/models" \;
}

start_SWui() {
    /bin/bash "${RP_VOLUME}"/StableSwarmUI/launch-linux.sh --host 0.0.0.0 --port 2254 --launch_mode none &
}

EXPERIMENT_FASTER_COMFYUI
export_env_vars
sync_workspace

echo "[MAIN] Starting SwarmUI service..."
start_SWui

echo "[MAIN] Started Services, ready!"
jupyter server list
echo "Jupyter Lab is running on port 7888"
echo "SwarmUI is running on port 2254"

sleep infinity
