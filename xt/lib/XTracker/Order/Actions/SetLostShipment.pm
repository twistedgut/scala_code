package XTracker::Order::Actions::SetLostShipment;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Invoice;
use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :shipment_status :shipment_item_status :renumeration_status :renumeration_class :customer_issue_type );
use XTracker::Error;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    # set up vars and get query string data
    my $redirect_url;
    my $order_id    = $handler->{param_of}{order_id};
    my $shipment_id = $handler->{param_of}{shipment_id};

    eval {

        # hash to keep track of items changed
        my %change_items = ();

        foreach my $form_key ( %{ $handler->{param_of} } ) {
            if ( $form_key =~ m/-/ ) {
                my ($field_name, $item_id) = split /-/, $form_key;
                # item field
                if ( $field_name eq 'item' && $handler->{param_of}{$form_key} == 1 ) {
                    $change_items{ $item_id } = 1;
                }
            }
        }


        # no items selected by user
        if ( !keys(%change_items) ) {
            die 'No items were selected, please try again.';
        }

        # no refund type selected
        # GV:
        # The refund will be split automatically and so know need
        # for this field anymore unless future requirements want
        # any kind of manual overrides, hence I've just commented it out.
        #if ( !$handler->{param_of}{refund_type_id} ) {
        #    die 'No refund type selected, please try again.';
        #}

        my $schema  = $handler->schema;
        my $dbh = $schema->storage->dbh;;

        my $guard = $schema->txn_scope_guard;
        # get shipment & shipment items from db to validate current status against new
        my $order_info      = get_order_info($dbh, $order_id);
        my $shipment_info   = get_shipment_info( $dbh, $shipment_id );
        my $shipment_items  = get_shipment_item_info( $dbh, $shipment_id );

        # flag to indicate if all items in shipment are set to lost
        my $lost_shipment       = 0;
        my $num_shipment_items  = 0;
        my $num_already_lost    = 0;
        my $shipping_refund     = 0;

        foreach my $shipment_item_id ( keys %{ $shipment_items } ) {
            if ( $shipment_items->{$shipment_item_id}{shipment_item_status_id} != $SHIPMENT_ITEM_STATUS__CANCELLED && $shipment_items->{$shipment_item_id}{shipment_item_status_id} != $SHIPMENT_ITEM_STATUS__CANCEL_PENDING ){
                $num_shipment_items++;
            }
            if ( $shipment_items->{$shipment_item_id}{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__LOST ) {
                $num_already_lost++;
            }
        }

        # if number of items picked plus numnber of items already lost then whole Shipment is Lost!!
        if ( $num_shipment_items == ( scalar( keys(%change_items) ) + $num_already_lost ) ) {
            $lost_shipment = 1;
        }

        # final check to ensure item status is "dispatched" before setting to "lost"
        foreach my $shipment_item_id ( keys %change_items ) {
            if (  $shipment_items->{$shipment_item_id}{shipment_item_status_id} != $SHIPMENT_ITEM_STATUS__DISPATCHED ){
                die $shipment_items->{$shipment_item_id}{sku} . ' cannot be set to lost, current status: '. $shipment_items->{$shipment_item_id}{status};
            }
        }


        # update shipment as lost if all items selected
        if ( $lost_shipment == 1) {
            update_shipment_status( $dbh, $shipment_id, $SHIPMENT_STATUS__LOST, $handler->{data}{operator_id} );

            # refund shipping costs
            $shipping_refund = $shipment_info->{shipping_charge};
        }

        # create refund for items
        my $shipping        = $shipping_refund;
        my $misc_refund     = 0;
        my $alt_customer    = 0;
        my $gift_credit     = 0;
        my $store_credit    = 0;

        # create refund
        my $refund_req;

        # update items status & create refund items
        foreach my $shipment_item_id ( keys %change_items ) {

            $refund_req->{return_items}{ $shipment_item_id }    = {
                    type        => 'Return',
                    reason_id   => $CUSTOMER_ISSUE_TYPE__7__DELIVERY_ISSUE,
                    variant     => $shipment_items->{ $shipment_item_id }{variant_id},
                    _original_price => $shipment_items->{ $shipment_item_id }{unit_price},
                };

            update_shipment_item_status( $dbh, $shipment_item_id, $SHIPMENT_ITEM_STATUS__LOST );
            log_shipment_item_status( $dbh, $shipment_item_id, $SHIPMENT_ITEM_STATUS__LOST, $handler->{data}{operator_id} );
        }

        $refund_req->{operator_id}  = $handler->operator_id;
        $refund_req->{shipment_id}  = $shipment_id;
        $refund_req->{order_id}     = $order_id;
        $refund_req->{pickup}       = 'false';
        $refund_req->{shipping_refund}= $lost_shipment;
        $refund_req->{is_lost_shipment}= 1;
        my $return = $handler->domain('Returns')->lost_shipment( $refund_req );

        $guard->commit();
        # send user back to the Order View with status msg
        xt_success('Shipment updated successfully.');
        $redirect_url = "$short_url/OrderView?order_id=$order_id";
    };

    if ($@) {
        # tidy up error msg for display
        my $error   = $@;
        $error      =~ s/ at \/opt\/xt.*//;

        # redirect user back to previous page with error
        xt_warn("An error occured trying to update the shipment: $error");
        $redirect_url = "$short_url/LostShipment?order_id=$order_id&shipment_id=$shipment_id";
    }

    return $handler->redirect_to( $redirect_url );
}

1;
