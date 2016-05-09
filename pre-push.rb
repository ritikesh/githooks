#!/usr/bin/env ruby
# encoding: UTF-8

require 'net/http'
require 'uri'
require 'base64'
require 'json'

class GitHooksIntegrationPush

  MONITORED_FILE_EXTENSIONS = [[".scss", ".js"], ["db/migrate"]]
  MONITORS =['user1@freshdesk.com', 'user2@freshdesk.com']

  # Place your api key here
  API_KEY = "YOUR_API_KEY"
  ACCOUNT_URL = "https://localhost:3000"
  REPO_URL = "https://github.com/ritikesh/githooktest/commit/"

  class << self
  
    # 'Basic ' + Base64.encode64(API_KEY)
    # dump to escape encoded key
    # gsub to replace escaped " at the start and end
    def encoded_api_key
      "Basic #{Base64.encode64(API_KEY).dump.gsub("\"","")}"
    end

    def note_url(id = @id)
      "#{ACCOUNT_URL}/helpdesk/tickets/#{id}/conversations/note.json"
    end

    def process_commits
      commits = %x(git log @{u}..HEAD --pretty=format:%H)
      commits.split(" ").each do |sha|
        @m_author = %x(git show -s --format=%an #{sha})
        m_comment = %x(git show -s --format=%s #{sha})
        @id = m_comment.gsub(/^(\d+)/).first
        if @id
          m_files = %x(git diff-tree --no-commit-id --name-only -r #{sha}).split(" ")
          commit_url = REPO_URL + sha

          find_monitored_files m_files
          update_commit_sha commit_url, m_comment
        else
          # assuming commit message was one of the ALLOWED_FORMATS
          break
        end
      end
      exit 0
    end

    def find_monitored_files(files)
      @monitors = []
      ui_checked, db_checked = false, false
      files.each do |file|
        ui_checked || @monitors << MONITORS[0] && ui_checked = true if MONITORED_FILE_EXTENSIONS[0].include? File.extname(file)
        db_checked || @monitors << MONITORS[1] && db_checked = true if MONITORED_FILE_EXTENSIONS[1].include? File.dirname(file)
        ui_checked && db_checked && break
      end
    end

    def update_commit_sha(commit_url, commit_msg)

      data = {
        "helpdesk_note[private]" => true,
        "helpdesk_note[body]" => "Note added from git hooks.",
        "helpdesk_note[body_html]" => "<div style='font-size: 13px; font-family: Helvetica Neue, Helvetica, Arial, sans-serif;'><p><b>
          Commit Details&nbsp;</b></p><p><b><br></b></p><p style='margin-bottom:15px;'><span>Author : #{@m_author}</span></p>
          <p style='margin-bottom:15px;'>
          <span>Message : #{commit_msg}</span></p>
          <p style='margin-bottom:15px;'>
          <span>URL : #{commit_url}</span></p>
          <p><br></p><p><br></p></div>"
      }

      data.merge!("helpdesk_note[to_emails]" => @monitors.to_s) if @monitors
      add_note data
    end

    def add_note(data)
      uri = URI(note_url)

      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Post.new uri.request_uri
        request['Content-Type'] = 'application/json'
        request['Authorization'] = encoded_api_key
        request.set_form_data data
        response = http.request request 

        case response
          when Net::HTTPSuccess
            ticket = JSON.parse(response.body)
            ticket["errors"] && ticket["errors"]["error"].sub!("Record", "Ticket") && raise_error(ticket["errors"]["error"])
          when Net::HTTPServerError
            raise_error "#{response.message}: try again later"
          when Net::HTTPNotFound
            raise_error "Requested ticket not found"
          else
            raise_error response.message
        end
      end   
    end

    def raise_error str
      puts str
      exit 1
    end
  end
end

GitHooksIntegrationPush.process_commits