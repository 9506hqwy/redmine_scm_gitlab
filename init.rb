# frozen_string_literal: true

basedir = File.expand_path('../lib', __FILE__)
libraries =
  [
    'redmine_scm_gitlab/gitlab_adapter',
    'redmine_scm_gitlab/gitlab_client',
    'redmine_scm_gitlab/repositories_helper_patch',
  ]

libraries.each do |library|
  require_dependency File.expand_path(library, basedir)
end

Redmine::Plugin.register :redmine_scm_gitlab do
  name 'Redmine Scm Gitlab plugin'
  author '9506hqwy'
  description 'This is a gitlab plugin for Redmine'
  version '0.1.0'
  url 'https://github.com/9506hqwy/redmine_scm_gitlab'
  author_url 'https://github.com/9506hqwy'

  Redmine::Scm::Base.add 'GitLab'
end
