#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'elasticsearch'
require 'json'
require 'date'
require 'optparse'
require 'curb'
require 'progress_bar'

module Stashquery
  class Query

  DEFAULT_FIELD = "message"
  $debug = nil
  $flush_buffer = 1000 ## Number of log lines to flush to file at
  $new_transport = true

  attr_reader :query_finished
  attr_reader :num_results
  attr_reader :start_date
  attr_reader :end_date

  def initialize(conf = {})
    @config = {}
    @config[:host] = conf[:host] || "ls2-es-lb.int.tropo.com"
    @config[:port] = conf[:port] || "9200"
    @config[:timefield] = conf[:timefield] || "@timestamp"
    if conf[:index_prefixes].is_a? Array and ! conf[:index_prefixes].empty?
      @config[:index_prefixes] = conf[:index_prefixes]
    else
      @config[:index_prefixes] = [ "logstash-" ]
    end
    @config[:scroll_size] = conf[:scroll_size] || "100"
    @config[:scroll_time] = conf[:scroll_time] || "30m"
    @config[:output] = conf[:output_file] || nil
    @query = conf[:query] || nil
    @tags = conf[:tags] || nil
    @start_date = conf[:start_date]
    @end_date = conf[:end_date]
    @config[:write_fields] = []
    set_write_fields(conf[:write_fields])
    @config[:delimiter] = conf[:delimiter] || ','
    @num_results = 0
    @query_finished = false
    @scroll_ids = Array.new
    @config[:debug] = conf[:debug] || $debug
    @config[:max_results] = conf[:max_results] || nil

    if conf[:print_msgs]
      @config[:print] = true
      require 'progress_bar'
    end

    ## Do this better
    unless Query.validate_date(@start_date) and Query.validate_date(@end_date)
      raise "Improper date format entered"
    end

    ## Cleanup output file. Probably a better way to do this.
    unless @config[:output].nil?
      begin
        File.truncate(@config[:output],0)
      rescue
      end
    end
    @es_conn = connect_to_es
    run_query
    sort_file
  end

  def self.validate_date(str)
    return true if str =~ /20[0-9]{2}-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])T[012][0-9]:[0-5][0-9]:[0-5][0-9]\.[0-9]{3}Z/
    return nil
  end

  private

  def sort_file
    unless @config[:output].nil?
      arr = File.readlines(@config[:output]).sort
      File.open(@config[:output], 'w') do |f|
        f.puts arr
      end
    end
  end

  def flush_to_file(hit_list)
    return if @config[:output].nil?
    if hit_list.is_a? String
        hit_list = hit_list.split("\n")
    end
    File.open(@config[:output], 'a') do |file|
      begin
        file.puts(generate_output(hit_list))
      rescue => e
        puts "Error writing to file."
        raise e
        exit
      end
    end
  end

  def set_write_fields(fields)
    if fields.is_a? Array
      if fields.empty?
        @config[:write_fields] << DEFAULT_FIELD
      else
        @config[:write_fields] = fields
      end
    elsif fields.is_a? String
      @config[:write_fields] = [ fields ]
    else
      @config[:write_fields] = [ DEFAULT_FIELD ]
    end
  end

  def generate_output(hit_list)
    output_data = []
    hit_list.each do |event|
      event_data = []
      if @config[:write_fields].include?('_all')
        event['_source'].keys.each do |field|
          event_data << "#{event['_source'][field]}".gsub("\n", '')
        end
      else
        @config[:write_fields].each do |field|
          event_data << "#{event['_source'][field] if event['_source'][field]}".gsub("\n", '')
        end
      end
      output_data << event_data.join(@config[:delimiter])
    end
    output_data
  end

  def connect_to_es
    ## Try a different transporter
    if $new_transport
      require 'typhoeus'
      require 'typhoeus/adapters/faraday'

      transport_conf = lambda do |f|
        #f.response :logger
        f.adapter :typhoeus
      end
    end

    ## Connect to ES server
    begin
      if $new_transport
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
      @config[:index_prefixes].each do |prefix|
        indexes << "#{prefix}#{day}"
      end
    end
    return indexes
  end

  def run_query
    queries = Array.new
    if @start_date and @end_date
      time_range = "#{@config[:timefield]}:[#{@start_date} TO #{@end_date}]"
      queries << "#{time_range}"
      indexes = get_indices
    else
      indexes [ '_all' ]
    end
    queries << @query if @query
    queries << @tags if @tags

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

    puts "Using these indices: #{indexes.join(',')}" if @config[:debug]

    index_str = indexes.join(',')
    res = @es_conn.search index: index_str, q: query, search_type: 'scan', scroll: @config[:scroll_time], size: @config[:scroll_size], df: 'message'
    scroll_id = res['_scroll_id']

    @scroll_ids << res['_scroll_id']
    @num_results = res['hits']['total']
    puts "Found #{@num_results} results" if @config[:print] or @config[:debug]

    puts res.inspect if @config[:debug]

    if @num_results > 0
      bar = ProgressBar.new(@num_results) if @config[:print]
      hit_list = Array.new
      total_lines = 0 if @config[:debug]
      while true
        # Scroll through data
        begin
          res = @es_conn.scroll scroll: @config[:scroll_time], body: scroll_id
          scroll_id = res['_scroll_id']
          @scroll_ids << res['_scroll_id']
        rescue => e
          puts res.inspect
          raise e
        end

        begin
          break if res['hits']['hits'].length < 1
        rescue => e
          raise e
        end

        res['hits']['hits'].each do |hit|
          bar.increment! if @config[:print]
          hit_list << hit
	  if @config[:max_results]
            # Set break flag
	    if hit_list.length == @config[:max_results]
              puts "Hit max result limit: #{@config[:max_results]} records" if @config[:debug]
	      $break_while_loop = true
	      break
	    end
	  end
          if hit_list.length % $flush_buffer == 0
            @config[:output] ? flush_to_file(hit_list) : (puts generate_output(hit_list))
            hit_list = Array.new
          end
        end
        total_lines += res['hits']['hits'].length if @config[:debug]
	# Break if break flag set
	break if $break_while_loop

      end
      @config[:output] ? flush_to_file(hit_list) : (puts generate_output(hit_list))
    end

    @query_finished = true
    clean_scroll_ids
  end

  def clean_scroll_ids
    ## Delete the scroll_ids to free up resources on the ES cluster
    ## Have to use direct API call until elasticsearch-ruby supports this
    @scroll_ids.uniq.each do |scroll|
      puts "DELETE SCROLL:#{scroll}" if @config[:debug]
      #puts
      begin
        Curl.delete("#{@config[:host]}:#{@config[:port]}/_search/scroll/#{scroll}")
      rescue
        puts "Delete failed" if @config[:debug]
      end
    end
  end

  end
end
