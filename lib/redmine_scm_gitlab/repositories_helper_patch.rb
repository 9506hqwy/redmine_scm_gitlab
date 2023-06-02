# frozen_string_literal: true

module RedmineScmGitlab
  module RepositoriesHelperPatch
    def git_lab_field_tags(form, repository)
      root_url_field = form.text_field(
        :root_url,
        size: 60,
        required: true,
        label: l(:field_gitlab_root_url), # for Redmine3.x
        disabled: !repository.safe_attribute?('root_url'))

      root_url_hint = content_tag('em', l(:text_gitlab_root_url_note), class: 'info')

      root_url_content = content_tag(
        'p',
        root_url_field + root_url_hint)

      project_url_field = form.text_field(
        :url,
        size: 60,
        required: true,
        label: l(:field_gitlab_project_url), # for Redmine3.x
        disabled: !repository.safe_attribute?('url'))

      project_url_hint = scm_path_info_tag(repository)

      project_url_content = content_tag(
        'p',
        project_url_field + project_url_hint)

      token_field = form.password_field(
        :password,
        size: 60,
        required: true,
        name: 'ignore',
        label: l(:label_scm_gitlab_token),
        value: ((repository.new_record? || repository.password.blank?) ? '' : ('x'*15)),
        onfocus: "this.value=''; this.name='repository[password]';",
        onchange: "this.name='repository[password]';")

      token_content = content_tag(
        'p',
        token_field)

      root_url_content + project_url_content + token_content
    end
  end
end

Rails.application.config.after_initialize do
  RepositoriesController.send(:helper, RedmineScmGitlab::RepositoriesHelperPatch)
end
