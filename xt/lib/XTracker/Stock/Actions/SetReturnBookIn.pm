package XTracker::Stock::Actions::SetReturnBookIn;

use strict;
use warnings;

use Carp;

use DateTime;

use XTracker::Handler;
use XTracker::Barcode;
use XTracker::Constants::FromDB qw(
    :correspondence_templates
    :customer_issue_type
    :delivery_item_status
    :delivery_status
    :delivery_type
    :renumeration_status
    :renumeration_type
    :return_item_status
    :return_status
    :shipment_item_status
    :stock_process_status
    :stock_process_type
    :shipment_status
);
use XTracker::Error;
use XTracker::Database::Address;
use XTracker::Database::Channel qw(get_channel_details);
use XTracker::Database::Delivery;
use XTracker::Database::Invoice;
use XTracker::Database::Logging;
use XTracker::Database::Order;
use XTracker::Database::Product;
use XTracker::Database::Return;
use XTracker::Database::Shipment;
use XTracker::Database::Stock;
use XTracker::Database::StockProcess;
use XTracker::Database::Customer;

use XTracker::Document::ReturnDeliveryForm;

use XTracker::EmailFunctions;
use XTracker::Error;
use XTracker::PrintFunctions;
use XTracker::PrinterMatrix;
use XTracker::Utilities qw(
    url_encode
    ucfirst_roman_characters
);
use XTracker::Config::Local qw( config_var returns_email );
use XTracker::Constants::FromDB qw/ :shipment_class :delivery_type :delivery_item_type /;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    # where to redirect back to after updates
    my $redirect_url = '/GoodsIn/ReturnsIn';

    # get return id from form vars
    my $return_id =  $handler->{request}->param('return_id');
    my $schema = $handler->schema;
    my $op_pref = $schema->resultset('Public::OperatorPreference')
                         ->search({operator_id=>$handler->operator_id})
                         ->slice(0,0)
                         ->single;

    return $handler->redirect_to( $redirect_url ) unless $return_id;

    # email customer care for cancelled return received
    if ( $handler->{request}->param('email_cc') ){
        _email_customer_care($handler->dbh, $return_id);
        return $handler->redirect_to( $redirect_url );
    }

    # if we get here we can book in the return

    eval{
        my $guard = $schema->txn_scope_guard;
        my $dbh = $schema->storage->dbh;

        # We don't allow returning lost returns
        my $return = $schema->resultset('Public::Return')->find(
            $return_id, { for => 'update' }
        );
        die "Cannot book in a return that is lost\n" if $return->is_lost;

        _book_in_return($schema, $handler, $return_id, $op_pref);

        my $order = $return->discard_changes->shipment->order;
        if ( $order ) {
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::Orders::Update',
                { order_id => $order->id, }
            );
        }
        $guard->commit;
        xt_success( 'Successfully booked in return' );
    };
    # db updates not successful
    if ($@) {
        xt_warn( "There was a problem trying to process this return:<br/>$@" );
    }

    return $handler->redirect_to( $redirect_url );
}

