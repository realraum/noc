[[!meta title="Certificates for services on our LAN"]]

# Let's Encrypt certs for services on our LAN

We use [Let's Encrypt] to acquire and renew certificates for basically
all services.  However, some services are only exposed on the LAN, and
so certificate acquisition becomes a bit trickier.

[ACME], the protocol for interacting with [Let's Encrypt],
supports [DNS-01] authorization, so we can use that to acquire certs
without exposing services to the Internet.

[Let's Encrypt]: https://letsencrypt.org/
[DNS-01]: https://tools.ietf.org/html/draft-ietf-acme-acme-07#section-8.5
[ACME]:   https://tools.ietf.org/html/draft-ietf-acme-acme-07


## Overview

Let's say we need certificates for `metrics.mgmt.realraum.at`

`metrics.mgmt` will send DNS updates to `gw`.  It only needs TXT records for
 `_acme-challenge.metrics.mgmt.realraum.at` and they will be authenticated using
 HMAC-SHA256.


## Bind9

### Generating a TSIG key

On the system running the services:

- Install `bind9utils` to have the not-so-aptly named `dnssec-keygen` tool.
- As `root`, generate an HMAC-SHA256 key and make it readable by `acme`:

        # dnssec-keygen -K /etc/acme -a HMAC-SHA256 -b 256 \
                        -n USER metrics.mgmt.realraum.at.
        Kmetrics.mgmt.realraum.at.+163+06888

        # chown root:acme /etc/acme/K*
        # chmod 0440 /etc/acme/K*

- Lookup the key, as we will need to put it in the NS' configuration

        # cat /etc/acme/Kmetrics.mgmt.realraum.at.+163+06888.private
        Private-key-format: v1.3
        Algorithm: 163 (HMAC_SHA256)
        Key: FG4v6Eya7utyJ1GxXm019kYBawN+jvfEWCC/7lIgraQ=
        Bits: AAA=
        Created: 20171022235329
        Publish: 20171022235329
        Activate: 20171022235329


_Note:_ I selected HMAC-SHA256 because `gw.realraum.at` is running an
        obsolete version of Bind9 that only supports HMAC or RSA.
        In principle, the setup should be similar for asymetric signatures.


### Adding the keys

On `gw.realraum.at`:

- `/etc/bind/keys.conf` should exist and be accessible to `root` and `bind`:

        # touch           /etc/bind/keys.conf
        # chown root:bind /etc/bind/keys.conf
        # chmod 0640      /etc/bind/keys.conf

- Check that `keys.conf` is included from `named.conf.local`:

        # head /etc/bind/named.conf.local
        include "/etc/bind/zones.rfc1918";
        include "/etc/bind/keys.conf";
        [...]

- Add the key descriptor to `keys.conf`:

        # cat >> /etc/bind/keys.conf
        key metrics.mgmt.realraum.at. {
            algorithm HMAC-SHA256;
            secret "4QZWZsLagxXaoBCAxDqbSZmoSjN5qJvZviadrPXkmvU=";
        }


### Setting up DNS updates

- Edit the zone description in `named.conf.local` to allow updates:

        zone "realraum.at" {
            type master;
            file "/etc/bind/db.realraum.at";
            [...]

            update-policy {
                grant metrics.mgmt.realraum.at. name _acme-challenge.metrics.mgmt.realraum.at. TXT;
            };
        };

- The update journal for the zone should be writeable by `bind`:

        # touch           /etc/bind/db.realraum.at.jnl
        # chown root:bind /etc/bind/db.realraum.at.jnl
        # chmod 0660      /etc/bind/db.realraum.at.jnl

- Restart `bind`


## [acmetool]

### Installation

- `acmetool` is available from the official repos starting with Stretch.
- For earlier releases, Christian [has a package](https://build.spreadspace.org/)

Start with a working, [rootless acmetool setup].

_Note:_ On Debian, _hooks_ are located in `/etc/acme/hooks`, instead of
        `/usr/lib/acme/hooks` or `/usr/libexec/acme/hooks`.

[acmetool]: https://hlandau.github.io/acme/
[rootless acmetool setup]: https://hlandau.github.io/acme/userguide#annex-root-configured-non-root-operation


### Setting up the hook

An example hook using `nsupdate`
[already ships](https://github.com/hlandau/acme/blob/master/_doc/dns.hook)
with acmetool.

- Install `dnsutils` (contains `nsupdate`)
- Link the hook from the documentation:

        # ln -s ../../../usr/share/doc/acmetool/examples/dns.hook /etc/acme/

- Write the configuration for it:

        # cat > /etc/default/acme-dns
        NSUPDATE_ARGS="-k /etc/acme/Kmetrics.mgmt.realraum.at.+163+06888.key"

        nsupdate_cmds() {
            echo server 192.168.33.1
        }

- Test

        # sudo -u acme /etc/acme/hooks/dns.hook challenge-dns-start \
          foo.example.com "" "foobar"
        # sudo -u acme /etc/acme/hooks/dns.hook challenge-dns-start \
          foo.example.com "" "foobar"

  If either of those commands fail with an error,
  check the DNS traffic (`tcpdump -vvv port 53`)


### Certificate acquisition

Once everything is setup, getting a certificate from Let's Encrypt
is quite easy:

        # sudo -u acme acmetool want metrics.mgmt.realraum.at


### Testing automated removal

Last thing, you should check that automatic renewal is setup and works:

- Is the cron job in place?

        # crontab -u acme -l
        
        37 13 * * * /usr/bin/acmetool --batch reconcile

- Is the default hook for reloading services in place?
  If you delete the certificate and key, then run `acmetool`,
  do your services use the new certificate?

        # [check the service's certificate fingerprint, with openssl s_client]
        # rm -rf /var/lib/acme/keys/*
        # sudo -u acme acmetool --batch reconcile
        # [check the service's certificate fingerprint, they should differ]
