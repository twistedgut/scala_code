package XTracker::Order::Functions::Return::AddItem;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

=head1 NAME

XTracker::Order::Functions::Return::AddItem

=head1 DESCRIPTION

Handler for adding additional items to an existing RMA.

=cut

use XTracker::Handler;
use XTracker::Image qw( get_images );
use XTracker::Database;
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::Database::Shipment;
use XTracker::Database::Return;
use XTracker::Database::Invoice;
use XTracker::Database::Product;
use XTracker::Database::Stock;
use XTracker::Database::Channel qw(get_channel_details);
use XTracker::EmailFunctions;
use XTracker::Utilities qw( parse_url number_in_list );
use XTracker::Constants::FromDB qw(
    :shipment_item_status
    :correspondence_templates
    :shipment_type
    :refund_charge_type
    :renumeration_type
    :renumeration_status
    :renumeration_class
);
use XTracker::Config::Local qw( returns_email localreturns_email config_var );

=head2 handler

=cut

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{SHIPMENT_ITEM_STATUS__DISPATCHED} = $SHIPMENT_ITEM_STATUS__DISPATCHED;

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Add Item to Return';
    $handler->{data}{content}       = 'ordertracker/returns/additem.tt';
    $handler->{data}{short_url}     = $short_url;

    # get order_id and shipment_id from URL
    $handler->{data}{order_id}      = $handler->{param_of}{order_id};
    $handler->{data}{shipment_id}   = $handler->{param_of}{shipment_id};
    $handler->{data}{return_id}     = $handler->{param_of}{return_id};

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back to Return', 'url' => "$short_url/Returns/View?order_id=$handler->{data}{order_id}&shipment_id=$handler->{data}{shipment_id}&return_id=$handler->{data}{return_id}" } );

    # get shipment info required
    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{channel}           = get_channel_details( $handler->{dbh}, $handler->{data}{order}{sales_channel} );
    $handler->{data}{invoice_address}   = get_address_info( $handler->{dbh}, $handler->{data}{order}{invoice_address_id} );
    $handler->{data}{shipment_info}     = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
    $handler->{data}{shipment_address}  = get_address_info( $handler->{dbh}, $handler->{data}{shipment_info}{shipment_address_id} );
    $handler->{data}{shipment_items}    = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );
    $handler->{data}{return}            = get_return_info( $handler->{dbh}, $handler->{data}{return_id} );
    #$handler->{data}{return_items}     = get_return_item_info( $handler->{dbh}, $handler->{data}{return_id} );
    $handler->{data}{return_invoices}   = get_return_invoice( $handler->{dbh}, $handler->{data}{return_id} );

    # set sales channel
    $handler->{data}{sales_channel} = $handler->{data}{order}{sales_channel};


    # get all existing invoices and take value off value to be refunded
    my $invoices = get_shipment_invoices( $handler->{dbh}, $handler->{data}{shipment_id} );

    $handler->{data}{debit_total} = 0;
    $handler->{data}{previous_refund_total} = 0;

    # loop through invoices
    foreach my $inv_id ( keys %{ $invoices } ) {

        # its a refund and its not cancelled - take it into account
        if ( ($invoices->{$inv_id}{renumeration_type_id} == $RENUMERATION_TYPE__STORE_CREDIT || $invoices->{$inv_id}{renumeration_type_id} == $RENUMERATION_TYPE__CARD_REFUND) && $invoices->{$inv_id}{renumeration_status_id} < $RENUMERATION_STATUS__CANCELLED && $invoices->{$inv_id}{renumeration_class_id} != $RENUMERATION_CLASS__ORDER){

            # get invoice items
            my $items = get_invoice_item_info( $handler->{dbh}, $inv_id);

            foreach my $item_id ( keys %{ $items } ) {

                # take value of refund off shipment item value
                $handler->{data}{shipment_items}{ $items->{$item_id}{shipment_item_id} }{unit_price}    -= $items->{$item_id}{unit_price};
                $handler->{data}{shipment_items}{ $items->{$item_id}{shipment_item_id} }{tax}           -= $items->{$item_id}{tax};
                $handler->{data}{shipment_items}{ $items->{$item_id}{shipment_item_id} }{duty}          -= $items->{$item_id}{duty};
            }

            $handler->{data}{previous_refund_total} += $invoices->{$inv_id}{total};

        }

        # its a debit and its not cancelled - add to debit total value
        if ( $invoices->{$inv_id}{renumeration_type_id} == $RENUMERATION_TYPE__CARD_DEBIT && $invoices->{$inv_id}{renumeration_status_id} < $RENUMERATION_STATUS__CANCELLED){

            $handler->{data}{debit_total} += $invoices->{$inv_id}{total};

        }
    }


    $handler->{data}{num_shipment_items} = 0;

    foreach my $shipment_item_id ( keys %{ $handler->{data}{shipment_items} } ) {
        if ( number_in_list($handler->{data}{shipment_items}{$shipment_item_id}{shipment_item_status_id},
                            $SHIPMENT_ITEM_STATUS__NEW,
                            $SHIPMENT_ITEM_STATUS__SELECTED,
                            $SHIPMENT_ITEM_STATUS__PICKED,
                            $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                            $SHIPMENT_ITEM_STATUS__PACKED,
                        ) ){
            $handler->{data}{num_shipment_items}++;
        }
    }


    # get exchange sizes & images for each shipment item
    foreach my $shipment_item_id ( keys %{ $handler->{data}{shipment_items} } ) {
        if ( $handler->{data}{shipment_items}{$shipment_item_id}{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__DISPATCHED ){
            $handler->{data}{shipment_items}{$shipment_item_id}{sizes}  = get_exchange_variants( $handler->{dbh}, $shipment_item_id );
        }

        $handler->{data}{shipment_items}{$shipment_item_id}{images} = get_images({
            product_id => $handler->{data}{shipment_items}{$shipment_item_id}{product_id},
            live => 1,
            size => 'l',
            schema => $handler->schema,
        });
    }

    # list of reasons for user to select from
    $handler->{data}{reasons} = $handler->schema->resultset('Public::CustomerIssueType')->return_reasons_for_rma_pages;



    # user has selected items for return
    # validate form data
    # work out refund/debit
    # and preview email template
    if ( defined $handler->{param_of}{select_items} ) {

        $handler->{data}{form_submitted} = 1;

        push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back to Item Selection', 'url' => "$short_url/Returns/AddItem?order_id=$handler->{data}{order_id}&shipment_id=$handler->{data}{shipment_id}&return_id=$handler->{data}{return_id}" } );


        # set up some counters to keep track of things
        $handler->{data}{num_return_items}      = 0;
        $handler->{data}{num_exchange_items}    = 0;
        $handler->{data}{charge_tax}            = 0;
        $handler->{data}{charge_duty}           = 0;

        # populate the list of selected return items.
        _populate_selected_return_items( $handler );

        # process return items
        _process_items( $handler );

        # build customer email template
        _build_return_email( $handler );

    }

    $handler->{data}{refund_type} ||= '';

    $handler->process_template( undef );

    return OK;
}

