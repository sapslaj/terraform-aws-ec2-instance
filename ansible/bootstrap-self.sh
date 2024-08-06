#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
if command -v apt-get &>/dev/null ; then
  apt-get update
  apt-get install -y git ansible
else
  echo "Unsupported platform: $(lsb_release -a)"
  exit 1
fi
pushd "$(dirname "$(realpath "$0")")"
[[ -s requirements.yml ]] && ansible-galaxy install -r requirements.yml
ansible-playbook -i localhost, main.yml "$@"
popd
