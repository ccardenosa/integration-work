#!/bin/bash

ASSETS_DIR=/opt/assets

function check_for_issues {
  docker_conf=~/.docker/config.json
  if [ -f $docker_conf ];then
    diff -u "${XDG_RUNTIME_DIR}"/containers/auth.json $docker_conf > /dev/null
    if [ $? -ne 0 ];then
      echo "The content of these two files are different:"
      echo "   1. $docker_conf"
      echo "   2. ${XDG_RUNTIME_DIR}/containers/auth.json"
      echo
      echo "If $docker_conf exists, the content of ${XDG_RUNTIME_DIR}/containers/auth.json won't be considered"
      echo "This might cause auth issues since incorrect file is being used by oc-mirror tool."
    fi
  fi
}

# 1) Get oc-mirror tool
printf "\n========================\n"
printf "| Get ./oc-mirror tool |\n"
printf "========================\n\n"

curl -s -L https://mirror.openshift.com/pub/openshift-v4/amd64/clients/ocp-dev-preview/pre-release/oc-mirror.tar.gz | tar xvz -C /usr/bin
chmod +x /usr/bin/oc-mirror
oc-mirror version


# 2) Mirror OpenShift release
printf "\n============================\n"
printf "| Mirror OpenShift release | --> 4.10 (Telco) & 4.11 (Integration)\n"
printf "============================\n\n"

mkdir -pv ${ASSETS_DIR}/ISC ${ASSETS_DIR}/ICSP "${XDG_RUNTIME_DIR}"/containers
cp "${LOCAL_SECRET_JSON}" "${XDG_RUNTIME_DIR}"/containers/auth.json
podman login -u init -p "adrogallop" "$(hostname -f)":8443

cat << EOF > ${ASSETS_DIR}/ISC/99-ocp-release.yaml
apiVersion: mirror.openshift.io/v1alpha2
kind: ImageSetConfiguration
storageConfig:
  registry:
    imageURL: $(hostname -f):8443/ocp4

mirror:
  platform:
    channels:
      # Latest available version (for internal integration work).
      - name: stable-$(echo $OCP_RELEASE_VERSION | cut -d'.' -f1-2)
        minVersion: '${OCP_RELEASE_VERSION}'
    graph: false

  additionalimages:
    - name: registry.redhat.io/openshift4/ztp-site-generate-rhel8:latest    # required for ZTP solutions
    - name: quay.io/lochoa/netshoot                                         # required for network troubleshooting
EOF

oc-mirror --config ${ASSETS_DIR}/ISC/99-ocp-release.yaml \
          --max-per-registry 5 \
          docker://"$(hostname -f)":8443/ocp4

if [ $? -ne 0 ];then
  check_for_issues
fi

# 3) Clean up all temporal artifacts
printf "\n===================================\n"
printf "| Clean up all temporal artifacts |\n"
printf "===================================\n\n"

sudo cp -v ./oc-mirror-workspace/results-*/imageContentSourcePolicy.yaml ${ASSETS_DIR}/ICSP/99-ocp-release.yml

rm -rfv oc-mirror-workspace
