#!/usr/bin/env perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Test::More tests => 2;

# THIS MODULE EXISTS PURELY TO MAKE SURE THAT XTracker::Schema ACTUALLY LOADS
# WITHOUT ERRORS, AND SUPPORTS ANTICIPATED FUNCTIONS
# SEE OTHER .t FILES FOR ACTUAL TABLE BASED TESTS

use_ok('XTracker::Schema');

can_ok(
    'XTracker::Schema',
    qw/
        lookup_dictionary_by_name
    /
);
