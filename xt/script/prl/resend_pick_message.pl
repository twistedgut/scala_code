#!/opt/xt/xt-perl/bin/perl
use NAP::policy qw/tt/;

=head1 NAME

script/prl/resend_pick_message.pl

=head1 DESCRIPTION

Resend the pick message for an allocation_id.

IMPORTANT: this doesn't do any db updates, it just sends the pick message,
so only use it for allocations that XT already thinks it has picked.

=head1 SYNOPSIS

    script/prl/resend_pick_message.pl \
        --allocation_id=ALLOCATION_ID

=cut

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;
use Pod::Usage;

use XTracker::Script::PRL::ResendPick;

local $| = 1;

my $result = GetOptions(
    "help"            => \( my $help ),
    "allocation_id=i" => \( my $allocation_id ),
);

pod2usage(-verbose => 2) if !$allocation_id || $help;

try {
    XTracker::Script::PRL::ResendPick->new({
        allocation_id => $allocation_id,
    })->invoke();
}
catch {
    pod2usage( -message => "$_" );
};


