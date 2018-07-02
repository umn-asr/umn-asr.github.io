---
layout: post
title: "Encrypting Apache Kafka Traffic"
subtitle: "SSL for Kafka servers and clients"
date: 2018-05-05
author: "Ian Whitney"
---

A little preamble before we start. For this post I'll be using example code from the [`ssl` branch of the Kafka demo playbooks repo](https://github.com/umn-asr/kafka_ansible_demo_playbooks/tree/ssl). These set of playbooks are different from the ones used in the [last post](2018/02/10/kafka-and-ansible.html), as we've made many improvements since writing that post. However, the playbooks should still be thought of as _illustrative_, not authoritative. I.e., if you try to run them as-is, they probably won't work.

Also, we're pretty new to some of the SSL tooling described below. I'm sure we're taking some unnecessary steps. We will probably refine our work as we learn more.

Also also, Confluent now has [their own Ansible playbooks that do SSL](https://github.com/confluentinc/cp-ansible). You should take a look at those.

Ok, preamble done.

<!--break-->

At the end of the last post we had a working Kafka cluster using a default configuration in which all messages are sent as plaintext between cluster members and clients. If you're running Kafka on a network where you have no concerns about malicious actors looking at your network traffic this may be good enough. In our case this was not going to be good enough and we needed to use SSL.

The official [Kafka documentation](http://kafka.apache.org/documentation/#security_ssl) includes an introduction to adding SSL, as do the [Confluent docs](https://docs.confluent.io/current/security.html). Those are both good starting points. But even after following the official guides as closely as I could I still ended up with a non-functioning cluster. After a failed attempt or two I found Stephane Maarek's and Gerd Koenig's class [Apache Kafka Security](https://www.udemy.com/apache-kafka-security). That class, along with some questions in the [Confluent Community Slack](https://launchpass.com/confluentcommunity), got us to a working solution that we've now automated in Ansible. In this post I'm going to lay out what my team did and explain our Ansible playbooks.

## Goals

For our SSL configuration, I had the following goals:

1. All traffic between Kafka brokers should be encrypted
2. All traffic between clients and brokers should be encrypted
3. It should be easy to add new hosts to the Kafka ecosystem

We ended up changing our mind on goal two and now allow clients to use either SSL or Plaintext. I'll explain why later on. But the other two goals have been achieved. Let's dig in to how.

## Encrypting Kafka Brokers

Each of your brokers is going to need

- A cert from a Certificate Authority they trust
- A cert signed by that Certificate Authority
- A `server.properties` file updated to enable SSL.

### Certificate Authority

For SSL encryption to work you're going to need a Certificate Authority (CA). At the U we [use an official CA](https://www.incommon.org), but the process for getting a signed cert is not automated or particularly fast. In order to satisfy the, "It should be easy to add new hosts" goal we decided to create our own CA. This CA will be trusted by all members of the Kafka cluster and it will sign all certificate requests made by cluster members.

[The `ca-create` playbook](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/ssl/certs/ca-create.yml) creates the keys on our designated CA host and then copies the public CA cert to a local directory.

Copying the file to a local directory may be unnecessary for you. We do it because our hosts are configured so that we can not move files between them. If we want to get a file from Host A to Host B we first have to copy the file to a local directory. This may not be how your hosts work.

### Create Certificate Signing Requests

[The `brokers-create` playbook](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/ssl/certs/brokers-generate.yml) uses the Java `keytool` on each broker host to create a keystore and then extract a Certificate Signing Request (CSR).

### Use the CA to Create Signed Certificates

[The `brokers-sign` playbook](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/ssl/certs/brokers-generate.yml) uses the Certificate Authority to sign our broker's CSR.

### Send the CA's Public Cert to Each Broker

[The `ca-copy-to-brokers` playbook](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/ssl/certs/ca-copy-to-brokers.yml) copies the Certificate Authority's public certificate to each broker. This certificate is then placed in a keystore and a truststore. The keystore copy will be used by the broker to prove its identity. The truststore is how your broker will trust other certs that have been signed by the CA.

### Place the Signed Cert and the CA Public Cert 

[The `brokers-upload-signed` playbook](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/ssl/certs/brokers-upload-signed.yml) places signed broker certificate into the keystore on the broker. Combined with the CA cert that we put in the keystore in the previous step, the keystore now contains the credentials that the broker will present to establish a SSL Connection. You can see this in action in this handy play I wrote:

Host A: Hello, I am Host A. Here is my certificate, signed by the Kafka CA. And here is the Kafka CA's cert. They are both from my keystore.

Host B: [looks in its truststore] Well, I trust certificates signed by the Kafka CA. So you must be who you say you are.

Greatly simplified, but you get the point. Each broker will use their keystore when introducing themselves. And each broker will use their truststore when deciding who to trust.

### Configure each Broker Host

With the truststore and keystore in place, we need to update each of our brokers to communicate over SSL. We do this in [the `kafka` playbook](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/ssl/kafka.yml) when uploading the [server.properties file](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/ssl/files/kafka/server.properties.j2)

First, we configure the ports that the broker listens for SSL connections:

```
listeners=PLAINTEXT://:9092,SSL://:9093
```

Note that we're still listening for plaintext traffic too. If you want your Kafka ecosystem to _only_ use SSL then remove that plaintext listener.

Then we configure the SSL settings. The end results on the server looks like:

```
ssl.truststore.location=/etc/pki/tls/private/kafka.server.truststore.jks
ssl.truststore.password=mysecret
ssl.keystore.location=/etc/pki/tls/private/kafka.server.keystore.jks
ssl.keystore.password=mysecret
ssl.key.password=mysecret
```

And then finally we tell the brokers to use SSL when communicating amongst themselves:

```
security.inter.broker.protocol=SSL
```

And with that all the configuration is done! Time to make sure everything works.

### Test The Brokers

The first test is to restart all of your brokers and watch their logs. Note that your broker's server logs are not stored in the same place as your `log.dir` setting, which controls where your application data (topics, etc) ends up. Our broker server logs end up at `/var/log/kafka/server.out`

If your logs show no errors then you're probably good. But if you want to see the traffic in action you can use `tcpdump`

`tcpdump` was new to me, but [Julia Evans' zine about it](https://jvns.ca/zines/#tcpdump) was a huge help. Highly recommended.

To watch your traffic using `tcpdump`,

1. Open two sessions on your broker's server
2. In one session run `tcpdump -i any port 9092`
  - This will show network traffic on port 9092, your plaintext port
3. In the other session, run `tcpdump -i any port 9093`
  - This will show network traffic on port 9093, your SSL port

You should see a bunch of activity on 9093. If you still have clients running that are connecting on 9092 then you may see activity on that port as well. If possible, turn those clients off so that you get a better picture of what your brokers are doing.

### Well, That Didn't Work

If you get errors at this point, join the club. Even though we felt that we understood this process pretty well it still took us a few times to get things right. Some errors we saw:

1. Brokers unable to communicate at all
2. 2 of the 3 brokers looking like they were fine while the leader broker logged endless errors.
3. Other cryptic weirdness

There are a lot of ways to go wrong and I can't document all of them or how to fix them. I can offer some tools we used to help us debug stuff.

**Are the brokers listening on 9093?**

`netstat -lnp | grep 9093` should show you a java process listening to `:::9093` (though that last bit can vary depending on your setup).

**Is 9093 open to your other brokers?**

`nmap -p 9093 other_broker_host` will tell you if port 9093 on the `other_broker_host` is open to connections from this host.

**Is the SSL handshake successful?**

`openssl s_client -debug -connect other_broker_host:9093 -tls1_2`

This should return a bunch of packet details and, at the bottom, SSL certificate details. The import thing to look for here is that the certificate was signed by the CA that your brokers trust.

For more help I suggest documenting your errors in detail and then politely asking the [Confluent Slack community](https://launchpass.com/confluentcommunity) or [Google group](https://groups.google.com/forum/#!forum/confluent-platform).

Eventually, after some days of trial and error, we got our brokers talking over to SSL and moved on to configuring our clients.

## Encrypting Your Clients

The steps for clients are much the same. On each client host we:

- Create a truststore that contains the CA's public cert.
- Update your client's configuration to use SSL

Different clients have different configuration options; refer to their documentation for exact details. The trickiest client we configured was Kafka Connect. I'll describe that next.

### Configuring Kafka Connect

Note: The steps below should work if you're using either Standalone or Distributed mode. We're using Distributed.

### Create the truststore

[The `distributed-connect` playbook](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/ssl/distributed-connect.yml) gets the CA's public cert, uploads it to the host(s) running Distributed Connect and creates a truststore. This is the same as what we did with the Brokers' truststores.

### Update your Connect worker to connect to Kafka via SSL

[The `distributed-connect` playbook](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/ssl/distributed-connect.yml) uploads the [`connect-avro-distributed.properties` file](https://github.com/umn-asr/kafka_ansible_demo_playbooks/blob/ssl/files/distributed-connect/connect-avro-distributed.properties.j2) that includes the necessary configuration. There are three sections you should probably add:

- Connect Worker
- Producer
- Consumer

Here are examples of the three sections as they will look on the Connect host.

*Connect Worker SSL Settings*
```
bootstrap.servers=zk-host-01:9093,zk-host-02:9093,zk-host-03:9093
security.protocol=SSL
ssl.truststore.location=/etc/pki/tls/private/kafka.server.truststore.jks
ssl.truststore.password=mysecret
```

*Producer SSL Settings*
```
producer.bootstrap.servers=zk-host-01:9093,zk-host-02:9093,zk-host-03:9093
producer.security.protocol=SSL
producer.ssl.truststore.location=/etc/pki/tls/private/kafka.server.truststore.jks
producer.ssl.truststore.password=mysecret
```

*Consumer SSL Settings*
```
consumer.bootstrap.servers=zk-host-01:9093,zk-host-02:9093,zk-host-03:9093
consumer.security.protocol=SSL
consumer.ssl.truststore.location=/etc/pki/tls/private/kafka.server.truststore.jks
consumer.ssl.truststore.password=mysecret
```

Yes these are all nearly identical but they each configure a different aspect of the Connect ecosystem. If you do not include the producer configuration then your producers will not connect to Kafka over SSL. Same goes for consumers and the consumer configuration.

Confluent provides some [documentation on Connect and SSL](https://docs.confluent.io/current/kafka/encryption.html#encryption-ssl-connect) which we recommend.

## Should We Encrypt Everything?

Our initial goal was to force all clients to use SSL but we decided to instead support both Plaintext and SSL. There were a few reasons for this.

First, we had trouble configuring SSL for the Schema Registry. This was likely our fault. But we decided not to spend too much time on it because sending schemas over plaintext is not a security risk we worried about.

Second, Kafka is faster over plaintext and we wanted to support clients that needed to move public data quickly. A lot of University of Minnesota data is public, so there are plenty of clients that can use plaintext without any risk.

But that's us and may not describe your situation. If you want to enforce SSL for everything, remove the `listener` for port 9092 in your Kafka `server.properties` file.

## That's It?

The steps in this blog post all seem fairly straightforward now that I write them all out, but actually getting all of these things to work involved a lot of confusion and frantic googling. Hopefully this walkthrough helps saves you some stress!
