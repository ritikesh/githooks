#!/usr/bin/env ruby
# encoding: UTF-8

require 'net/http'
require 'uri'
require 'base64'
require 'json'

class GitHooksIntegrationCommit

  ERROR_MESSAGE = [ "Please use the below format for your commit messages:\n <ID>(, ID) : <Comment> \nTicket id is mandatory; comments, optional. Ticket subject from portal will be taken as comment otherwise..",
    "Please make sure that the ticket: %{id} is assinged to you",
    "Please commit only for 'In Dev' and 'Resolved' tickets(%{id})",
    "Requested ticket: %{id} not found", 
    "Git Author config error"
  ]

  ID_REGEX = /^(\d+)((?:\s*,\s*\d+)*)(?:\s*:\s*([\w\s]+))?/
  AUTHOR_REGEX = /(?:("?(?:.*)"?)\s)?<(.*@.*)>/
  COMMIT_ALLOWED_STATUS = [1, 2] # Ticket Status IDS
  ALLOWED_FORMATS = [/^Merge (branch|remote-tracking) .+/]

  # Place your api key here
  API_KEY = "YOUR_API_KEY"
  ACCOUNT_URL = "https://localhost:3000"

  class << self

    # 'Basic ' + Base64.encode64(API_KEY)
    # dump to escape encoded key
    # gsub to replace escaped " at the start and end
    def encoded_api_key
      "Basic #{Base64.encode64(API_KEY).dump.gsub("\"","")}"
    end

    def ticket_url(id = 0)
      "#{ACCOUNT_URL}/helpdesk/tickets/#{id}.json"
    end

    def str_presence(obj)
      obj.respond_to?(:empty?) ? obj.gsub(" ","") : ""
    end

    def get_commit_ids(message)
      match_data = message.match(ID_REGEX)
      if match_data.nil? 
        ALLOWED_FORMATS.each { |format|
          !!message.match(format) && exit(0)
        }
        raise_error ERROR_MESSAGE[0] 
      end
      @add_msg = "#{message} : " if match_data[3].nil? || match_data[3].empty?
      ids = [match_data[1]]
      str_presence(match_data[2]).split(",").each { |id|
        ids.push id unless id.empty? # first value in the array can be empty string
      }
      ids
    end

    def parse_commit_message

      @message_file = ARGV[0]
      message = File.open(@message_file,&:readline)
      ticket_ids = get_commit_ids(message)
      
      author = %x(git var GIT_AUTHOR_IDENT)
      author_tokens = author.match(AUTHOR_REGEX)
      author_tokens.nil? ? (raise_error ERROR_MESSAGE[4]) : (@committer = author_tokens[1])
      
      ticket_ids.each { |id|
        validate id
      }
      exit 0
    end

    def validate(id)

      uri = URI(ticket_url(id))

      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new uri.request_uri
        request['Content-Type'] = 'application/json'
        request['Authorization'] = encoded_api_key
        response = http.request request

        case response
          when Net::HTTPSuccess
            ticket = JSON.parse(response.body)
            ticket["errors"] && ticket["errors"]["error"].sub!("Record", "Ticket") && raise_error(ticket["errors"]["error"])
            # skip ticket validations if message contains SoS
            return if @add_msg && @add_msg.include?("SoS")
            raise_error(ERROR_MESSAGE[1] % {id: id}) unless ticket["helpdesk_ticket"]["responder_name"] == @committer
            raise_error(ERROR_MESSAGE[2] % {id: id}) unless COMMIT_ALLOWED_STATUS.include? ticket["helpdesk_ticket"]["status"]

            @add_msg && append_subject(@add_msg+ticket["helpdesk_ticket"]["subject"])
          when Net::HTTPServerError
            raise_error "#{response.message}: try again later"
          when Net::HTTPNotFound
            raise_error(ERROR_MESSAGE[3] %{id: id})
          else
            raise_error response.message
        end
      end
    end

    def append_subject comment
      File.write(@message_file,comment)
    end

    def raise_error str
      puts str
      exit 1
    end
  end
end

GitHooksIntegrationCommit.parse_commit_message