package XT::DC::Controller::CustomerCare::OrderSearch::PaymentRefresh;

use NAP::policy qw(class tt);

BEGIN {extends 'Catalyst::Controller::REST'; }

use XTracker::Logfile                   qw( xt_logger );
use JSON;

__PACKAGE__->config(path => 'CustomerCare/OrderSearch/PaymentRefresh');

sub payment_refresh : Path : ActionClass('REST') {
    my ($self, $c)  = @_;
    $c->check_access('Customer Care', 'Order Search');
}

sub payment_refresh_POST {
    my ($self, $c)  = @_;

    my $schema = $c->model("DB")->schema;

    my $shipment = $schema->resultset('Public::Shipment')->find($c->req->param("shipment_id"));
    # return error if no shipment

    if (!$shipment)
    {
        $self->status_bad_request($c, message => "Cannot find shipment with ID ".$c->req->param("shipment_id"));
        xt_logger->fatal( 'cannot get shipment for shipment id ' .$c->req->param("shipment_id"));
        return;
    };

    try {
        $shipment->update_status_based_on_third_party_psp_payment_status();
    }
    catch {
        my $error = $_;
        xt_logger->warn( $error );
    };
    my $output = {on_hold => 0, order_id => $shipment->order ? $shipment->order->id : 0};
    if($shipment->discard_changes->is_held){
        $output->{on_hold} = 1;
        $output->{on_hold_for_psp} = 1 if $shipment->is_on_hold_for_third_party_psp_reason;
        $output->{shipment_hold_reason} = $shipment->shipment_holds->order_by_id_desc->first->shipment_hold_reason->reason;
    }
    $self->status_ok($c, entity => $output);
    return;
}
