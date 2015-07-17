#!/opt/xt/xt-perl/bin/perl
use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

=head1 NAME

script/prl/migration/reconcile_stock.pl

=head1 DESCRIPTION

Make a stock report in both XT and all PRLs, then reconcile them
and report any differences.

=cut

use XTracker::Script::PRL::Stock::Reconcile;

# unbuffered output
local $| = 1;

my $script = XTracker::Script::PRL::Stock::Reconcile->new_with_options;
$script->invoke();

