#!/bin/bash
set -euo pipefail

# Install dependencies
sudo apt-get update -y
sudo apt-get install -y imagemagick nodejs npm shellcheck zstd

# Configuration PATH
mkdir -p ~/.local/bin
# shellcheck disable=SC2016
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc

# Common
GITHUB_HEADER_ACCEPT="Accept: application/vnd.github+json"
GITHUB_HEADER_VERSION="X-GitHub-Api-Version: 2022-11-28"

# Install actionlint
ACTIONLIN_URL="https://api.github.com/repos/rhysd/actionlint/releases?per_page=1"
ACTIONLINT_VERSION=$(curl -fsSL -H "${GITHUB_HEADER_ACCEPT}" -H "${GITHUB_HEADER_VERSION}" "${ACTIONLIN_URL}" | jq -r '.[0].tag_name')
curl -fsSL -o - "https://github.com/rhysd/actionlint/releases/download/${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION#v}_linux_amd64.tar.gz" | \
    tar -zxf - -O "actionlint" > ~/.local/bin/actionlint
chmod +x ~/.local/bin/actionlint

# Install bat
BAT_URL="https://api.github.com/repos/sharkdp/bat/releases?per_page=1"
BAT_VERSION=$(curl -fsSL -H "${GITHUB_HEADER_ACCEPT}" -H "${GITHUB_HEADER_VERSION}" "${BAT_URL}" | jq -r '.[0].tag_name')
curl -fsSL -o - "https://github.com/sharkdp/bat/releases/download/${BAT_VERSION}/bat-${BAT_VERSION}-x86_64-unknown-linux-gnu.tar.gz" | \
    tar -zxf - -O "bat-${BAT_VERSION}-x86_64-unknown-linux-gnu/bat" > ~/.local/bin/bat
chmod +x ~/.local/bin/bat

# Install delta
DELTA_URL="https://api.github.com/repos/dandavison/delta/releases?per_page=1"
DELTA_VERSION=$(curl -fsSL -H "${GITHUB_HEADER_ACCEPT}" -H "${GITHUB_HEADER_VERSION}" "${DELTA_URL}" | jq -r '.[0].tag_name')
curl -fsSL -o - "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu.tar.gz" | \
    tar -zxf - -O "delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu/delta" > ~/.local/bin/delta
chmod +x ~/.local/bin/delta

# Install edit
#EDIT_URL="https://api.github.com/repos/microsoft/edit/releases?per_page=1"
EDIT_VERSION="v1.2.0"
curl -fsSL -o - "https://github.com/microsoft/edit/releases/download/${EDIT_VERSION}/edit-${EDIT_VERSION#v}-x86_64-linux-gnu.tar.zst" | \
    tar --zstd -xf - -O "edit" > ~/.local/bin/edit
chmod +x ~/.local/bin/edit

# Install lefthook
LEFTHOOK_URL="https://api.github.com/repos/evilmartians/lefthook/releases?per_page=1"
LEFTHOOK_VERSION=$(curl -fsSL -H "${GITHUB_HEADER_ACCEPT}" -H "${GITHUB_HEADER_VERSION}" "${LEFTHOOK_URL}" | jq -r '.[0].tag_name')
curl -fsSL -o - "https://github.com/evilmartians/lefthook/releases/download/${LEFTHOOK_VERSION}/lefthook_${LEFTHOOK_VERSION#v}_Linux_x86_64.gz" | \
    gzip -c -d > ~/.local/bin/lefthook
chmod +x ~/.local/bin/lefthook

# Install yq
YQ_URL="https://api.github.com/repos/mikefarah/yq/releases?per_page=1"
YQ_VERSION=$(curl -fsSL -H "${GITHUB_HEADER_ACCEPT}" -H "${GITHUB_HEADER_VERSION}" "${YQ_URL}" | jq -r '.[0].tag_name')
curl -fsSL -o - "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz" | \
    tar -zxf - -O "./yq_linux_amd64" > ~/.local/bin/yq
chmod +x ~/.local/bin/yq

# Setup redmine plugin
REDMINE_URL=https://github.com/redmine/redmine.git

sudo mkdir "${REDMINE_HOME}"
sudo chown vscode:vscode "${REDMINE_HOME}"
sudo chmod 755 "${REDMINE_HOME}"

pushd "${REDMINE_HOME}"

git clone --depth 1 -b 5.1-stable "${REDMINE_URL}" 5.1
git clone --depth 1 -b 6.0-stable "${REDMINE_URL}" 6.0
git clone --depth 1 -b 6.1-stable "${REDMINE_URL}" 6.1

for BASE in ./*
do
    pushd "${BASE}"

    cat >config/database.yml <<EOF
production:
  adapter: sqlite3
  database: db/redmine.sqlite

development:
  adapter: sqlite3
  database: db/redmine_dev.sqlite

test:
  adapter: sqlite3
  database: db/redmine_test.sqlite3
EOF

    echo "gem 'debug'" > Gemfile.local

    bundle install --with development test
    bundle exec rake generate_secret_token
    bundle exec rake db:migrate
    echo ja | bundle exec rake redmine:load_default_data

    popd
done

popd
