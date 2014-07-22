#!/usr/bin/env ruby

require 'elasticsearch'
require 'json'
require 'date'
require 'optparse'
require 'progress_bar'
require 'curb'

class StashQuery

    @debug = nil
    @flush_buffer = 1000 ## Number of log lines to flush to file at
    @new_transport = true

    attr_reader :query_finished
    attr_reader :num_results
    attr_reader :start_date
    attr_reader :end_date

    def initialize(query, start_date, end_date, output_file, connection = {})
        @config = {}
        @config[:host] = connection[:host] || "ls2-es-lb.int.tropo.com"
        @config[:port] = connection[:port] || "9200"
        @config[:index_prefix] = connection[:index_prefix] || "logstash-"
        @config[:scroll_size] = connection[:scroll_size] || "100"
        @config[:scroll_time] = connection[:scroll_time] || "30m"
        @config[:output] = output_file
        @progress = connection[:progress] || false
        @query = query
        @start_date = start_date
        @end_date = end_date
        @num_results = 0
        @query_finished = false

        ## Do this better
        unless validate_date(@start_date) and validate_date(@end_date)
            raise "Improper date format entered"
        end

        ## Cleanup output file. Probably a better way to do this.
        begin
            File.truncate(@config[:output],0)
        rescue
        end

        @es_conn = connect_to_es
    end

    private

    def flush_to_file(hit_list)
        File.open(@config[:output], 'a') do |file|
            begin
                file.puts(hit_list)
            rescue
                puts "Could not open output file (#{@config[:output]}) for writing!"
                exit
            end
        end
    end

    def validate_date(str)
        return true if str =~ /20[0-9]{2}-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])T[012][0-9]:[0-5][0-9]:[0-5][0-9]\.[0-9]{3}Z/
        return nil
    end

    def connect_to_es
        ## Try a different transporter
        if @new_transport
            require 'typhoeus'
            require 'typhoeus/adapters/faraday'

            transport_conf = lambda do |f|
                #f.response :logger
                f.adapter :typhoeus
            end
        end

        ## Connect to ES server
        begin
            if @new_transport
                transport = Elasticsearch::Transport::Transport::HTTP::Faraday.new hosts: [ { host: @config[:host], port: @config[:port] }], &transport_conf
                es = Elasticsearch::Client.new transport: transport
            else
                es = Elasticsearch::Client.new(:host => @config[:host], :port => @config[:port])
            end
        rescue
            raise "Could not connect to Elasticsearch cluster: #{@config[:host]}:#{@config[:port]}"
        end
        
        return es
    end

    def get_indices
        indexes = Array.new
        start_str = @start_date.split('T').first.split('-').join('.')
        s_year = start_str.split('.').first.to_i
        s_mo = start_str.split('.')[1].to_i
        s_day = start_str.split('.').last.to_i
        start_date = Date.new(s_year, s_mo, s_day)

        end_str = @end_date.split('T').first.split('-').join('.')
        e_year = end_str.split('.').first.to_i
        e_mo = end_str.split('.')[1].to_i
        e_day = end_str.split('.').last.to_i
        end_date = Date.new(e_year, e_mo, e_day)

        (start_date..end_date).map do |day| 
            day = day.strftime('%Y.%m.%d')
            indexes << "#{@config[:index_prefix]}#{day}"
        end
        return indexes
    end

    def run_query
        queries = Array.new
        queries << "#{@query}" if @query

        if @start_date and @end_date
            time_range = "@timestamp:[#{@start_date} TO #{@end_date}]"
            queries << "#{time_range}"
            indexes = get_indices
        else
            indexes [ '_all' ]
        end

        query = queries.join(' AND ')

        ## Make sure each index exists
        good_indexes = Array.new
        unless indexes.include?('_all')
            indexes.each do |index|
                good_indexes << index if @es_conn.indices.exists index: index
            end
            indexes = good_indexes
        else
            indexes = [ '_all' ]
        end


        puts "Using these indices: #{indexes.join(',')}" if @debug

        index_str = indexes.join(',')
        res = @es_conn.search index: index_str, q: query, search_type: 'scan', scroll: @config[:scroll_time], size: @config[:scroll_size], df: 'message'
        scroll_id = res['_scroll_id']

        scroll_ids = Array.new
        scroll_ids << res['_scroll_id']
        @num_results = res['hits']['total']

        puts res.inspect if @debug and res['hits']['total'] > 300000

        if @config[:output]
            bar = ProgressBar.new(res['hits']['total']) if @progress
            hit_list = ''
            total_lines = 0 if @debug
            while true
                res['hits']['hits'].each do |hit|
                    hit_list += hit['_source']['message']
                    if hit_list.lines.count % @flush_buffer == 0
                        flush_to_file hit_list
                        hit_list = ''
                    end
                end
                bar.increment! res['hits']['hits'].length if @progress
                total_lines += res['hits']['hits'].length if @debug

                # Continue scroll through data
                begin
                    res = @es_conn.scroll scroll: @config[:scroll_time], body: scroll_id
                    scroll_id = res['_scroll_id']
                    scroll_ids << res['_scroll_id']
                rescue => e
                    puts res.inspect
                    raise e
                end

                begin
                    break if res['hits']['hits'].length < 1
                rescue => e
                    raise e
                end
            end
            flush_to_file hit_list
        end

        @query_finished = true
        clean_scroll_ids
    end

    def clean_scroll_ids
        ## Delete the scroll_ids to free up resources on the ES cluster
        ## Have to use direct API call until elasticsearch-ruby supports this
        scroll_ids.uniq.each do |scroll|
            puts "DELETE SCROLL:#{scroll}" if @debug
            #puts
            begin
                Curl.delete("#{@config[:host]}:#{@config[:port]}/_search/scroll/#{scroll}")
            rescue
                puts "Delete failed" if @debug
            end
        end
    end
    
end
