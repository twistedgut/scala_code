#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use NAP::policy;

use XTracker::Script::PRL::InFlight;

XTracker::Script::PRL::InFlight->new->invoke();

