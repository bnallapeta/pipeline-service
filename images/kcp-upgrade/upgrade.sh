#!/usr/bin/env bash

# Copyright 2022 The Pipeline Service Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

# get the current version of kcp on our repo
# check if there is a later version of kcp from kcp releases
# replace version in the below list of files if we find a later version of kcp
  # files
  # .github/workflows/build-push-images.yaml
  # .github/workflows/local-dev-ci.yaml
  # DEPENDENCIES.md
  # ckcp/openshift/overlays/dev/kustomization.yaml
  # docs/kcp-registration.md
  # images/kcp-registrar/register.sh
# if latest version matches the current version in our repo, exit the script.
  # if exit does not trigger the next steps, then we are good, but if it triggers, then we need to output some var and then execute based on that

SCRIPT_DIR="$(
  cd "$(dirname "$0")" >/dev/null
  pwd
)"
CONFIG="$(dirname "$(dirname "$SCRIPT_DIR")")/config/config.yaml"
current_kcp_version="$(yq '.KCP_VERSION' "$CONFIG")"

latest_kcp_version=$(curl -s https://api.github.com/repos/kcp-dev/kcp/releases/latest | yq '.tag_name')

if [[ "$current_kcp_version" != "$latest_kcp_version" ]]; then
  sed -i "s,$current_kcp_version,$latest_kcp_version,g" .github/workflows/build-push-images.yaml
  sed -i "s,$current_kcp_version,$latest_kcp_version,g" .github/workflows/local-dev-ci.yaml
  sed -i "s,$current_kcp_version,$latest_kcp_version,g" DEPENDENCIES.md
  sed -i "s,$current_kcp_version,$latest_kcp_version,g" ckcp/openshift/overlays/dev/kustomization.yaml
  sed -i "s,$current_kcp_version,$latest_kcp_version,g" docs/kcp-registration.md
  sed -i "s,$current_kcp_version,$latest_kcp_version,g" images/kcp-registrar/register.sh
else
  exit 1
fi