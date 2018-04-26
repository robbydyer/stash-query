stash-query
===========

A CLI Tool for Querying Logstash/Elasticsearch and Exporting the results. Uses the Lucene query syntax that Kibana utilizes, but provides the option for exporting. 

Usage: 
```
    -c, --connect_host [HOST]        Elasticsearch host to run query on (defaults to: localhost)
    -p, --port [PORT]                Elasticsearch port (defaults to: 9200)
        --ssl                        Elasticsearch port (defaults to no ssl)
    -T, --timefield [FIELDNAME]      Time-field name (defaults to: @timestamp)
        --scroll-size [number of records]
                                     Scroll Size (defaults to: 10).
        --scroll-time [time units]   Scroll Size (defaults to: 30m).
    -i, --index-prefix [PREFIX]      Index name prefix(es). Defaults to 'logstash-'. Comma delimited
    -w, --write [FILE]               Write output file location (defaults to nil)
    -d, --debug                      Debug mode
    -s, --start [DATE]               Start date. Format: YYYY-MM-DDThh:mm:ss.SSSZ. Ex: 2013-12-01T12:00:00.000Z
    -e, --end [DATE]                 End date. Format: YYYY-MM-DDThh:mm:ss.SSSZ
    -q, --query [QUERY]              Query string
    -t, --tags [TAGS]                Tags to query. Comma delimited
    -f, --write-fields [FIELDS]      Comma delimited list of Logstash fields to write to output file. Defaults to "message"
    -l, --delimiter [DELIMITER]      Delimiter to use in output file. Defaults to ","
    -S, --silent                     Run silently
    -m, --max [INTEGER]              Maximum number of results to return. Non-integer arguments default to 0.
```

Examples:
```
stash-query -s 2013-12-01T00:00:00.000Z -e 2013-12-02T00:00:00.000Z -t my_tag -q 'message:hello_world' -w /tmp/my_query.txt
```

#  To install locally

```
gem build stash-query.gemspec
 
gem install stash-query-<version>.gem
```

