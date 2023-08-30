set -eo pipefail

export TERM=dumb
export TZ=Etc/UTC
export DEBIAN_FRONTEND=noninteractive
# https://askubuntu.com/questions/1367139/apt-get-upgrade-auto-restart-services

# based on https://gist.github.com/sj26/88e1c6584397bb7c13bd11108a579746?permalink_comment_id=4155247#gistcomment-4155247
function retry {
  local retries=$1
  shift
  local cmd=($@)
  local cmd_string="${@}"
  local count=0

  # be lenient with non-zero exit codes, to allow retries
  set +o errexit
  set +o pipefail
  until "${cmd[@]}"; do
    retcode=$?
    wait=$(( 2 ** count ))
    count=$(( count + 1))
    if [[ $count -le $retries ]]; then
      printf "Command [%s] failed. Retry [%d/%d] in [%d] seconds.\n" "$cmd_string" $count $retries $wait
      sleep $wait
    else
      printf "Exhausted all [%s] retries for command [%s]. Exiting.\n" "$cmd_string" $retries
      # restore settings to fail immediately on error
      set -o errexit
      set -o pipefail
      return $retcode
    fi
  done
  # restore settings to fail immediately on error
  set -o errexit
  set -o pipefail
  return 0
}
function collect_ps_info {
  [ -d /home/elastic/.rally/logs ] || mkdir -p /home/elastic/.rally/logs
  sudo apt install procps -y
  while true
  do
    date >> /home/elastic/.rally/logs/ps_info.log
    ps -ef >> /home/elastic/.rally/logs/ps_info.log
    pstree >> /home/elastic/.rally/logs/ps_info.log
    sleep 60
  done
}
echo "--- System dependencies"
export TERM=dumb
sudo apt update
sudo apt-get -y install openjdk-17-jdk-headless
export JAVA17_HOME=/usr/lib/jvm/java-17-openjdk-amd64

python -m pip install .[develop]

collect_ps_info &

echo "--- Run IT test"

hatch -v -e it run test
