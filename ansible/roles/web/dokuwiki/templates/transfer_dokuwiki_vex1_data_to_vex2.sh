#!/bin/zsh
rsync -e 'ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o KexAlgorithms=curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256,diffie-hellman-group-exchange-sha1,diffie-hellman-group14-sha1,diffie-hellman-group1-sha1' -v -r --size-only --chown dokuwiki:dokuwiki vex.realraum.at:/var/www/dokuwiki/data/ /srv/dokuwiki/data/
rsync -e 'ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o KexAlgorithms=curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256,diffie-hellman-group-exchange-sha1,diffie-hellman-group14-sha1,diffie-hellman-group1-sha1' -v -r --size-only --chown dokuwiki:dokuwiki vex.realraum.at:/var/www/dokuwiki/conf/acl.auth.php vex.realraum.at:/var/www/dokuwiki/conf/users.auth.php /srv/dokuwiki/acl/

## Fixes for newer plugins
sed 's/<faicon.*fa-\(.*\)>/{{fa>\1}}/' -i /srv/dokuwiki/data/pages/navbar.txt
sed '/^{{rss/d' -i /srv/dokuwiki/data/pages/realraum.txt

## Todo
# - markdown conversion with pandoc

for f in /srv/dokuwiki/data/pages/**/*.md.txt; do pandoc --from markdown "$f" -t dokuwiki -o "${f:r:r}.txt" && rm "$f"; done