sub _book_in_return {
    my ($schema, $handler, $return_id, $op_pref) = @_;

    # hash of booked in items
    my %booked_items = ();

    # loop through form vars to pick up booked in items
    foreach my $form_key ( %{ $handler->{param_of} } ) {
        if ( $form_key =~ m/-/ ) {

            my ($field_name, $item_id) = split /-/, $form_key;

            # item field
            if ( $field_name eq "book" ) {

                # set booked flag for item
                $booked_items{$item_id}{booked} = 1;
            }
        }
    }

    return unless %booked_items;
    # something was booked in

    my $dbh = $schema->storage->dbh;

    # Get return DB object
    my $return = $schema->resultset('Public::Return')->find( $return_id );

    my $return_item_info = get_return_item_info($dbh, $return_id);

    # update status of return to 'Processing'
    update_return_status( $dbh, $return_id, $RETURN_STATUS__PROCESSING );
    log_return_status( $dbh, $return_id, $RETURN_STATUS__PROCESSING, $handler->{data}{operator_id} );

    # update the return_arrival record for the airwaybill where the processed_goods_in field is false
    $handler->{param_of}{'airwaybill'} =~ s/[^A-z0-9]//g;
    update_return_arrival_AWB( $dbh, $handler->{param_of}{'airwaybill'} );

    # hash ref of delivery items to create delivery later
    my $di_ref = ();

    # Work out from the shipping id what delievery_type we should use (e.g is this a customer or a sample return?)
    my ($delivery_type, $delivery_item_type) = _work_out_delivery_type($schema, $return->shipment_id);

    # loop over booked in items and set status
    foreach my $return_item_id ( keys %booked_items ) {

        # check status is correct to be booked in
        die "SKU $return_item_info->{$return_item_id}{sku} (return item $return_item_id) has already been booked.\n"
            unless $return_item_info->{$return_item_id}{return_item_status_id} == $RETURN_ITEM_STATUS__AWAITING_RETURN;

        # set status of return item & log it
        update_return_item_status(
            $dbh,
            $return_item_id,
            $RETURN_ITEM_STATUS__BOOKED_IN
        );
        log_return_item_status(
            $dbh,
            $return_item_id,
            $RETURN_ITEM_STATUS__BOOKED_IN,
            $handler->{data}{operator_id}
        );

        # set awb and correct variant fields for return item
        update_return_item_received(
            $dbh,
            $return_item_id,
            $handler->{param_of}{'airwaybill'}
        );

        # update shipment item status and log
        update_shipment_item_status(
            $dbh,
            $return_item_info->{$return_item_id}{shipment_item_id},
            $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED
        );
        log_shipment_item_status(
            $dbh,
            $return_item_info->{$return_item_id}{shipment_item_id},
            $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
            $handler->{data}{operator_id}
        );

        # pass item into delivery item data
        push @{$di_ref}, {
            return_item_id => $return_item_id,
            packing_slip   => 1,
            type_id        => $delivery_item_type,
        };
    }

    # create delivery and delivery items for return
    my $delivery_id = _create_return_delivery($dbh, $di_ref, $delivery_type, $return->shipment_id);

    # Print delivery sheet to returns printer
    my $location = ( $handler->operator->operator_preference )
        ? $handler->operator->operator_preference->printer_station_name
        : undef;

    if ( $location ) {
        XTracker::Document::ReturnDeliveryForm
            ->new(delivery_id => $delivery_id)
            ->print_at_location($location);

        log_shipment_document(
            $dbh,
            $return->shipment_id,
            'Return Delivery Form',
            'returndel-' . $delivery_id,
            $location
        );
    } else {
        die 'No preferences found for operator: ' . $handler->operator->username;
    }

    # send email to customer
    if ( $handler->{param_of}{'email'} eq 'yes' ){
        _email_customer($schema, $return_id, \%booked_items, $return_item_info, $handler->{data}{operator_id});
    }
    return;
}

