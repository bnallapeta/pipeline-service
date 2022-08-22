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

images=(
 "access-setup"
 "argocd-registrar"
 "cluster-setup"
 "gateway-deployment"
 "kcp-registrar"
 "shellcheck"
)

get_digest() {
  #number of retries=3
  for _ in {1..3}
  do
    #Get the digest of the image
    digest_http_code=$(curl -s -w '%{http_code}' -o /tmp/digest.json -H "Accept: application/vnd.quay.distribution.manifest.v2+json Content-type: application/json Authorization: Bearer           $AUTH_BEARER_TOKEN " https://quay.io/api/v1/repository/redhat-pipeline-service/"$img")

    if [[ "$digest_http_code" == "200" ]]; then
      digest=$(jq '.tags[] | select(.name == "main").manifest_digest ' /tmp/digest.json | tr -d '"')
      rm -f /tmp/digest.json
      get_vulnerabilities
      break
    else
      printf "Error while fetching digests from Quay. Status code: %s\n" "${digest_http_code}"
    fi
  done
}

get_vulnerabilities() {
  #Scan for vulnerabilities
  results_http_code=$(curl -s -w '%{http_code}' -o /tmp/vulnerability.json -H "Content-type: application/json Authorization: Bearer $AUTH_BEARER_TOKEN" https://quay.io/api/v1/repository/redhat-pipeline-service/"$img"/manifest/"$digest"/security?vulnerabilities=true)

  if [[ "$results_http_code" == "200" ]]; then
    printf "\n *********************************** \n"
    printf " \t %s results " "$img"
    printf "\n *********************************** \n"

    #Filtering results with vulnerabilities only.
    results=$(jq -r '.data.Layer.Features[].Vulnerabilities[]' /tmp/vulnerability.json)

    if [[ -n $results ]]; then
      printf "%s" "$results" | jq
      printf "\n Check the full report here: https://quay.io/repository/redhat-pipeline-service/%s/manifest/%s?tab=vulnerabilities \n" "$img" "$digest"
      export VULNERABILITIES_EXIST=true
    else
      printf "No vulnerabilities found! \n"
    fi

    rm -f /tmp/vulnerability.json
    return
  else
    printf "Error while fetching vulnerability report from Quay. Status code: %s\n" "${results_http_code}"
  fi
}

main() {
  for img  in "${images[@]}"; do
      get_digest
  done
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi