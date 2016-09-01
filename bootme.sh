#!/usr/bin/env bash
#
# This script installs puppet 3.x or 4.x and configures it for the stargazer-server1.naturalis.nl puppetmaster
#
# Usage:
# Ubuntu / Debian: wget https://raw.githubusercontent.com/naturalis/bootscript/master/bootme.sh; bash bootme.sh
#
# Red Hat / CentOS: curl https://raw.githubusercontent.com/naturalis/bootscript/master/bootme.sh -o bootme.sh; bash bootme.sh
# Options: add 3 as parameter to install 4.x release

# default major version, comment to install puppet 3.x
PUPPETMAJORVERSION=4
export DEBIAN_FRONTEND=noninteractive
hostname=$(hostname -f)

### Code start ###
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

if [[ $hostname == *"."* ]]; then
  echo "Hostname OK"
else
  echo "Please configure host and domain name, test using 'hostname -f'"
  exit 1
fi

if [ "$#" -gt 0 ]; then
   if [ "$1" = 3 ]; then
     PUPPETMAJOR=3
   else
     PUPPETMAJOR=4
  fi
else
  PUPPETMAJOR=$PUPPETMAJORVERSION
fi

if [ "$PUPPETMAJOR" = 3 ]; then
    MODULEDIR="/etc/puppet/modules/"
  else
    MODULEDIR="/etc/puppetlabs/code/modules/"
fi

# install dependencies
if which apt-get > /dev/null 2>&1; then
    apt-get update
  else
    echo "Using yum"
fi

apt-get install git -y -q

# get or update repo
if [ -d /root/bootscript ]; then
  echo "Update repo"
  cd /root/bootscript
  git pull
else
  echo "Cloning repo"
  git clone https://github.com/naturalis/bootscript.git /root/bootscript
  cd /root/bootscript
fi

# install puppet
bash /root/bootscript/bootstrap.sh $PUPPETMAJOR

# disable puppet
service puppet stop

# create puppet config
cat << EOF > /etc/puppetlabs/puppet/puppet.conf
[agent]
default_schedules = false
report            = true
pluginsync        = true
masterport        = 8140
environment       = production
certname          = dummyhostname
server            = stargazer-server1.naturalis.nl
listen            = false
splay             = false
splaylimit        = 1800
runinterval       = 1800
noop              = false
usecacheonfailure = true
EOF

# change certname to hostname
sed -i "s/^certname          = dummyhostname/certname          = $hostname/" /etc/puppetlabs/puppet/puppet.conf

# add puppetmaster to /etc/hosts
if grep -q stargazer-server1 /etc/hosts; then
  echo "stargazer-server1 already in hostfile"
else
  echo "Adding stargazer-server1 to  hostfile"
  echo '172.16.75.5     stargazer-server1.naturalis.nl stargazer-server1' >> /etc/hosts
fi

# run puppet
echo "Run puppet agent"
/usr/local/bin/puppet agent -t

# start puppet
service puppet start
