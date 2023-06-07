# frozen_string_literal: true

require 'net/http'
require 'json'

module RedmineScmGitlab
  class GitlabClient
    def initialize(url, project_path,  token, skip_ssl_verify)
      @rest_url = URI.parse(url) + 'api/v4/'
      @graph_url = URI.parse(url) + 'api/graphql/'

      @project_path = project_path
      @project_url = @rest_url + "projects/#{URI.encode_www_form_component(@project_path)}/"

      @token = token
      @skip_ssl_verify = skip_ssl_verify
    end

    def branches
      return branches_fallback if graphql_fallback?

      results = []

      offset = 0
      limit = 100
      loop do
        query = <<~QUERY
          {
            project(fullPath: "#{@project_path}") {
              repository {
                branchNames(searchPattern: "*", offset: #{offset}, limit: #{limit}),
              }
            }
          }
        QUERY

        json = graphql(query)
        tmp = json['data']['project']['repository']['branchNames']
        results += tmp

        if tmp.length < limit
          break
        end

        offset += limit
      end

      results
    end

    def default_branch
      query = <<~QUERY
        {
          project(fullPath: "#{@project_path}") {
            repository {
              rootRef
            }
          }
        }
      QUERY

      json = graphql(query)
      json['data']['project']['repository']['rootRef']
    end

    def last_commit(path, ref)
      query = <<~QUERY
        {
          project(fullPath: "#{@project_path}") {
            repository {
              tree(path: "#{path}", ref: "#{ref}") {
                lastCommit {
                  authorName,
                  authoredDate,
                  message,
                  sha
                }
              }
            }
          }
        }
      QUERY

      json = graphql(query)
      json['data']['project']['repository']['tree']['lastCommit']
    end

    def filesize(path, ref)
      return files(path, ref)['X-Gitlab-Size'] if graphql_fallback?

      query = <<~QUERY
        {
          project(fullPath: "#{@project_path}") {
            repository {
              blobs(paths: ["#{path}"], ref: "#{ref}") {
                nodes {
                  size
                }
              }
            }
          }
        }
      QUERY

      json = graphql(query)
      json['data']['project']['repository']['blobs']['nodes'][0]['size'].to_i
    end

    def tree(path, ref)
      limit = 5

      trees = []
      endcursor = ''
      loop do
        query = <<~QUERY
          {
            project(fullPath: "#{@project_path}") {
              repository {
                tree(path: "#{path}", ref: "#{ref}") {
                  trees(first: #{limit}, after: "#{endcursor}") {
                    nodes {
                      name,
                      path,
                      type
                    },
                    pageInfo {
                      endCursor,
                      hasNextPage
                    }
                  }
                }
              }
            }
          }
        QUERY

        json = graphql(query)
        trees += json['data']['project']['repository']['tree']['trees']['nodes']

        unless json['data']['project']['repository']['tree']['trees']['pageInfo']['hasNextPage']
          break
        end

        endcursor = json['data']['project']['repository']['tree']['trees']['pageInfo']['endCursor']
      end

      blobs = []
      endcursor = ''
      loop do
        query = <<~QUERY
          {
            project(fullPath: "#{@project_path}") {
              repository {
                tree(path: "#{path}", ref: "#{ref}") {
                  blobs(first: #{limit}, after: "#{endcursor}") {
                    nodes {
                      name,
                      path,
                      type
                    },
                    pageInfo {
                      endCursor,
                      hasNextPage
                    }
                  }
                }
              }
            }
          }
        QUERY

        json = graphql(query)
        blobs += json['data']['project']['repository']['tree']['blobs']['nodes']

        unless json['data']['project']['repository']['tree']['blobs']['pageInfo']['hasNextPage']
          break
        end

        endcursor = json['data']['project']['repository']['tree']['blobs']['pageInfo']['endCursor']
      end

      trees + blobs
    end

    def blob(path, ref)
      return blob_fallback(path, ref) if graphql_fallback?

      query = <<~QUERY
        {
          project(fullPath: "#{@project_path}") {
            repository {
              blobs(paths: ["#{path}"], ref: "#{ref}") {
                nodes {
                  rawTextBlob
                }
              }
            }
          }
        }
      QUERY

      json = graphql(query)
      json['data']['project']['repository']['blobs']['nodes'][0]
    end

    def version
      return @version if @version.present?

      query = <<~QUERY
        {
          metadata {
            version,
          }
        }
      QUERY

      json = graphql(query)
      @version = json['data']['metadata']['version'].split('.').map(&:to_i)
    end

    def blame(path, ref)
      q_path = URI.encode_www_form_component(path)
      q_ref = URI.encode_www_form_component(ref)
      blame_url = @project_url + "repository/files/#{q_path}/blame?ref=#{q_ref}"
      request = Net::HTTP::Get.new(blame_url)
      response = send(request)
      JSON.parse(response.body)
    end

    def blob_fallback(path, ref)
      sha = files(path, ref)['X-Gitlab-Blob-Id']
      content_url = @project_url + "repository/blobs/#{sha}/raw"
      request = Net::HTTP::Get.new(content_url)
      response = send(request)
      {'rawTextBlob' => response.body}
    end

    def branches_fallback
      branches_base = @project_url + 'repository/branches/'
      pagination(branches_base, nil, 0).map do |branch|
        branch['name']
      end
    end

    def commits(path, rev, limit, since, all)
      queries = []
      queries.push("path=#{URI.encode_www_form_component(path)}") if path.present?
      queries.push("ref_name=#{URI.encode_www_form_component(rev)}") if rev.present?
      queries.push("since=#{URI.encode_www_form_component(since)}") if since.present?
      queries.push("all=true") if all

      commit_base = @project_url + "repository/commits/"
      if all
        pagination_rev(commit_base, queries.join('&'), limit)
      else
        pagination(commit_base, queries.join('&'), limit)
      end
    end

    def diff(ref)
      q_ref = URI.encode_www_form_component(ref)
      diff_base = @project_url + "repository/commits/#{q_ref}/diff/"
      pagination(diff_base, nil, 0)
    end

    def compare(from, to)
      q_from = URI.encode_www_form_component(from)
      q_to = URI.encode_www_form_component(to)
      compare_url = @project_url + "repository/compare?from=#{q_from}&to=#{q_to}"
      request = Net::HTTP::Get.new(compare_url)
      response = send(request)
      JSON.parse(response.body)
    end

    def files(path, ref)
      q_path = URI.encode_www_form_component(path)
      q_ref = URI.encode_www_form_component(ref)
      files_url = @project_url + "repository/files/#{q_path}?ref=#{q_ref}"
      request = Net::HTTP::Head.new(files_url)
      send(request)
    end

    def tags
      project_tags_base = @project_url + 'repository/tags/'
      pagination(project_tags_base, 'order_by=name&sort=asc', 0)
    end

    private

    def graphql_fallback?
      (version <=> [13, 12]) < 0
    end

    def graphql(query)
      data = {query: "query #{query.gsub(/\s+/, '')}"}
      request = Net::HTTP::Post.new(@graph_url)
      request['Content-Type'] = 'application/json'
      request.body = JSON.dump(data)
      response = send(request)
      json = JSON.parse(response.body)
      if json.has_key?('errors')
        raise json['errors'][0]['message']
      end

      json
    end

    def pagination(base_url, query, limit)
      per_page = 20
      page = 1

      query += '&' if query.present?
      results = []

      loop do
        url = base_url + "?#{query}per_page=#{per_page}&page=#{page}"

        request = Net::HTTP::Get.new(url)
        response = send(request)
        results += JSON.parse(response.body)

        if limit != 0 && limit < results.length
          results = results[0..limit]
          break
        end

        page = response['x-next-page'].to_i
        if page < 1
          break
        end
      end

      results
    end

    def send(request)
      request['Authorization'] = "Bearer #{@token}"

      conn = Net::HTTP.new(@rest_url.host, @rest_url.port)
      conn.use_ssl = @rest_url.scheme == 'https'
      if @skip_ssl_verify
        conn.verify_mode = OpenSSL::SSL::VERIFY_NONE
      else
        conn.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end

      response = conn.start do |http|
        http.request(request)
      end

      response.value # raise if not 2xx

      response
    end

    def pagination_rev(base_url, query, limit)
      # if commits (all=true),
      # commit order is `asc` in page but `desc` between pages.
      # so acquire last page as first.
      query += '&' if query.present?

      url = base_url + "?#{query}per_page=#{limit}&page=1"
      request = Net::HTTP::Head.new(url)
      response = send(request)

      next_page = response['x-next-page'].to_i
      total_pages = response['x-total-pages'].to_i

      if total_pages < 1
        # if entry is over 10,000, total_pages does not exist.
        while next_page > 0
          total_pages = next_page

          url = base_url + "?#{query}per_page=#{limit}&page=#{next_page}"
          request = Net::HTTP::Head.new(url)
          response = send(request)

          next_page = response['x-next-page'].to_i
        end
      end

      # total_pages is missing ???
      total_pages = 1 if total_pages == 0

      results = []

      (1..total_pages).reverse_each do |page|
        url = base_url + "?#{query}per_page=#{limit}&page=#{page}"
        request = Net::HTTP::Get.new(url)
        response = send(request)
        results += JSON.parse(response.body)

        if limit < results.length
          return results[0..limit]
        end
      end

      results
    end
  end
end
