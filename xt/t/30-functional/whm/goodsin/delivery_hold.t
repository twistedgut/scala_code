#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

delivery_hold.t - Check the delivery held functionality

=head1 DESCRIPTION

Set a delivery status to on hold and check it was successful.

Set a delivery status to released and check it was successful.

#TAGS delivery goodsin whm

=cut

use FindBin::libs;


use DateTime;

use Test::XTracker::Data;
use Data::Dump qw/pp/;

# Ensure arrival_date is null if it exists to check it's set later in the test
my $po = Test::XTracker::Data->create_from_hash({
    stock_order => [{
        product => {
            variant => [
                {
                    size_id => 1,
                    stock_order_item => {
                        quantity => 1,
                    },
                },
                {
                    size_id => 5,
                    stock_order_item => {
                        quantity => 1,
                    },
                },
            ],
            delivery => {},
        },
    }],
    skip_measurements => 1,
});

check_delivery_held( $po );

done_testing;

=head2 check_delivery_held

Check the delivery held functionality

=cut

sub check_delivery_held {

    my $stock_order = $po->stock_orders->first;
    isa_ok( $stock_order, "XTracker::Schema::Result::Public::StockOrder", "Have a stock order");

    my $schema = $stock_order->result_source->schema;

    my $delivery_rs = $schema->resultset('Public::Delivery');

    my $delivery = $delivery_rs->first;

    my $hold = $delivery->on_hold;

    note pp "on_hold = " . $hold;

    if ( $hold eq '0' ) {
        _check_on_hold( $delivery );
        _check_on_release( $delivery );
    }
    elsif ( $hold eq '1') {
        _check_on_release( $delivery );
        _check_on_hold( $delivery );
    }


}

=head2 _check_on_hold

Set a delivery status to on hold and check it was successful

=cut

sub _check_on_hold {
    my ( $delivery ) = @_;

    $delivery->hold('1');
    is( $delivery->on_hold, '1', 'Delivery status successfully set to hold' );
}

=head2 _check_on_release

Set a delivery status to released and check it was successful

=cut

sub _check_on_release {
    my ( $delivery ) = @_;

    $delivery->release();
    is ( $delivery->on_hold, '0', 'Delivery status successfully released' );

}
