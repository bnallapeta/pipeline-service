#!/usr/bin/env bash

# Copyright 2022 The pipelines-service Authors.
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

usage() {

    printf "Usage: ARGO_URL="https://argoserver.com" ARGO_USER="user" ARGO_PWD="xxxxxxxxx" DATA_DIR="/workspace" ./register.sh\n\n"

    # Parameters
    printf "The following parameters need to be passed to the script:\n"
    printf "ARGO_URL: the address of the Argo CD server the clusters need to be registered to\n"
    printf "ARGO_USER: the user for the authentication\n"
    printf "ARGO_PWD: the password for the authentication\n"
    printf "DATA_DIR: the location of the cluster files\n"
    printf "INSECURE (optional): whether insecured connection to Argo CD should be allowed. Default value: false\n\n"
}

prechecks () {
    if ! command -v argocd &> /dev/null; then
        printf "Argocd CLI could not be found\n"
    	exit 1
    fi
    ARGO_URL=${ARGO_URL:-}
    if [[ -z "${ARGO_URL}" ]]; then
        printf "ARGO_URL not set\n\n"
        usage
        exit 1
    fi
    ARGO_USER=${ARGO_USER:-}
    if [[ -z "${ARGO_USER}" ]]; then
        printf "ARGO_USER not set\n\n"
        usage
	exit 1
    fi
    ARGO_PWD=${ARGO_PWD:-}
    if [[ -z "${ARGO_PWD}" ]]; then
	printf "ARGO_PWD not set\n\n"
        usage
	exit 1
    fi
    DATA_DIR=${DATA_DIR:-}
    if [[ -z "${DATA_DIR}" ]]; then
        printf "DATA_DIR not set\n\n"
        usage
	exit 1
    fi
    INSECURE=${INSECURE:-}
    if [[ $(tr '[:upper:]' '[:lower:]' <<< "$INSECURE") == "true" ]]; then
	printf "insecured connection to Argo CD allowed!\n"
        insecure="--insecure"
    else
        insecure=""
    fi
}

main() {
  prechecks
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi