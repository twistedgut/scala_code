#!/bin/bash

echo "============================================="
echo "dynamically unpacking dependencies on jenkins"
echo "============================================="

# UNICORN-PERL-BUILD-HELPERS

# The build helpers script analyses perl applications
# and automatically resolve rpm dependencies, download,
# unpack and configure those dependencies.

# this allows us to dynamically test the application
# regardless of what's installed on the local jenkins
# instance.

# further more, by download the rpms _now_ and promoting
# them with xt (notice our dependencies are in deploy.yaml)
# it means that promoting incompatible/untested dependencies
# to stable wouldn't break our envs as our vms don't rely on
# unstable/stable repos. this gives us trust that what we
# tested against is what we're deploying with.

# however... build/helpers only works with perl applications
# that are built with dist::zilla. Here I partially abuse the
# script to fetch the dependencies we need.. but until we've
# moved to dist::zilla we are going to need to update
# nap_hiera_jenkins and fracture our jenkins instances into those
# that work for free and those that don't. :-(

. /opt/nap/build/helpers
nap_perl_local_install_dependencies;

_nap_perl_ignore_rpms=x nap_perl_download_rpms_for "perl-nap-core"
_nap_perl_ignore_rpms=x nap_perl_download_rpms_for "perl-nap-cpan"
nap_perl_download_rpms_for "bootstrap-nap"
nap_perl_download_rpms_for "yui-nap"
nap_perl_download_rpms_for "jquery-nap"
nap_perl_download_rpms_for "bootstrap-nap"
nap_perl_download_rpms_for "warehouse-common"
nap_perl_download_rpms_for "NAP-Service-Product"
nap_perl_download_rpms_for "NAP-Solr-Perl"
nap_perl_download_rpms_for "Plack-Middleware-NAP-ServerStatus"
nap_perl_download_rpms_for "NAP-policy"
nap_perl_download_rpms_for "NAP-Messaging"
nap_perl_download_rpms_for "NAP-Config"
nap_perl_download_rpms_for "XT-Common"
nap_perl_download_rpms_for "XT-Common-JQ"
nap_perl_download_rpms_for "NAP-Apache-Admin-Config"

echo "======================================"
echo "insert test suite / sanity checks here"
echo "======================================"


echo "============"
echo "building rpm"
echo "============"

echo ">> cleaning environment"
rm -f MANIFEST
make realclean

echo ">> Constructing Makefile"
perl Makefile-uni.PL

echo ">> making manifest (takes a while)"
make manifest > manifest.output 2>&1

echo ">> making rpm"
make rpm

copy_perl_rpms_here;

echo "RPMs Built"

find -name *.rpm

