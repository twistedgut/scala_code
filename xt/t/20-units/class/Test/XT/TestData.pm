# renamed this class from 'Test::XT::Data' because it was clashing
# with the class of the same name in: t/lib/Test/XT/Data.pm
package Test::XT::TestData;
use FindBin::libs;
use parent "NAP::Test::Class";

use strict;
use warnings;

use Test::Most;

use Test::XTracker::Data;

sub test_any_channel : Tests() {
    my $self = shift;

    my $channel = Test::XTracker::Data->any_channel();
    isa_ok(
        $channel,
        "XTracker::Schema::Result::Public::Channel",
        "Got a channel with correct class",
    );
}

1;
