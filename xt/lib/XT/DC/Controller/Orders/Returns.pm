package XT::DC::Controller::Orders::Returns;

use Moose;
use Data::Dump 'pp';
use XTracker::Logfile qw(xt_logger);

use XTracker::Constants::FromDB     qw( :renumeration_type );


BEGIN { extends 'Catalyst::Controller' };

# Used for the Returns/Create return page to get a live preview of how the
# refund will be split across card/store credit.
sub preview_refund_split : Local ActionClass('REST') {
}

# Make this a POST so IE doesn't cache it annoyingly.
sub preview_refund_split_POST {
    my ($self, $c) = @_;

    my $params = $c->req->body_params;
    my $return_items = {};

    # loop over form post and get data
    # return items into a format we can use
    foreach my $form_key ( keys %$params ) {
        if ( $form_key =~ m/^(.*?)-(\d+)$/ ) {
            my ($field_name, $shipment_item_id) = ($1,$2);
            $return_items->{ $shipment_item_id }{ $field_name } = $params->{$form_key};
        }
    }

    # Ignore items not selected for return
    for (keys %$return_items) {
        delete $return_items->{$_} unless $return_items->{$_}{selected};
    }

    if (! keys %$return_items ) {
        # Nothing selected to return
        $c->stash(json => []);
        $c->detach('/serialize');
    }

    my $split = $c->model('Returns')->get_renumeration_split({
        refund_type_id => $params->{refund_id},
        return_items => $return_items,
        shipment_id => $params->{shipment_id},
    });

    my $schema = $c->model('DB')->schema;

    my $shipment = $schema->resultset('Public::Shipment')
                            ->find( $params->{shipment_id} );
    my $order    = $shipment->order;

    # Turn the DBIC object into a string
    for (@$split) {
      # if the Refund type is for a Card Refund then check the Order to see
      # if it was actually paid using a Third Party Payment such as PayPal.
      if ( $_->{renumeration_type_id} == $RENUMERATION_TYPE__CARD_REFUND
        && $order->is_paid_using_third_party_psp ) {
          $_->{renumeration_type} = $order->get_third_party_payment_method
                                            ->payment_method . ' Account';
      }
      else {
          $_->{renumeration_type} = $schema->resultset( 'Public::RenumerationType' )
                                       ->find( $_->{renumeration_type_id} )
                                       ->type;
      }

      $_->{currency} = $order->currency->currency;
    }

    $c->stash(json => $split);
    $c->forward('/serialize');
}


1;