sub _email_customer {
    my ($schema, $return_id, $booked_item_ref, $return_item_ref, $operator_id) = @_;

    my $dbh = $schema->storage->dbh;

    # flags for conditional email content
    my $alt_refund      = 0;
    my $damaged_item    = 0;
    my $waiting_debit   = 0;
    my $refund_type_id  = 0;
    my $dispatch_return = 0;

    # get return info and return invoices
    my $return_info = get_return_info($dbh, $return_id);
    my $invoices    = get_return_invoice($dbh, $return_id);

    # loop over return items and check returns reasons
    foreach my $item_id ( keys %{$return_item_ref} ){
        if ($return_item_ref->{$item_id}{customer_issue_type_id} == $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY){
            $damaged_item = 1;
        }

        if ($return_item_ref->{$item_id}{customer_issue_type_id} == $CUSTOMER_ISSUE_TYPE__7__DISPATCH_FSLASH_RETURN){
            $dispatch_return = 1;
        }
    }

    # loop over invoices to get template info
    foreach my $renum_id ( keys %{$invoices} ){

        # alt customer number set for store credit
        if (defined $invoices->{$renum_id}{alt_customer_nr}
                && $invoices->{$renum_id}{alt_customer_nr} != 0){
            $alt_refund = 1;
        }

        # debit still awaiting authorisation
        if ($invoices->{$renum_id}{renumeration_type_id} == $RENUMERATION_TYPE__CARD_DEBIT && $invoices->{$renum_id}{renumeration_status_id} == $RENUMERATION_STATUS__AWAITING_AUTHORISATION){
            $waiting_debit = 1;
        }

        # refund not completed or cancelled yet
        if ($invoices->{$renum_id}{renumeration_status_id} < $RENUMERATION_STATUS__COMPLETED){
            $refund_type_id = $invoices->{$renum_id}{renumeration_type_id};
        }
    }

    # if not an alt customer receiving credit
    # and not a damaged item being returned
    # and not a dispatch/return
    # then send customer an email confirming arrival
    if ($alt_refund == 0 && $damaged_item == 0 && $dispatch_return == 0){

        # build up data required for customer email
        my $email_data;

        $email_data->{return}            = $return_info;
        $email_data->{shipment}          = get_shipment_info($dbh, $return_info->{shipment_id});
        $email_data->{order}             = get_order_info($dbh, $email_data->{shipment}{orders_id});
        $email_data->{channel}           = get_channel_details( $dbh, $email_data->{order}{sales_channel} );
        $email_data->{shipment_item}     = get_shipment_item_info($dbh, $return_info->{shipment_id});

        my $shipping_address             = get_address_info($dbh, $email_data->{shipment}{shipment_address_id});

        $email_data->{shipping_address}  = $shipping_address;
        $email_data->{item_info}         = $return_item_ref;
        $email_data->{waiting_debit}     = $waiting_debit;
        $email_data->{refund_type_id}    = $refund_type_id;

        $email_data->{shipping_address}{first_name} = ucfirst_roman_characters($email_data->{shipping_address}{first_name});
        $email_data->{customer}          = get_customer_info( $dbh, $email_data->{order}{customer_id} );
        $email_data->{business}          = $email_data->{channel}{config_section} eq 'OUTNET' ? 'THE OUTNET' : $email_data->{channel}{business};

        my $shipment    = $schema->resultset('Public::Shipment')->find( $return_info->{shipment_id} );
        my $return_obj  = $schema->resultset('Public::Return')->find( $return_id );

        $email_data->{payment_info} = $shipment->get_payment_info_for_tt;

        $email_data->{branded_salutation}= $shipment->branded_salutation;

        # CANDO-1335
        $email_data->{is_exchange_shipment_cancelled } = 0;
        if ( $return_obj->exchange_shipment && $return_obj->exchange_shipment->is_cancelled )
        {
            #set flag
            $email_data->{is_exchange_shipment_cancelled } = 1;
        }

        # check which items from return are recieved and which aren't
        foreach my $item_id ( keys %{$return_item_ref} ){

            # item booked in this process
            if ( $booked_item_ref->{$item_id} ){
                $email_data->{returned}{$item_id} = 1;
            }
            # item not booked in this process
            else {

                # item still awaiting return
                if ($return_item_ref->{$item_id}{return_item_status_id} < $RETURN_ITEM_STATUS__BOOKED_IN){
                    $email_data->{notreturned}{$item_id} = 1;
                }
            }

        }

        # build template
        $email_data->{order_number} = $email_data->{order}{order_nr};       # use a standard placeholder for the Order Number
        my $email_template = get_and_parse_correspondence_template( $schema, $CORRESPONDENCE_TEMPLATES__RETURN_RECEIVED, {
                                                                channel     => $shipment->get_channel,
                                                                data        => $email_data,
                                                                base_rec    => $return_obj,
                                                        } );

        # get returns email for from address
        my $customer_obj    = $return_obj->next_in_hierarchy_from_class( 'Customer', 'Customer', { stop_if_me => 1 } );
        my $returns_email   = returns_email( $email_data->{channel}{config_section}, {
            schema  => $schema,
            locale  => ( $customer_obj ? $customer_obj->locale : '' ),
        } );

        eval{
            # send email
            my $email_sent  = send_customer_email( {
                                                to          => $email_data->{shipment}{email},
                                                from        => $returns_email,
                                                subject     => $email_template->{subject},
                                                content     => $email_template->{content},
                                                content_type=> $email_template->{content_type},
                                            } );

            # log it is successful
            if ($email_sent == 1){
                $shipment->log_correspondence( $CORRESPONDENCE_TEMPLATES__RETURN_RECEIVED, $operator_id );
            }
        };
        if ($@){
            my $msg = "RMA: ".$return_info->{rma_number}."\n\nInvalid email address - unable to send an email to the customer when booking the return. Please investigate and correct accordingly.\n\n\n$@";
            my $subject = 'Invalid email detected';
            _email_customer_care($dbh, $return_id, $msg, $subject);
        }
    }
}

