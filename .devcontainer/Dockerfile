FROM mcr.microsoft.com/devcontainers/ruby:3.1-bookworm

ENV RAILS_ENV=development \
    REDMINE_HOME=/usr/src/redmine

RUN --mount=type=bind,target=/src,Z \
    sudo -E -u vscode /src/build.sh

EXPOSE 3000/tcp
