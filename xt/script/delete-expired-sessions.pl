#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database ':common';

xtracker_schema->resultset('Public::Sessions')
       ->search({ last_modified => {'<' => \q{NOW() - INTERVAL '1 DAY'}}})
       ->delete
;