=head2 _populate_selected_return_items( $handler )

Transform parameters passed in C<$handler>->{param_of} with a name containing
a '-' into a new HashRef with keys that use the part after the '-' (the shipment
item id). Each of these HashRefs contain keys of the part before the '-' (the
field name) and the corresponding value from the form data. Only shipment
items that are flagged as 'selected' are included in the results. The results
are placed into the C<$handler>->{data}->{return_items} HashRef.

For example:

    C<$handler>->{param_of} = {
        'selected-1'    =>  1,
        'type-1'        =>  'Return',
        'selected-2'    =>  0,
        'type-2'        =>  'Exchange',
        ...
    }

Becomes:

    C<$handler>->{data}->{return_items} = {
        1 => {
            selected    =>  1,
            type        =>  'Return',
        },
    }

=cut

sub _populate_selected_return_items {
    my ( $handler ) = @_;

    my %return_items;

    # loop over form post and get data
    # return items into a format we can use
    foreach my $form_key ( keys %{ $handler->{param_of} } ) {
        if ( $form_key =~ m/-/ ) {
            my ($field_name, $shipment_item_id) = split( /-/, $form_key );
            $return_items{ $shipment_item_id }{ $field_name }
                = $handler->{param_of}{$form_key};
        }
    }

    # Now make sure we only have the selected return items.
    $handler->{data}{return_items} = {
        map     { $_ => $return_items{ $_ } }
        grep    { ref( $return_items{ $_ } ) eq 'HASH' && $return_items{ $_ }->{selected} }
        keys    %return_items
    };

}

=head2 _build_return_email( $handler )

=cut

