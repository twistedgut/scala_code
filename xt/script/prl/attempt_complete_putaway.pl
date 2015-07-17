#!/opt/xt/xt-perl/bin/perl
use NAP::policy;

=head1 NAME

script/prl/attempt_complete_putaway.pl

=head1 DESCRIPTION

Script that for provided PGID attempts complete putaway.
Its purpose is to clean up open putaway_prep_groups
that have all containers processed but for some reasons
failed to mark as complete.

Current implementation is limited to PGID and recodes.

=head1 SYNOPSIS

    script/prl/attempt_complete_putaway.pl \
        --group_id=PGID

=cut

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;
use Pod::Usage;

use XTracker::Script::PRL::AttemptCompletePutaway;

local $| = 1;

my $result = GetOptions(
    "help"   => \( my $help ),
    "group_id=s" => \( my $group_id ),
);

pod2usage(-verbose => 2) if !$group_id || $help;

my $script;
try {
    XTracker::Script::PRL::AttemptCompletePutaway->new({
        group_id => $group_id,
    })->invoke();
}
catch {
    pod2usage( -message => "$_" );
};

