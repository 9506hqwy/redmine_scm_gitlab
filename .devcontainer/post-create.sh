#!/bin/bash
set -euo pipefail

PLUGIN_DIR=$(pwd)

pushd ${REDMINE_HOME}

for BASE in $(ls)
do
    pushd ${BASE}

    ln -s ${PLUGIN_DIR} plugins/${PLUGIN_NAME}

    popd
done