sub _build_return_email {

    my ( $handler ) = @_;

    my $return = $handler->{schema}->resultset('Public::Return')->find($handler->{data}{return_id});

    my $h = $handler->domain('Returns')->render_email( {
      return => $return,
      ( map { $_ => $handler->{data}{$_} } qw/
        return_items
        refund_id
        charge_tax charge_duty channel
      /)
    }, $CORRESPONDENCE_TEMPLATES__ADD_RETURN_ITEM);

    $handler->{data}{email_msg} = delete $h->{email_body};
    $handler->{data}{$_} = $h->{$_} for keys %$h;

    return;
}

=head2 _process_items( $handler )

=cut

sub _process_items {

    my ( $handler ) = @_;

    my $ship_country    = get_dbic_country( $handler->{schema}, $handler->{data}{shipment_address}{country} );

    foreach my $shipment_item_id ( keys %{ $handler->{data}{return_items} } ) {

        my $item = $handler->{data}{return_items}{$shipment_item_id};

        # increment the total number of return items
        $handler->{data}{num_return_items}++;

        # set a return value on item for backwards compatabiliy with email template
        $item->{return} = 1;

        # get reason for return from reason_id
        $item->{reason} = get_return_reason( $handler->{dbh}, $item->{reason_id} );

        # item selected for straight Return
        if ( $item->{type} eq 'Return' ) {

            # get unit price to be refunded from shipment data
            $item->{unit_price} = $handler->{data}{shipment_items}{ $shipment_item_id }{unit_price};

            # refund tax and duty for certain "reasons" for return
            # FIXME/XXX: replace these with constants from Constants::FromDB
            if ( $item->{reason} eq 'Incorrect item'
                || $item->{reason} eq 'Defective/faulty'
                || (defined $item->{full_refund} and $item->{full_refund} == 1)) {
                $item->{tax}    = $handler->{data}{shipment_items}{ $shipment_item_id }{tax};
                $item->{duty}   = $handler->{data}{shipment_items}{ $shipment_item_id }{duty};
            }
            else {
                # assume we don't refund any tax or duties
                $item->{tax}  = "0.00";
                $item->{duty} = "0.00";

                # based on the Shipping Country check to see if we can refund Tax &/or Duties

                if ( $ship_country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX ) ) {
                    $item->{tax}    = $handler->{data}{shipment_items}{ $shipment_item_id }{tax};
                }
                if ( $ship_country->can_refund_for_return( $REFUND_CHARGE_TYPE__DUTY ) ) {
                    $item->{duty}   = $handler->{data}{shipment_items}{ $shipment_item_id }{duty};
                }
            }
        }
        # item selected for Exchange
        else {

            # incerement the total number of exchange items
            $handler->{data}{num_exchange_items}++;

            # split out exchange variant and size if set
            ($item->{exchange_variant_id}, $item->{exchange_size}) = split( /-/, $item->{exchange} );

            # push the size of the exchange into hash key 'exch_size' for backwards compatabiliy with email template
            $item->{exch_size} = $item->{exchange_size};
            $item->{exch_size} =~ s/\(.*\)//gi;

            # set refund for unit price to 0
            $item->{unit_price} = '0.00';

            # don't charge extra tax and duty for countries who have tax refunded OR for faulty items'
            # FIXME/XXX: replace these with constants from Constants::FromDB
            if ( $item->{reason} eq 'Incorrect item' || $item->{reason} eq 'Defective/faulty' ) {
                $item->{tax}    = '0.00';
                $item->{duty}   = '0.00';
            }
            else {
                # assume we charge both Tax & Duties
                my $tax     = $handler->{data}{shipment_items}{ $shipment_item_id }{tax};
                my $duty    = $handler->{data}{shipment_items}{ $shipment_item_id }{duty};

                # check based on Shipping Country as to whether Tax &/or Duties should NOT be Charged
                if ( $ship_country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__TAX ) ) {
                    $tax    = 0;
                }
                if ( $ship_country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__DUTY ) ) {
                    $duty   = 0;
                }

                if ( $tax == 0) {
                    $item->{tax}    = '0.00';
                }
                else {
                    $item->{tax} = (-1 * $tax);
                }
                $handler->{data}{charge_tax} += $tax;

                if ( $duty == 0) {
                    $item->{duty}    = '0.00';
                }
                else {
                    $item->{duty} = (-1 * $duty);
                }
                $handler->{data}{charge_duty} += $duty;
            }
        }

    }

    return;

}



1;
