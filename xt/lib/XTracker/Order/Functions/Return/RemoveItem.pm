package XTracker::Order::Functions::Return::RemoveItem;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Image qw( get_images );
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Return;
use XTracker::Database::Invoice;
use XTracker::Database::Channel qw(get_channel_details);
use XTracker::EmailFunctions;
use XTracker::Config::Local qw( returns_email localreturns_email );
use XTracker::Constants::FromDB qw( :return_item_status :shipment_item_status :correspondence_templates :shipment_type :renumeration_type :renumeration_status :renumeration_class );
use XTracker::Utilities qw( parse_url );


### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Remove Return Item';
    $handler->{data}{content}       = 'ordertracker/returns/removeitem.tt';
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
    $handler->{data}{return_items}      = get_return_item_info( $handler->{dbh}, $handler->{data}{return_id} );
    $handler->{data}{return_invoices}   = get_return_invoice( $handler->{dbh}, $handler->{data}{return_id} );

    # set sales channel
    $handler->{data}{sales_channel} = $handler->{data}{order}{sales_channel};

    $handler->{data}{num_return_items} = 0;

    foreach my $id ( keys %{ $handler->{data}{return_items} } ) {
        if ( $handler->{data}{return_items}{$id}{return_item_status_id} < $RETURN_ITEM_STATUS__CANCELLED ) {
            $handler->{data}{num_return_items}++;
        }

        # get product images
        my $shipment_item_id = $handler->{data}{return_items}{$id}{shipment_item_id};
        $handler->{data}{return_items}{$id}{images} = get_images({
            product_id => $handler->{data}{shipment_items}{$shipment_item_id}{product_id},
            live => 1,
            size => 'l',
            schema => $handler->schema,
        });
    }

    # user has selected items to be removed
    # validate form data
    # work out refund/debit
    # and preview email template
    if ( defined $handler->{param_of}{select_items} ) {

        $handler->{data}{form_submitted} = 1;

        push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back to Item Selection', 'url' => "$short_url/Returns/RemoveItem?order_id=$handler->{data}{order_id}&shipment_id=$handler->{data}{shipment_id}&return_id=$handler->{data}{return_id}" } );


        # set up a counter to track number of items being removed
        $handler->{data}{num_remove_items}      = 0;

        # loop over form post and get data
        # return items into a format we can use
        foreach my $form_key ( keys %{ $handler->{param_of} } ) {
            if ( $form_key =~ m/-/ ) {
                my ($field_name, $shipment_item_id) = split( /-/, $form_key );
                $handler->{data}{return_items}{ $shipment_item_id }{ $field_name } = $handler->{param_of}{$form_key};
            }
        }

        # process return items
        _process_items( $handler );

        # build customer email template
        _build_return_email( $handler );

    }

    return $handler->process_template( undef );
}


sub _build_return_email {

    my ( $handler ) = @_;

    my $return = $handler->{schema}->resultset('Public::Return')->find($handler->{data}{return_id});

    my $h = $handler->domain('Returns')->render_email( {
      return => $return,
      channel => $handler->{data}{channel},
      return_items => $handler->{data}{return_items},
    }, $CORRESPONDENCE_TEMPLATES__REMOVE_RETURN_ITEM);

    $handler->{data}{email_msg} = delete $h->{email_body};
    $handler->{data}{$_} = $h->{$_} for keys %$h;

}


sub _process_items {

    my ( $handler ) = @_;

    foreach my $shipment_item_id ( keys %{ $handler->{data}{return_items} } ) {

        my $item = $handler->{data}{return_items}{$shipment_item_id};

        if ( $item->{selected} && ($item->{selected} == 1)) {

            # increment the total number of items removed
            $handler->{data}{num_remove_items}++;

            # set a remove value on item for backwards compatabiliy with email template
            $item->{remove} = 1;

        }
        # item NOT selected for return/exchange
        else {
            # nothing to do
        }
    }

    # loop over invoices to work out what we need to remove for items
    foreach my $inv_id ( keys %{ $handler->{data}{return_invoices} } ) {

        $handler->{data}{return_invoices}{$inv_id}{items} = get_invoice_item_info( $handler->{dbh}, $inv_id );

        my $items = $handler->{data}{return_invoices}{$inv_id}{items};

        foreach my $inv_item_id ( keys %{ $items } ) {

            # remove unit price
            if ( $items->{$inv_item_id}{unit_price} != 0 ){
                $items->{$inv_item_id}{unit_price} = $items->{$inv_item_id}{unit_price} * -1;
            }

            # remove tax
            if ( $items->{$inv_item_id}{tax} != 0 ){
                $items->{$inv_item_id}{tax}= $items->{$inv_item_id}{tax} * -1;
            }

            # remove duty
            if ( $items->{duty} && ($items->{duty} != 0) ){
                $items->{$inv_item_id}{duty} = $items->{$inv_item_id}{duty} * -1;
            }

            # check status of existing refund/debit to work out if we need to update it or create a new one
            foreach my $ret_item_id ( keys %{ $handler->{data}{return_items} } ){
                if ( $handler->{data}{return_items}{$ret_item_id}{remove}
                    && ($handler->{data}{return_items}{$ret_item_id}{remove} == 1)
                    && ($items->{$inv_item_id}{shipment_item_id} == $handler->{data}{return_items}{$ret_item_id}{shipment_item_id}) ){
                    if (!defined($handler->{data}{return_invoices}{$inv_id}{$inv_id}{renumeration_status_id})
                        || ($handler->{data}{return_invoices}{$inv_id}{$inv_id}{renumeration_status_id} < $RENUMERATION_STATUS__PRINTED) ){
                        $handler->{data}{invoice_remove}{$inv_id}{$inv_item_id} = 1;
                    }
                    elsif ( $handler->{data}{return_invoices}{$inv_id}{renumeration_status_id} < $RENUMERATION_STATUS__CANCELLED ){
                        $handler->{data}{invoice_create}{$inv_item_id} = $inv_id;
                    }
                }
            }
        }
    }

    return;

}


1;
