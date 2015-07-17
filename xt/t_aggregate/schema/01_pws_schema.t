#!/usr/bin/env perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Test::More tests => 1;

# THIS MODULE EXISTS PURELY TO MAKE SURE THAT PWS::Schema ACTUALLY LOADS
# WITHOUT ERRORS, AND SUPPORTS ANTICIPATED FUNCTIONS
# SEE OTHER .t FILES FOR ACTUAL TABLE BASED TESTS

use_ok('PWS::Schema');

