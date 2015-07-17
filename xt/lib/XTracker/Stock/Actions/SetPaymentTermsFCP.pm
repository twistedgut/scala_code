package XTracker::Stock::Actions::SetPaymentTermsFCP;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Carp;
use Perl6::Export::Attrs;

use XTracker::Database 'xtracker_schema';

sub handler {
    my $r = shift;

    my $req = $r; # they're the same thing in our new Plack world

    my $referer = $r->headers_in->{referer};

    my $schema = xtracker_schema();

    my $payment_term_id                = $req->param( 'payment_term' )                || 0;
    my $payment_deposit_id             = $req->param( 'payment_deposit' )             || 0;
    my $payment_settlement_discount_id = $req->param( 'payment_settlement_discount' ) || 0;
    my $product_id                     = $req->param( 'product_id' )                  || 0;

    eval {
        $schema->txn_do(sub{
            my $dbh = $schema->storage->dbh;
            _update_payment_term( $dbh, {
                product_id => $product_id,
                payment_term_id => $payment_term_id,
                payment_deposit_id => $payment_deposit_id,
                payment_settlement_discount_id => $payment_settlement_discount_id,
            } );
        });
    };
    if ($@) {
        die "qry failed: $@";
    }

    $r->headers_out->set( Location => $referer );

    return REDIRECT;

}

sub _update_payment_term {
    my ( $dbh, $p ) = @_;

        my $qry = qq{
update product set
payment_term_id = ?,
payment_deposit_id = ?,
payment_settlement_discount_id = ?
where id = ?
};
        my $sth = $dbh->prepare( $qry );
        $sth->execute( $p->{payment_term_id}, $p->{payment_deposit_id}, $p->{payment_settlement_discount_id}, $p->{product_id} );
}

1;
