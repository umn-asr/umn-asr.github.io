---
layout: post
title: "Apache Kafka"
subtitle:  "From Quickstart to Reality with Ansible and Confluent"
date: 2018-02-10
author: "Ian Whitney"
---

Ever since reading [_Desgining Data Intensive Applications_](https://dataintensive.net) I've looked for any excuse to use [Apache Kafka](http://kafka.apache.org). I experimented with the Kafka quickstart and ran some small-scale proof-of-concept projects. When a real project came along that was a perfect fit for using Kafka, I jumped at the chance.

Which is when I learned that there's a large difference between tinkering with Kafka on my laptop and deploying it to a bunch of real servers. And when I went looking for guides to moving from Quickstart Kafka to Real Kafka, I couldn't find much. So I wrote my own! The following post covers my use of [Confluent](https://www.confluent.io) and [Ansible](https://www.ansible.com) to configure and automate a multi-host deployment of:

- Zookeeper
- Kafka
- Schema Registry
- Kafka Connect

If you're interested in learning about the Whys or the Whens of using Kafka there are other blog posts (or books, such as _Designing Data Intensive Applications_) that cover those topics in detail. If you're interested in a quickstart, then I recommend trying out [Confluent's quckstart](https://docs.confluent.io/current/). But if you're looking for how to move beyond experimentation in to a real running Kafka system, read on.

<!--break-->

### The Preamble

In the steps below I'll be using Ansible to deploy the Confluent OSS platform to a collection of Red Hat 7 hosts. Most of what I discuss should apply to other operating systems or configuration automation systems.

Feel free to use any code I provide! But be aware that everything is specific to UMN servers and your infrastructure may be different.

### The Playbooks

The repo [https://github.com/umn-asr/kafka_ansible_demo_playbooks](https://github.com/umn-asr/kafka_ansible_demo_playbooks) contains the Ansible playbooks that I used.

The [inventory file](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/master/inventory) contains the (fake) host names and groups them by playbook.

We'll discuss the playbooks in the same order they are run.

1. Confluent
1. Zookeeper
1. Kafka
1. Schema Registry
1. Connect

I'll describe what each playbook does and how you can test that it ran successfully.

### Confluent

The first playbook is [confluent.yml](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/master/confluent.yml) which, unsurprisingly, installs the Confluent OSS Platform

Confluent [provides great instructions for installing Confluent on Red Hat machines](https://docs.confluent.io/current/installation/installing_cp.html#rhel-and-centos), so this playbook was mostly a matter of converting their instructions into Ansible commands.

We're using the Ansible Galaxy [geerlingguy java role](https://github.com/geerlingguy/ansible-role-java) to get OpenJDK installed on the server.

#### Testing Confluent

Once run, you should be able to connect to your host(s) and run `confluent` and get see the Confluent usage instructions 

### Zookeeper

Kafka requires Zookeeper to run. You can run with a single Zookeeper process, but that defeats the distributed, redundant nature of Zookeeper. A collection of Zookeeper processes is called an "Ensemble". Ensembles [usually contain an odd number of processes](https://zookeeper.apache.org/doc/r3.1.2/zookeeperAdmin.html#sc_zkMulitServerSetup). We are starting with a 3-member ensemble.

The [zookeeper playbook](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/master/zookeeper.yml) configures a few things that all Zookeeper processes need.

- Open ports 2181, 2888 and 3888
- A unique ID number for each Ensemble member
- A Zookeeper configuration file
- A file that contains the correct ID number

#### Open ports 2181, 2888 and 3888

Port 2181 is the default port used by Zookeeper clients, such as Kafka. We need to open this port to all hosts that are running client processes.

Zookeeper uses ports 2888 and 3888 for Leader election. We need to open this port to all hosts that are running members of our Zookeeper ensemble.

We use a custom Ansible  role -- `ipset` -- to manage [IP Sets](http://ipset.netfilter.org). Ansible Galaxy contains a [role for managing ipset](https://github.com/mrlesmithjr/ansible-ipset) that can do the same thing, though the syntax will be a little different.

#### A unique ID number for each Ensemble member

You'll need to uniquely identify each Zookeeper ensemble member with an integer between 1 and 255.  We'll be using this ID number a bunch, so I made it a host variable in the [inventory file](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/master/inventory#L6).

#### A Zookeeper Config File

Confluent creates a default Zookeeper configuration file in `/etc/kafka/zoookeeper.properties`. The default configuration won't run an ensemble, so we have Ansible create a new one, using [the template in `files/zookeeper/zookeeper.properties.j2`](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/master/files/zookeeper/zookeeper.properties.j2)

The [Zookeeper admin site](https://zookeeper.apache.org/doc/r3.1.2/zookeeperAdmin.html#sc_zkMulitServerSetup) describes these settings in detail, but here's a quick summary.

`tickTime=2000` means that a single `tick` is equal to 2000 milliseconds. `initLimit` and `syncLimit` set restrictions on connecting to and synchronizing with the Ensemble Leader. The numbers are in `ticks`, so our initLimit is 5 `ticks` or 10 seconds.

Zookeeper stores its files in `dataDir`.

Zookeeper processes will listen for clients on `clientPort`. We've set this to 2181 to match the port we opened in the first step.

The loop at the end of the template declares all the ensemble members and where they live. For our 3-host ensemble, it'll look like this when deployed to the 2nd of our 3 Zookeeper hosts:

```
server.1=zk-01.umn.edu:2888:3888
server.2=0.0.0.0:2888:3888
server.3=zk-03.umn.edu:2888:3888
```

Each line follows the pattern `server.[id]=[host]:[port1]:[port2]`

The `server.[id]` section uses the same `zookeeper_id` we use to uniquely identify each Zookeeper process.

The `[host]` section declares the host running that ensemble member.

The `[port1]` and `[port2]` declare which ports to use for leader election. We opened these ports earlier in the playbook.

But why is the `[host]` section `0.0.0.0` for `server.2`?

Zookeeper documentation uses examples that look like this:

```
server.1=zk-01.umn.edu:2888:3888
server.2=zk-02.umn.edu:2888:3888
server.3=zk-03.umn.edu:2888:3888
```

But when I followed that example Zookeeper would fail. Each Zookeeper process was unable to communicate with the other two.

Some helpful folks at the UMN helped me discover that our Zookeeper processes were listening on the correct ports, but only for _internal_ requests. Requests from other servers were being ignored.

After even more help (and a lot of Googling, experimentation and cursing) I found [this answer on Stack Overflow](https://stackoverflow.com/questions/26732514/zookeeper-ensemble-not-coming-up#35441016)

Once I updated my template to use `0.0.0.0` for the current host, my Zookeeper processes were able to communicate. Yay!

I suspect the root cause of this behavior is something in `/etc/hosts`, but I'm not sure yet.

#### A file that contains their ID number

Each Zookeeper process needs a file that contains their ID number so that they know which member of the ensemble they are. This file is called `myid` and must live in the Zookeeper `dataDir`.

### Testing Zookeeper

Those steps _should_ be all you need, but we still want to see Zookeeper in action. For each host:

- Connect
- Run the command `zookeeper-server-start /etc/kafka/zookeeper.properties`
- Watch the very-chatty logs as they stream to stdout

If Zookeeper is especially misconfigured, it'll quit. Or it might run while complaining about not being able to connect to the other members of the ensemble. If it does neither of those things, you're probably good.

Once Zookeeper is running, you can ask each member of the ensemble how it's doing. Look at the [Four Letter Words section of the Zookeeper Admin Guide](https://zookeeper.apache.org/doc/r3.1.2/zookeeperAdmin.html#sc_zkCommands) for details. `stat` is a particularly helpful command because it will tell you who is the current Leader of the ensemble, allowing you to verify that Leader election is working:

`echo stat | nc localhost:2181`

### Kafka

Like Zookeeper you can run a single Kafka broker. But doing so reduces the redundancy and safety of your system. A collection of Kafka processes are a "cluster". Clusters work best with an odd number of members. We chose to start with a cluster of 3 Kafka brokers.

The [kafka playbook](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/master/kafka.yml) contains two tasks:

- Open ports for Kafka
- Configure our Kafka brokers

#### Open ports for Kafka

Kafka brokers communicate over port 9092. We need to open this port to all hosts that will be connecting to our Kafka cluster. Using the same `ipset` role that we used before does the trick.

#### Configure Kafka brokers

Confluent creates a default Kafka configuration file in `/etc/kafka/server.properties`. But the file configures Kafka for local development. [Our template file](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/master/files/kafka/server.properties.j2) changes the defaults to allow multi-host deployments.

- Configures The `broker.id` which identifies each member of the cluster
- Updates `zookeeper.connect` to the addresses of our Zookeeper ensemble members
- Adjusts settings designed for local development

Building the `zookeeper.connect` string is the oddest part of the playbook. We need  to turn a collection of hosts like:

```
zk-01.umn.edu
zk-02.umn.edu
zk-03.umn.edu
```

Into a comma-separated string of `host:port` values like:

```
zk-01.umn.edu:2181,zk-02.umn.edu:2181,zk-03.umn.edu:2181
```

I found this tricky to do in Ansible/Jinja2. After a lot of searching in Stack Overflow I came up with a two step approach.

Step one turns the list of hosts into a collection of facts that contain `host:2181`

```

- set_fact:
    host_and_port: '{{ item }}:2181'
  with_items:
    {{ "{{ groups['zookeeper'] " }}}}
  register: zookeeper_servers
```

Step two is [in the template](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/master/files/kafka/server.properties.j2#L123). It takes our `zookeeper_servers` facts, pulls out the `host_and_port` value and then joins them into a comma-separated string.

```
zookeeper.connect={{ "{{ zookeeper_servers.results | map(attribute='ansible_facts.hosts_and_ports') | join(',') " }}}}
```

The final result is what we need:

```
zookeeper.connect=zk-01.umn.edu:2181,zk-02.umn.edu:2181,zk-03.umn.edu:2181
```

#### Testing Kafka

As with Zookeeper we want to see our Kafka brokers run. First, follow the steps to start up your Zookeeper ensemble. Then, on each host:

- Connect
- Run the command `kafka-server-start /etc/kafka/server.properties`
- Watch the chatty logs as they stream to stdout

Like Zookeeper the Kafka brokers will quit if misconfigured too badly. In other cases they may keep running while spitting out errors. If they do neither then they are probably fine.

A quick test you can run is to ask each broker its topic list. Run this on each host:

```
kafka-topics --list --zookeeper zk-01.umn.edu:2181
```

This will show you the topics that the Kafka broker on the host knows. The topics will be the same for each broker. If they aren't, something has gone awry.

### Schema Registry

Many articles about Kafka in production contain a regretful note that goes something like:

> We didn't start out with Avro schemas, just unstructured JSON. This quickly became a problem and we had to [painfully] move to Avro.

I understood their pain and wanted to avoid it. JSON is hard to govern, validate, and evolve. Avro and the Schema Registry solve those problems. We are starting off with the Confluent Schema Registry and will be using Avro encoding on everything.

Our project is small, so we only need one Schema Registry server. I chose to run it on one of the hosts that is already running Zookeeper/Kafka but running it on its own host also makes sense. If you run it on a separate host be sure to install Confluent on the host first.

The [schema-registry playbook](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/master/schema-registry.yml) performs three tasks

- Open ports
- Upload a Schema Registry configuration file
- Upload a Avro configuration configuration file

#### Open Ports

I chose to run my Schema Registry server on port 8080. The playbook opens that ports to all members of the Kafka cluster. `ipset` to the rescue again.

#### Upload Schema Registry config file

Confluent creates a default Schema Registry configuration file in `/etc/schema-registry/schema-registry.properties`. We replace it with [our template file](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/master/files/schema-registry/schema-registry.properties.j2). Our template file declares the port of `8080` and the now-familiar Zookeeper connection string.

#### Upload a Avro configuration file

This file is actually used by the Connect process, which we're configuring next. But the contents of the file are only concerned with Schema Registry details, so I chose to configure it in the Schema Registry playbook.

Confluent will create two default Avro config files for you

- `/etc/schema-registry/connect-avro-standalone.properties`
- `/etc/schema-registry/connect-avro-distributed.properties`

Our [template file](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/master/files/schema-registry/connect-avro-standalone.properties.j2) replaces the standalone file, since that's what we currently use.

The template file is like the others we've seen. It:

- Creates a comma-separated list of Zookeeper hosts/ports
- Sets the host and port of the Schema Registry

But down at the bottom is what seems to be a minor thing

```
plugin.path=/usr/share/java
```

This is the directory where Confluent puts a lot of JAR files and those files are not loaded by default. If you do not declare this setting you may end up with an error like

> `ERROR Stopping after connector error (org.apache.kafka.connect.cli.ConnectStandalone:108) java.util.concurrent.ExecutionException: org.apache.kafka.connect.errors.ConnectException: Failed to find any class that implements Connector and which name matches io.confluent.connect.jdbc.JdbcSourceConnector`

This error haunted me for a day before I figured it out. Afterwards I found [this documentation about `plugin.path` and its usage](https://docs.confluent.io/current/connect/userguide.html#connect-installing-plugins). But it is very hard to link the error you get to this setting.

#### Testing Schema Registry

As with Zookeeper and Kafka we want to see Schema Registry run for real. First, start up your Zookeeper ensemble and Kafka cluster. Then:

- Connect to the host where you want to run Schema Registry
- `schema-registry-start /etc/schema-registry/schema-registry.properties`
- Watch stdout for errors

It should say that it's listening on `8080` (or whatever port you chose). 

You can test it by using `cURL` (or equivalent) from any host that should have access to the Schema Registry.

`curl http://zk-02.umn.edu:8080/subjects`

You should get `[]` as the response body, because you haven't yet put any data into your registry.

### Connect

Not all Kafka deployments will need Connect but it's a big part of our platform. It was also one of the trickier bits to set up (see the Avro configuration details above). Hopefully I can save someone some time by documenting our steps.

Our [connect playbook](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/master/connect.yml) performs two tasks.

- Upload a JDBC driver
- Configure our Connect worker

#### Upload a JDBC Driver

This step is only necessary if you need a JDBC driver that Confluent does not provide. We're connecting to a SQL Server DB which means we need to provide Microsoft's JDBC driver. You can upload it anywhere but we are putting in the same directory as the Confluent-provided drivers which is also part of the `plugin.path` that we declared in the Avro configuration file.

#### Configure our Connect Worker

Unlike previous steps we are not overwriting an existing configuration file here. We are creating our own, using [this template file](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/master/files/connect/source-destiny-one.properties.j2). Every Connect configuration will vary as this file describes what database to connect to, how to identify new records, what tables to watch, etc.

More details on configuring a Connect worker are at [the Confluent web site](https://docs.confluent.io/current/connect/connectors.html)

Andrew Zenk, awesome member of the UMN Ansible community, added the [LastPass lookup feature to Ansible in 2.3](https://github.com/ansible/ansible/pull/16285). We use it in the playbook to set our database connection variables to the credentials stored in LastPass.

#### Testing Connect

With the configuration in place we want to see the the Connect worker in action. First, start your Zookeeper, Kafka and Schema Registry processes. Then:

- Connect to the host that will run the Connect worker
- Run `connect-standalone /etc/schema-registry/connect-avro-standalone.properties /etc/kafka-connect-jdbc/source-destiny-one.properties`

It takes about 10 seconds for the Connect worker to get up and running. If it errors it will quit.

You may see an error saying that "no driver can be found". You may need to declare the `plugin.path` variable in your Connect configuration as well. Setting it to the same value as the `plugin.path` in the Avro configuration file may work, or you may need to set it to the exact location (including file name) of your JDBC driver. I've had varying results here, so I'm not exactly sure what's going on.

To see if your Connect worker is _really_ working, you can use the same test we ran when testing our Kafka brokers to see what topics exist. You should see your Connect worker's topic(s) in the list.

You can also check to see how many messages are in a topic with

```
kafka-run-class kafka.tools.GetOffsetShell --broker-list zk-01.umn.edu:9092 --topic your_topic_name
```

It will return `your_topic_name:0:XXXX` where `XXXX` is the number of messages in the topic.

### Conclusion/Next Steps

While it's very easy to get Confluent running for local development, configuring and deploying a real-world example takes some work. Even after all of the above we're not done yet. Up next are important operational concerns such as:

- How do I ensure that everything starts up properly on boot?
- How do I monitor that my processes are running?
- How do I restrict access to Kafka data?
- How do I retrieve and use data in Kafka?

And more, I'm sure. ASR Custom Solutions is still in early days with Kafka and there is much more to learn.
