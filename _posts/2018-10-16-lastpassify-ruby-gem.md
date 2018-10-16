---
layout: post
title: "Lastpassify"
subtitle: "A Ruby gem to automate YAML configuration files with data from LastPass"
date: 2018-10-16
author: "Remy Abdullahi"
---

At ASR Custom Solutions, we support a number of applications and systems. These run in multiple environments and hosts, talking to other services that also exist in different environments. At any point, there's dozens of passwords, secrets, connection strings and other configurations we have to manage.

Our team stores these in LastPass. When we need to access them though, we had to deal with hunting within LastPass for the specific note we needed. For a large, microservicey-system like our [Student Degree Progress Service](https://sdp.dl.umn.edu/), this could mean dozens of hostnames, usernames and passwords. Onboarding a new developer to the project was distinctly painful here.

So, we made a Ruby gem to automate all this for us; [Lastpassify](https://github.com/umn-asr/lastpassify).

Lastpassify is a commandline tool packaged as [a Ruby gem](https://rubygems.org/gems/lastpassify) that takes in an YAML ERB template file and outputs a populated YAML file. We primarily use it for our `database.yml` files.

It requires [lastpass-cli](https://github.com/lastpass/lastpass-cli) and Ruby v2+ to be installed.

### Usage

LastPassify expects an input of one YAML file to be processed and outputs one YAML file. The input file can be passed in as an argument at the commandline like so:

`$ bundle exec lastpassify my_input_file.yml`

The output file and path can also be specified:

`$ bundle exec lastpassify my_input_file.yml config/my_output_file.yml`

LastPassify has default values that silently get passed if no input or output file is specified. The default input file LastPassify will look for is `config/database.example.yml`. The default output will also live in the config directory, with a filename of `database.yml`.

An example `database.example.yml` file might look like this:

```yaml
---
# Shared
global_defaults: &global_defaults
  adapter: oracle_enhanced

# Development environment
development: &development
  <<: *global_defaults
  host: <%= lookup('lastpass', 'Shared-Artifactory/lastpassify', field='Hostname') %>
  database: <%= lookup('lastpass', 'Shared-Artifactory/lastpassify', field='Database') %>
  username: <%= lookup('lastpass', 'Shared-Artifactory/lastpassify', field='username') %>
  password: <%= lookup('lastpass', 'Shared-Artifactory/lastpassify', field='password') %>
  secret_key: <%= lookup('lastpass', 'Shared-Artifactory/lastpassify_secret_key', field='Secret Key') %>

staging:
  <<: *development
```

Finally, Lastpassify strips out any YAML keys with production, staging or qat in their names. This is a security measure to ensure no prod or staging environment credentials sit on your local development machine unnecessarily.

This can be overridden by passing in a `-s` (staging) or `-p` (prod) flag to Lastpassify, e.g.:

`$ bundle exec lastpassify -p`

We hope you find it useful and appreciate any [pull requests](https://github.com/umn-asr/lastpassify/)!
