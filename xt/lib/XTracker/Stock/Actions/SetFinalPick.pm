package XTracker::Stock::Actions::SetFinalPick;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Utilities qw( url_encode );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new( shift );

    my $product_id      = 0;
    my $variant_id      = 0;
    my $location        = "";
    my $redir_params    = "";
    my $schema          = $handler->schema;

    eval {
        my %vars                = ();
        my $variant_ref = ();

        my $guard = $schema->txn_scope_guard;
        foreach my $key (keys %{ $handler->{param_of} }){
            my ($action, $qid) = split /_/, $key;
            next unless ($action eq 'delete' && $qid =~ m/^\d+$/);
            my $quantity = $schema->resultset('Public::Quantity')->find($qid);
            die "Quantity with id $qid not found" unless $quantity;
            die "Quantity with id $qid is not empty" if $quantity->quantity != 0;

            # go for it
            $quantity->delete_and_log($handler->operator_id);
        }
        $guard->commit;
    };
    if ($@) {
        xt_warn($@);
    }

    return $handler->redirect_to('/StockControl/FinalPick'.$redir_params);
}

1;
