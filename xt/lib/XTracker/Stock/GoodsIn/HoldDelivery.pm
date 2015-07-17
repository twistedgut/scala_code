package XTracker::Stock::GoodsIn::HoldDelivery;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::XTemplate;
use XTracker::Navigation;
use XTracker::Handler;

use XTracker::Error;
use Data::Dump qw(pp);

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $delivery_id         = $handler->{request}->param('delivery_id');
    my $delivery_note_id    = $handler->{request}->param('edit');

    if ( $delivery_id ) {

        my $delivery = $handler->{schema}->resultset('Public::Delivery')->find(
            $delivery_id
        );
        $handler->{data}{delivery} = $delivery;

        # If delivery on hold
        if ( $delivery->on_hold ) {
            xt_warn(q{This delivery is on hold.});
        }
    }

    elsif ( $delivery_note_id ) {

        my $delivery_note_rs = $handler->{schema}->resultset('Public::DeliveryNote');

        $handler->{data}{delivery_note} = $delivery_note_rs->find(
            $delivery_note_id
        );
    }

    my $operator_rs = $handler->{schema}->resultset('Public::Operator');
    my $operator    = $operator_rs->get_operator($handler->{data}{operator_id});

    $handler->{data}{content}       = 'goods_in/hold_delivery.tt';
    $handler->{data}{section}       = 'Goods In';
    $handler->{data}{subsection}    = 'Hold Delivery';
    $handler->{data}{operator}      = $operator;

    # left nav links
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "javascript:history.go(-1)" } );

    $handler->process_template( undef );
    return OK;
}

1;
