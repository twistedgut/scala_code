package Test::XT::AssertDBRecords;
use strict;
use warnings;

use base qw/Test::AssertRecords/;

sub schema_namespace {
    return 'XTracker::Schema';
}
1;
