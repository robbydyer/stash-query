stash-query
===========

A CLI Tool for Querying Logstash and Exporting the results

Usage:
```
Usage:
    -c, --connect_host [HOST]        Logstash host to run query on (defaults to: localhost)
    -p, --port [PORT]                Logstash port (defaults to: 9200)
    -i, --index-prefix [PREFIX]      Index name prefix. Defaults to 'logstash-'
    -w, --write [FILE]               Write output file location (defaults to nil)
    -d, --debug                      Debug mode
    -s, --start [DATE]               Start date. Format: YYYY-MM-DDThh:mm:ss.SSSZ. Ex: 2013-12-01T12:00:00.000Z
    -e, --end [DATE]                 End date. Format: YYYY-MM-DDThh:mm:ss.SSSZ
    -q, --query [QUERY]              Query string
    -t, --tags [TAGS]                Tags to query. Comma delimited
```

