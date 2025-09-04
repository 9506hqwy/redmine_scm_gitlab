#!/bin/bash
set -euo pipefail

# Install dependencies
sudo apt-get update -y
sudo apt-get install -y imagemagick shellcheck zstd

# Configuration PATH
mkdir -p ~/.local/bin
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc

# Install actionlint
ACTIONLINT_VERSION=1.7.7
curl -fsSL -o - "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz" | \
    tar -zxf - -O "actionlint" > ~/.local/bin/actionlint
chmod +x ~/.local/bin/actionlint

# Install bat
BAT_VERSION=0.25.0
curl -fsSL -o - "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat-v${BAT_VERSION}-i686-unknown-linux-gnu.tar.gz" | \
    tar -zxf - -O "bat-v${BAT_VERSION}-i686-unknown-linux-gnu/bat" > ~/.local/bin/bat
chmod +x ~/.local/bin/bat

# Install delta
DELTA_VERSION=0.18.2
curl -fsSL -o - "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu.tar.gz" | \
    tar -zxf - -O "delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu/delta" > ~/.local/bin/delta
chmod +x ~/.local/bin/delta

# Install edit
EDIT_VERSION=1.2.0
curl -fsSL -o - "https://github.com/microsoft/edit/releases/download/v${EDIT_VERSION}/edit-${EDIT_VERSION}-x86_64-linux-gnu.tar.zst" | \
    tar --zstd -xf - -O "edit" > ~/.local/bin/edit
chmod +x ~/.local/bin/edit

# Install lefthook
LEFTHOOK_VERSION=1.11.13
curl -fsSL -o - "https://github.com/evilmartians/lefthook/releases/download/v${LEFTHOOK_VERSION}/lefthook_${LEFTHOOK_VERSION}_Linux_x86_64.gz" | \
    gzip -c -d > ~/.local/bin/lefthook
chmod +x ~/.local/bin/lefthook

# Install yq
YQ_VERSION=4.45.4
curl -fsSL -o - "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64.tar.gz" | \
    tar -zxf - -O "./yq_linux_amd64" > ~/.local/bin/yq
chmod +x ~/.local/bin/yq

# Setup redmine plugin
REDMINE_URL=https://github.com/redmine/redmine.git

sudo mkdir "${REDMINE_HOME}"
sudo chmod 755 "${REDMINE_HOME}"

pushd "${REDMINE_HOME}"

git clone --depth 1 -b 5.0-stable "${REDMINE_URL}" 5.0
git clone --depth 1 -b 5.1-stable "${REDMINE_URL}" 5.1
git clone --depth 1 -b 6.0-stable "${REDMINE_URL}" 6.0

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