sub _create_return_delivery {
    my ($dbh, $di_ref, $delivery_type, $shipment_id) = @_;

    # create delivery
    my $delivery_id = create_delivery($dbh, { delivery_type_id => $delivery_type, delivery_items => $di_ref, shipment_id => $shipment_id } );

    # set delivery status
    set_delivery_status( $dbh, $delivery_id, 'delivery_id', $DELIVERY_STATUS__COUNTED );

    # get id's of items we've just created
    my $qry = "SELECT id FROM delivery_item WHERE delivery_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($delivery_id);

    while (my $row = $sth->fetchrow_arrayref()){

        my $del_item_id = $row->[0];
        my $quantity    = 1;

        # update delivery item quantity
        set_delivery_item_quantity( $dbh, $del_item_id, $quantity );

        # update delivery item status
        set_delivery_item_status( $dbh, $del_item_id, 'delivery_item_id', $DELIVERY_ITEM_STATUS__COUNTED);

        # create stock process
        my $group = 0;
        create_stock_process( $dbh, $STOCK_PROCESS_TYPE__MAIN, $del_item_id, $quantity, \$group );
    }

    return $delivery_id;
}

=head2 _work_out_delivery_type

    Work out the delivery types we should use when creating the delivery db entries for this return.

    param - $schema : DBIX::Class schema object
    param - $shipment_id : PK identifier for this return's db.public.shipment entry

    return - $delivery_type_id - delivery_type_id to use
    return - $delivery_item_type_id - delivery_item_type_id to use
=cut
sub _work_out_delivery_type {
    my ($schema, $shipment_id) = @_;

    my $shipment = $schema->resultset('Public::Shipment')->find({ id => $shipment_id })
        // Carp::confess("No shipment could be found!");

    # Work out return type based on shipment_class

    # Is this a Samples Return?
    my $shipment_class_id = $shipment->shipment_class_id;
    if(grep { $shipment_class_id == $_ } ($SHIPMENT_CLASS__SAMPLE, $SHIPMENT_CLASS__PRESS, $SHIPMENT_CLASS__TRANSFER_SHIPMENT)) {
        return ($DELIVERY_TYPE__SAMPLE_RETURN, $DELIVERY_ITEM_TYPE__SAMPLE_RETURN);
    }

    # No, must be a Customer Return then
    return ($DELIVERY_TYPE__CUSTOMER_RETURN, $DELIVERY_ITEM_TYPE__CUSTOMER_RETURN);
}

### Subroutine : _email_customer_care           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _email_customer_care {

    my ($dbh, $return_id, $msg, $subject) = @_;

    # get return info
    my $return_info     = get_return_info($dbh, $return_id);
    my $shipment_info   = get_shipment_info($dbh, $return_info->{shipment_id});
    my $order_info      = get_order_info($dbh, $shipment_info->{orders_id});
    my $channel_info    = get_channel_details( $dbh, $order_info->{sales_channel} );

    # get returns email
    my $returns_email   = returns_email( $channel_info->{config_section} );

    $subject //= 'Cancelled RMA Received';
    $msg //= "RMA: ".$return_info->{rma_number}."\n\nReturn received after cancellation of RMA.  Please investigate and contact the Returns Department with further instructions.";

    # send it
    send_email( config_var('Email', 'xtracker_email'), config_var('Email', 'xtracker_email'), $returns_email, $subject, $msg );
}

1;
