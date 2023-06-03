# frozen_string_literal: true

require 'webmock'
require File.expand_path('../../test_helper', __FILE__)

class RepositoriesGitlabControllerTest < Redmine::ControllerTest
  include Redmine::I18n
  include WebMock::API
  tests RepositoriesController

  fixtures :enabled_modules,
           :email_addresses,
           :member_roles,
           :members,
           :projects,
           :repositories,
           :roles,
           :users

  def setup
    Setting.enabled_scm.push('GitLab')

    @request.session[:user_id] = 1
    @project = Project.find(3)
  end

  def test_new
    get(
      :new,
      params: {
        project_id: @project.id,
        repository_scm: 'GitLab'
      }
    )

    assert_response :success
    assert_select 'select[name="repository_scm"]' do
      assert_select 'option[value="GitLab"][selected=selected]'
    end
  end

  def test_create
    post(
      :create,
      params: {
        project_id: @project.id,
        repository_scm: 'GitLab',
        repository: {
          is_default: 0,
          identifier: 'test-create',
          root_url: 'http://127.0.0.1:8443',
          url: 'http://127.0.0.1:8443/project',
          password: 'token'
        }
      }
    )

    assert_response 302

    repository = Repository.order('id DESC').first
    assert_kind_of Repository::GitLab, repository
    assert_equal 'http://127.0.0.1:8443', repository.root_url
    assert_equal 'http://127.0.0.1:8443/project', repository.url
    assert_equal 'token', repository.password
  end

  def test_show
    WebMock.enable!

    repository = new_test_repository

    stub_branches
    stub_default_branch
    stub_commits
    stub_diff
    stub_tree
    stub_filesize
    stub_last_commit
    stub_tags

    get(
      :show,
      params: {
        id: @project.id,
        repository_id: repository.id,
      }
    )

    assert_response :success
  ensure
    WebMock.disable!
  end

  def new_test_repository
    repository = Repository::GitLab.new
    repository.project = @project
    repository.url = 'http://127.0.0.1/project'
    repository.login = 'root'
    repository.password = 'password'
    repository.root_url = 'http://127.0.0.1'
    repository.type = 'Repository::GitLab'
    repository.identifier = 'test'
    repository.save!
    repository
  end

  def stub_branches
    res = {
      data: {
        project: {
          repository: {
            branchNames: ['main', 'develop']
          }
        }
      }
    }

    stub_request(:post, "http://127.0.0.1/api/graphql/")
      .with(body: /branchNames/)
      .to_return(body: JSON.dump(res))
  end

  def stub_default_branch
    res = {
      data: {
        project: {
          repository: {
            rootRef: 'main'
          }
        }
      }
    }

    stub_request(:post, "http://127.0.0.1/api/graphql/")
      .with(body: /rootRef/)
      .to_return(body: JSON.dump(res))
  end

  def stub_last_commit
    res = {
      data: {
        project: {
          repository: {
            tree: {
              lastCommit: {
                authorName: 'root',
                authoredDate: '2023-01-01T01:01:02.000+00:00',
                massage: 'test',
                sha: 'b123456789012345678901234567890123456789',
              }
            }
          }
        }
      }
    }

    stub_request(:post, "http://127.0.0.1/api/graphql/")
      .with(body: /tree\(path:\\"folder\\"/)
      .to_return(body: JSON.dump(res))

    stub_request(:post, "http://127.0.0.1/api/graphql/")
      .with(body: /tree\(path:\\"test.txt\\"/)
      .to_return(body: JSON.dump(res))
  end

  def stub_filesize
    res = {
      data: {
        project: {
          repository: {
            blobs: {
              nodes: [
                {
                  size: 1024,
                },
              ],
            }
          }
        }
      }
    }

    stub_request(:post, "http://127.0.0.1/api/graphql/")
      .with(body: /blobs\(paths/)
      .to_return(body: JSON.dump(res))
  end

  def stub_tree
    res = {
      data: {
        project: {
          repository: {
            tree: {
              trees: {
                nodes: [
                  {
                    name: 'folder',
                    path: 'folder',
                    type: 'dir',
                  },
                ],
                pageInfo: {
                  hasNextPage: false
                }
              }
            }
          }
        }
      }
    }

    stub_request(:post, "http://127.0.0.1/api/graphql/")
      .with(body: /trees/)
      .to_return(body: JSON.dump(res))

    res = {
      data: {
        project: {
          repository: {
            tree: {
              blobs: {
                nodes: [
                  {
                    name: 'test.txt',
                    path: 'test.txt',
                    type: 'blob',
                  },
                ],
                pageInfo: {
                  hasNextPage: false
                }
              }
            }
          }
        }
      }
    }

    stub_request(:post, "http://127.0.0.1/api/graphql/")
      .with(body: /blobs\(first/)
      .to_return(body: JSON.dump(res))
  end

  def stub_commits
    res = [
      {
        id: 'a123456789012345678901234567890123456789',
        parent_ids: [],
        message: 'test',
        author_name: 'root',
        committed_date: '2023-01-01T01:01:01.000+00:00',
      },
      {
        id: 'b123456789012345678901234567890123456789',
        parent_ids: ['a123456789012345678901234567890123456789'],
        message: 'test',
        author_name: 'root',
        committed_date: '2023-01-01T01:01:02.000+00:00',
      },
    ]

    stub_request(:get, "http://127.0.0.1/api/v4/projects/project/repository/commits/")
      .with(query: {all: true, page: 1, per_page: 100})
      .to_return(body: JSON.dump(res))

    stub_request(:get, "http://127.0.0.1/api/v4/projects/project/repository/commits/")
      .with(query: {ref_name: 'main', page: 1, per_page: 10})
      .to_return(body: JSON.dump(res))
  end

  def stub_diff
    res = [
      {
        diff: '',
        new_path: 'test.txt',
        old_path: 'test.txt',
        a_mode: '100644',
        b_mode: '100644',
        new_file: false,
        renamed_file: false,
        deleted_file: false,
      },
    ]

    stub_request(:get, "http://127.0.0.1/api/v4/projects/project/repository/commits/a123456789012345678901234567890123456789/diff/")
      .with(query: {page: 1, per_page: 20})
      .to_return(body: JSON.dump(res))

    stub_request(:get, "http://127.0.0.1/api/v4/projects/project/repository/commits/b123456789012345678901234567890123456789/diff/")
      .with(query: {page: 1, per_page: 20})
      .to_return(body: JSON.dump(res))
  end

  def stub_tags
    res = [
      {
        name: 'v0.0.1',
      },
      {
        name: 'v1.0.0',
      }
    ]

    stub_request(:get, "http://127.0.0.1/api/v4/projects/project/repository/tags/")
      .with(query: {order_by: 'name', sort: 'asc', page: 1, per_page: 20})
      .to_return(body: JSON.dump(res))
  end
end
