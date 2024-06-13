#!/usr/bin/env bash
# ---------------------------------------------------------------------------- #
#                          Function Definitions                                #
# ---------------------------------------------------------------------------- #

start_nginx() {
    echo "Starting Nginx service..."
    systemctl start nginx
}

start_jupyter() {
    # Default to not using a password
    JUPYTER_PASSWORD=""

    # Allow a password to be set by providing the JUPYTER_PASSWORD environment variable
    if [[ ${JUPYTER_LAB_PASSWORD} ]]; then
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
      --ServerApp.allow_origin=* \
      --ServerApp.preferred_dir=/workspace &> /workspace/logs/jupyter.log &
    echo "Jupyter Lab started"
}

update_rclone() {
    echo "Updating rclone..."
    rclone selfupdate
}

start_cron() {
    echo "Starting Cron service..."
    service cron start
}

start_ssh() {
    echo "Starting SSH service..."
    service ssh start
}

sync_workspace() {
  echo "Syncing workspace..."
  # if directory still exists
  if [ -d "${RP_VOLUME}/StableSwarmUI" ]; then
    echo "StableSwarmUI already exists [ NOT CREATING ]"
  else
    rsync --remove-source-files -rlptDu "${ROOT}"/* "${RP_VOLUME}"
  fi
  echo "Workspace synced"

  echo "Creating and activating venv"
  # shellcheck disable=SC2164
  cd /workspace
  if [ -d "venv" ]; then
    echo "venv already exists [ NOT CREATING VENV ]"
  else
  python3 -m venv /workspace/venv
  fi

  # for serverless and pods files
  ln -s /workspace /runpod-volume

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
sleep 2

start_SWui() {
    echo "Installing SWui dependencies.."
      . /workspace/venv/bin/activate

    pip install --no-cache-dir rembg matplotlib opencv_python_headless imageio-ffmpeg \
      spandrel dill ultralytics
    echo "Starting SWui service..."
    /bin/bash "${RP_VOLUME}"/StableSwarmUI/launch-linux.sh --host 0.0.0.0 --port 2254 --launch_mode none &
}
start_SWui

echo "started Services, ready!"
sleep infinity
