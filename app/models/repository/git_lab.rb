# frozen_string_literal: true

class Repository::GitLab < Repository
  validates_presence_of(:root_url, :url, :password)

  safe_attributes('root_url', if: lambda {|repository, user| repository.new_record?})

  delegate(:default_branch, to: :scm)

  def self.human_attribute_name(attribute_key_name, *args)
    attr_name = attribute_key_name.to_s
    case attr_name
    when "root_url"
      attr_name = "gitlab_root_url"
    when "url"
      attr_name = "gitlab_project_url"
    end
    super(attr_name, *args)
  end

  def self.scm_name
    'GitLab'
  end

  def self.scm_adapter_class
    RedmineScmGitlab::GitlabAdapter
  end

  def self.changeset_identifier(changeset)
    changeset.scmid
  end

  def self.format_changeset_identifier(changeset)
    changeset.revision[0, 8]
  end

  def supports_directory_revisions?
    true
  end

  def supports_revision_graph?
    true
  end

  def find_changeset_by_name(name)
    return nil if name.blank?

    changesets.where(revision: name.to_s).first ||
      changesets.where('scmid LIKE ?', "#{name}%").first
  end

  def fetch_changesets
    ex = extra_info || {}
    latest_committed_date = ex['latest_committed_date']

    limit = 100
    loop do
      revisions = scm.revisions(latest_committed_date, limit)
      return if revisions.blank?

      revision_count = revisions.length
      latest_committed_date = revisions.last.time.utc.strftime("%FT%TZ")

      new_ids = revisions.map {|r| r.scmid}
      db_scmids = changesets.where(:scmid => new_ids).map {|c| c.scmid}
      revisions.reject! {|r| db_scmids.include?(r.scmid)}

      revisions.each do |revision|
        save_revision(revision)
      end

      ex['latest_committed_date'] = latest_committed_date
      merge_extra_info(ex)
      save(:validate => false)

      return if revision_count < limit
    end
  end

  def latest_changesets(path, rev, limit=10)
    revisions = scm.revision_scmids(path, rev, limit)
    return [] if revisions.blank?

    changesets.where(:scmid => revisions).to_a
  end

  private

  def save_revision(revision)
    parents = (revision.parents || []).map {|p| find_changeset_by_name(p)}.compact
    changeset = Changeset.create(
      repository: self,
      revision: revision.identifier,
      scmid: revision.scmid,
      committer: revision.author,
      committed_on: revision.time,
      comments: revision.message,
      parents: parents)
    unless changeset.new_record?
      revision.paths.each {|change| changeset.create_change(change)}
    end
    changeset
  end

  def clear_changesets
    super
    write_attribute(:extra_info, nil)
    save(:validate => false)
  end
end
