# frozen_string_literal: true

module RedmineScmGitlab
  class GitlabAdapter < Redmine::Scm::Adapters::AbstractAdapter
    def self.client_command
      'gitlab'
    end

    def self.client_version
      plugin = Redmine::Plugin.find(:redmine_scm_gitlab)
      plugin.version.split('.').map(&:to_i)
    end

    def initialize(url, root_url=nil, login=nil, password=nil, path_encoding=nil)
      super
      @password = password
    end

    def path_encoding
      'UTF-8'
    end

    def info
      @last_commit ||= path_to_revision('/', default_branch)
      Info.new(root_url: url, lastrev: @last_commit)
    rescue SystemCallError
      nil
    end

    def entries(path=nil, identifier=nil, options={})
      ref = identifier || default_branch

      client.tree(path, ref).map do |object|
        name = object['name']
        kind = object['type'] == 'tree' ? 'dir' : 'file'
        path = object['path']
        size = kind == 'file' ? client.filesize(path, ref) : 0
        lastrev = path_to_revision(path, ref)
        Redmine::Scm::Adapters::Entry.new(name: name, path: path, kind: kind, size: size, lastrev: lastrev)
      end
    rescue SystemCallError
      nil
    end

    def branches
      @branches ||= client.branches.sort.map do |branch|
        Redmine::Scm::Adapters::Branch.new(branch)
      end
    rescue SystemCallError
      nil
    end

    def tags
      @tags ||= client.tags.map do |tag|
        tag["name"]
      end
    rescue SystemCallError
      nil
    end

    def default_branch
      @default_branch_name ||= client.default_branch
      Redmine::Scm::Adapters::Branch.new(@default_branch_name)
    rescue SystemCallError
      Redmine::Scm::Adapters::Branch.new('main')
    end

    def diff(path, identifier_from, identifier_to=nil)
      diff = []

      ret = if identifier_to.blank?
              client.diff(identifier_from)
            else
              client.compare(identifier_to, identifier_from)['diffs']
            end

      diff = []
      ret.map do |d|
        if path.blank? || path == '.' || path == d['new_path']
          old_path = d['new_file'] ? '/dev/null' : d['old_path']
          new_path = d['deleted_file'] ? '/dev/null' : d['new_path']
          diff += "diff\n--- a/#{old_path}\n+++ b/#{new_path}".split("\n")
          diff += d['diff'].split("\n")
        end
      end
      diff
    rescue SystemCallError
      nil
    end

    def cat(path, identifier=nil)
      ref = identifier || default_branch
      client.blob(path, ref)['rawTextBlob']
    rescue SystemCallError
      nil
    end

    def annotate(path, identifier=nil)
      ref = identifier || default_branch
      lines = Redmine::Scm::Adapters::Annotate.new
      client.blame(path, ref).map do |content|
        revision = commit_to_revision(content['commit'])
        content['lines'].map do |line|
          lines.add_line(line, revision)
        end
      end
      lines
    rescue SystemCallError
      nil
    end

    def valid_name?(name)
      return false unless name.is_a?(String)

      true
    end

    def revision_scmids(path, rev, limit=10)
      client.commits(path, rev, limit, nil, false).map  do |commit|
        commit['id']
      end
    rescue SystemCallError => e
      raise Redmine::Scm::Adapters::CommandFailed.new(e.message)
    end

    def revisions(since, limit)
      client.commits(nil, nil, limit, since, true).map  do |commit|
        sha = commit['id']
        author = commit['author_name']
        time = Time.iso8601(commit['committed_date'])
        message = commit['message']
        paths = []
        parents = commit['parent_ids']

        client.diff(sha).map do |d|
          new_file = d['new_file']
          deleted_file = d['deleted_file']
          renamed_file = d['renamed_file']
          path = {
            action: if new_file
                      'A'
                    elsif deleted_file
                      'D'
                    else
                      renamed_file ? 'R' : 'M'
                    end,
            path: d['new_path'],
          }
          path['from_path'] = d['old_path'] if d['old_path'].present?
          paths.push(path)
        end

        Revision.new(
          identifier: sha,
          scmid: sha,
          author: author,
          time: time,
          message: message,
          paths: paths,
          parents: parents)
      end
    rescue SystemCallError => e
      raise Redmine::Scm::Adapters::CommandFailed.new(e.message)
    end

    private

    def commit_to_revision(commit)
      author = commit['author_name']
      time = Time.iso8601(commit['committed_date'])
      message = commit['message']
      id = commit['id']
      Revision.new(identifier: id, scmid: id, author: author, time: time, message: message)
    end

    def path_to_revision(path, ref)
      # TODO: time is not `committed_date`.
      commit = client.last_commit(path, ref)
      author = commit['authorName']
      time = Time.iso8601(commit['authoredDate'])
      message = commit['message']
      id = commit['sha']
      Revision.new(identifier: id, scmid: id, author: author, time: time, message: message)
    end

    def client
      @client ||= create_client
    end

    def create_client
      project = URI.parse("#{url.chomp('/')}/").normalize
      root = URI.parse("#{root_url.chomp('/')}/").normalize
      project_path = (project - root).path.chomp('/')
      RedmineScmGitlab::GitlabClient.new(root.to_s, project_path, @password, true)
    end
  end

  class Revision < Redmine::Scm::Adapters::Revision
    def format_identifier
      identifier[0, 8]
    end
  end
end
