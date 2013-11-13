require 'helper'
require 'cashier'
require 'mysql2'
require 'slog'

module Services

  ##
  # = SQLDetector
  #
  # Detec changes in SQL databases. MySQL support only.
  #
  class SQLDetector < Detector

    public

    def checkup
      # update checkup time
      @agent.update_check_at @help.datetime
      
      
      @response = Hash.new
      @help = Services::Helper.new
      begin
        @client = Mysql2::Client.new(:host => @agent[:payload][:host], :username => @agent[:payload][:username] , :password => @agent[:payload][:password] , :database => @agent[:payload][:database])
      rescue Exception => e
        @response = {:status => 404, :message => "[i2x][SQLDetector] failed to load database connection, #{e.inspect}", :agent => @agent}
        Services::Slog.exception e
      end

      # Execute Agent query on SQL database, check if content has been seen before
      #
      begin
        @payloads = []
        @client.query(@agent[:payload][:query]).each(:symbolize_keys => false) do |row|
          unless @agent[:payload][:cache].nil? then
            @cache = Cashier.verify row[@agent[:payload][:cache]], @agent, row, 'seed'
          else
            @cache = Cashier.verify row["id"], @agent, row, 'seed'
          end

          # The actual processing
          #
          if @cache[:status] == 100 then

            # add row data to payload from selectors (key => key, value => column name)
            payload = Hash.new
            JSON.parse(@agent[:payload][:selectors]).each do |selector|
              selector.each do |k,v|
                payload[k] = row[v]
              end
            end
            # add payload object to payloads list
            @payloads.push payload
          end
        end
        @agent.increment!(:events_count, @payloads.size)
        @response = { :payload => @payloads, :status => 100}
      rescue Exception => e
        @response = {:status => 404, :message => "[i2x][SQLDetector] failed to load data from database, #{e}", :agent => @agent }
        Services::Slog.exception e
      end

      @response
    end
  end
end