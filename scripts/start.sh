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
  rsync --remove-source-files -rlptDu "${ROOT}"/* "${RP_VOLUME}"
  rm -rf "${ROOT}"
  echo "Workspace synced"
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
    . /workspace/venv/bin/activate
    pip install --upgrade --no-cache-dir --prefer-binary rembg matplotlib opencv_python_headless imageio-ffmpeg \
      spandrel dill ultralytics
    echo "Starting SWui service..."
    /bin/bash "${RP_VOLUME}"/StableSwarmUI/launch-linux.sh --host 0.0.0.0 --port 2254 --launch_mode none &
    deactivate
}
start_SWui

echo "started Services, ready!"
sleep infinity
