#!/usr/bin/env bash
# ---------------------------------------------------------------------------- #
#                          Function Definitions                                #
# ---------------------------------------------------------------------------- #
start_nginx() {
    echo "Starting Nginx service..."
    systemctl start nginx &
}

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
    service ssh start &
}

sync_workspace() {
  echo "Syncing workspace..."
  # if directory still exists
  if [ -d "${RP_VOLUME}/StableSwarmUI" ]; then
    echo "StableSwarmUI already exists [ NOT CREATING ]"
    rm -rf "${ROOT}/StableSwarmUI" &
    if [ -d "${RP_VOLUME}/ComfyUI" ]; then
      echo "Fast Start: use /rp-vol/ComfyUI"
      echo "Copying ComfyUI"
      mkdir -p "${ROOT}/ComfyUI"
      rsync --progress -rltDu --exclude="models" "${RP_VOLUME}/ComfyUI" "${ROOT}/"
      ln -s "${ROOT}/ComfyUI/models" "${RP_VOLUME}/ComfyUI/models"
    fi
  else
    rsync --remove-source-files -rlptDu "${ROOT}"/* "${RP_VOLUME}"
  fi

  echo "Creating and activating venv"
  # shellcheck disable=SC2164
  cd /workspace
  if [ -d "venv" ]; then
    echo "venv already exists [ NOT CREATING VENV ]"
    source /workspace/venv/bin/activate
    . /workspace/venv/bin/activate
  else
    python3 -m venv /workspace/venv
    pip install --no-cache-dir rembg matplotlib opencv_python_headless imageio-ffmpeg \
              spandrel dill ultralytics -q -q -q  &
    echo "pip installing some packages... Restart after 10 minutes of running if some packages aren't found"
  fi

  # for serverless and pods files
  ln -s /workspace /runpod-volume
  echo "Workspace is synced"
}

#call the functions
start_nginx
start_jupyter
update_rclone
start_cron
start_ssh

export_env_vars() {
    echo "Exporting environment variables..."
    printenv | grep -E '^RUNPOD_|^PATH=|^_=' | awk -F = '{ print "export " $1 "=\"" $2 "\"" }' >> /etc/rp_environment
    echo 'source /etc/rp_environment' >> ~/.bashrc
}

export_env_vars
sync_workspace

start_SWui() {
    echo "Starting SwarmUI service..."
    /bin/bash "${RP_VOLUME}"/StableSwarmUI/launch-linux.sh --host 0.0.0.0 --port 2254 --launch_mode none &
}
start_SWui

echo "started Services, ready!"
jupyter server list
echo "Jupyter Lab is running on port 7888"
echo "StableSwarmUI is running on port 2254"

sleep infinity
