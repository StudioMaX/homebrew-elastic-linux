# Elastic Homebrew Tap

This tap is for products in the Elastic stack.

## How do I install these formulae?

Install the tap via:

    brew tap studiomax/elastic-linux

Then you can install individual products via:

    brew install studiomax/elastic-linux/elasticsearch-full

The following products are supported:

* Elasticsearch `brew install studiomax/elastic-linux/elasticsearch-full`
* Logstash `brew install studiomax/elastic-linux/logstash-full`
* Kibana `brew install studiomax/elastic-linux/kibana-full`
* Beats
  * Auditbeat `brew install studiomax/elastic-linux/auditbeat-full`
  * Filebeat `brew install studiomax/elastic-linux/filebeat-full`
  * Heartbeat `brew install studiomax/elastic-linux/heartbeat-full`
  * Metricbeat `brew install studiomax/elastic-linux/metricbeat-full`
  * Packetbeat `brew install studiomax/elastic-linux/packetbeat-full`
* APM server `brew install studiomax/elastic-linux/apm-server-full`
* Elastic Cloud Control (ecctl) `brew install studiomax/elastic-linux/ecctl`

For Logstash, Beats and APM server, we fully support the OSS distributions
too; replace `-full` with `-oss` in any of the above commands to install the 
OSS distribution. Note that the default distribution and OSS distribution of
a product can not be installed at the same time.

## Documentation
`brew help`, `man brew` or check [Homebrew's documentation](https://github.com/Homebrew/brew/blob/master/docs/README.md).
