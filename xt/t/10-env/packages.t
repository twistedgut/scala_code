#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;


use Test::UseAllModules;
use Log::Log4perl qw(:easy);
use FindBin::libs;
use Test::More;

# To get the right config overrides set
use Test::XTracker::LoadTestConfig;

BEGIN {
    # need to set this ENV to make 'XT::DC::Messaging' pass
    $ENV{XT_DC_MESSAGING_CONFIG} = $ENV{XTDC_CONF_DIR} . '/xt_dc_messaging.conf';

    # Result(Set) classes may rely on XTracker::Schema already being
    # loaded, and get loaded by XTracker::Schema->load_namespaces
    # anyway, so avoid duplicating the work
    all_uses_ok except => qw(
        ^XTracker::Schema::Result(?:Set)?::.*
    );
}
