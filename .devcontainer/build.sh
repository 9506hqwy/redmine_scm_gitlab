#!/bin/bash
set -euo pipefail

REDMINE_URL=https://github.com/redmine/redmine.git

sudo apt update
sudo apt install -y imagemagick

sudo mkdir "${REDMINE_HOME}"
sudo chmod 777 "${REDMINE_HOME}"

pushd "${REDMINE_HOME}"

git clone --depth 1 -b 5.0-stable "${REDMINE_URL}" 5.0
git clone --depth 1 -b 5.1-stable "${REDMINE_URL}" 5.1
git clone --depth 1 -b 6.0-stable "${REDMINE_URL}" 6.0

for BASE in $(ls)
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
