#!/bin/bash
set -euo pipefail
# set -x

mapfile -t keep_files < /tmp/ansible-filelist

while IFS= read -r -d '' file; do
  if [[ ! " ${keep_files[*]} " =~ " $file" ]]; then
    echo "Deleting: $file"
    rm "$file"
  fi
done < <(find /var/ansible -type f -print0)
