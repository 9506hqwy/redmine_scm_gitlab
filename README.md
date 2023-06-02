# Redmine Scm GitLab

This plugin provides a GitLab repository integration.

## Features

- Add GitLab repository to Redmine.

## Installation

1. Download plugin in Redmine plugin directory.
   ```sh
   git clone https://github.com/9506hqwy/redmine_scm_gitlab.git
   ```
2. Install dependency libraries in Redmine directory.
   ```sh
   bundle install --without development test
   ```
3. Start Redmine

## Configuration

1. Enable GitLab version control system.

   Check on [GitLab] in [Repository] tab in Redmine setting.

2. Add GitLab repository to the project.

   Add new repository in [Repository] tab in project setting.

## Notes

- Token need to have `read_repository` scope.

## Tested Environment

* Redmine (Docker Image)
  * 3.4
  * 4.0
  * 4.1
  * 4.2
  * 5.0
* Database
  * SQLite
  * MySQL 5.7
  * PostgreSQL 12
* GitLab
  * 15.11
