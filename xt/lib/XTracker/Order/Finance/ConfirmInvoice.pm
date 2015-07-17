package XTracker::Order::Finance::ConfirmInvoice;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Config::Local         qw( instance );
use XTracker::Constants             qw( :refund_error_messages );
use XTracker::Constants::FromDB     qw(
                                        :department
                                        :country
                                        :sub_region
                                        :shipment_item_status
                                        :refund_charge_type
                                        :renumeration_type
                                    );
use XTracker::Error;
use XTracker::Image;
use XTracker::Utilities qw( parse_url );
use XTracker::Database::Address;
use XTracker::Database::Invoice     qw( :DEFAULT payment_can_allow_goodwill_refund_for_card );
use XTracker::Database::Order;
use XTracker::Database::Shipment;

use XTracker::Order::Printing::RefundForm;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{SHIPMENT_ITEM_STATUS__DISPATCHED}=$SHIPMENT_ITEM_STATUS__DISPATCHED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__RETURN_PENDING}=$SHIPMENT_ITEM_STATUS__RETURN_PENDING;
    $handler->{data}{SHIPMENT_ITEM_STATUS__RETURN_RECEIVED}=$SHIPMENT_ITEM_STATUS__RETURN_RECEIVED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__RETURNED}=$SHIPMENT_ITEM_STATUS__RETURNED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__CANCEL_PENDING}=$SHIPMENT_ITEM_STATUS__CANCEL_PENDING;
    $handler->{data}{SHIPMENT_ITEM_STATUS__CANCELLED}=$SHIPMENT_ITEM_STATUS__CANCELLED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__LOST}=$SHIPMENT_ITEM_STATUS__LOST;
    $handler->{data}{SHIPMENT_ITEM_STATUS__UNDELIVERED}=$SHIPMENT_ITEM_STATUS__UNDELIVERED;

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Confirm Invoice';
    $handler->{data}{content}       = 'ordertracker/finance/viewinvoice.tt';
    $handler->{data}{short_url}     = $short_url;

    # get url params
    $handler->{data}{order_id}      = $handler->{param_of}{order_id};
    $handler->{data}{shipment_id}   = $handler->{param_of}{shipment_id};
    $handler->{data}{action}        = $handler->{param_of}{action};
    $handler->{data}{invoice_id}    = $handler->{param_of}{invoice_id};
    $handler->{data}{invalid}       = $handler->{param_of}{invalid} || 0;
    $handler->{data}{edit_error}    = $handler->{param_of}{edit_error} || 0;

    # set form action url
    $handler->{data}{form_submit}   = $short_url.'/CreateInvoice?order_id='.$handler->{data}{order_id}.'&shipment_id='.$handler->{data}{shipment_id};

    # get db info
    $handler->{data}{invoice}       = get_invoice_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
    $handler->{data}{order}         = get_order_info($handler->{dbh}, $handler->{data}{order_id});
    $handler->{data}{sales_channel} = $handler->{data}{order}{sales_channel};
    $handler->{data}{shipment}      = get_shipment_info($handler->{dbh}, $handler->{data}{shipment_id});
    $handler->{data}{shipment_item} = get_shipment_item_info($handler->{dbh}, $handler->{data}{shipment_id});
    $handler->{data}{promotions}    = get_shipment_promotions( $handler->{dbh}, $handler->{data}{shipment_id} );

    # check 'invoice_reason' field has a value
    my $invoice_reason_id   = $handler->{param_of}{invoice_reason} // '';
    $invoice_reason_id      =~ s/[^\d]//g;
    my $invoice_reason      = $handler->schema->resultset('Public::RenumerationReason')
                                                ->find( $invoice_reason_id || -1 );
    if ( !$invoice_reason ) {
        xt_warn( "Please Specify a Reason for the Invoice" );
        return $handler->redirect_to(
            $short_url . '/Invoice?action=Create'
                       . '&order_id='    . $handler->{data}{order_id}
                       . '&shipment_id=' . $handler->{data}{shipment_id}
        );
    }
    else {
        # store it for the page
        $handler->{data}{invoice_reason} = $invoice_reason;
    }

    my $shipment = $handler->{schema}->resultset('Public::Shipment')->find( $handler->{data}{shipment_id} );
    my $order    = $shipment->order;

    # check the Payment Method can handle a pure Goodwill Refund to Credit Card
    my $can_proceed = payment_can_allow_goodwill_refund_for_card(
        $order,
        $handler->{param_of}{misc_refund},
        $handler->{param_of}{type_id},
    );
    unless ( $can_proceed ) {
        my $payment_method = $order->payments->first->payment_method->payment_method;
        xt_warn( sprintf( $GOODWILL_REFUND_AGAINST_CARD_ERR_MSG, $payment_method ) );
        return $handler->redirect_to(
            $short_url . '/Invoice?action=Create'
                       . '&order_id='    . $handler->{data}{order_id}
                       . '&shipment_id=' . $handler->{data}{shipment_id}
       );
    }

    # sum up promotion value applied to each item for markdown calculations
    foreach my $promo ( keys %{ $handler->{data}{promotions} }) {
        if ( $handler->{data}{promotions}{$promo}{items} ) {
            foreach my $itemid ( keys %{ $handler->{data}{promotions}{$promo}{items} } ) {
                $handler->{data}{shipment_item}{$itemid}{promotion_unit_price}
                    += $handler->{data}{promotions}{$promo}{items}{$itemid}{unit_price};
                $handler->{data}{shipment_item}{$itemid}{promotion_tax}
                    += $handler->{data}{promotions}{$promo}{items}{$itemid}{tax};
                $handler->{data}{shipment_item}{$itemid}{promotion_duty}
                    += $handler->{data}{promotions}{$promo}{items}{$itemid}{duty};
            }
        }
    }

    # Get images for the products
    foreach my $id ( keys %{$handler->{data}{shipment_item}} ) {
        $handler->{data}{shipment_item}{$id}{image}
            = XTracker::Image::get_images({
                product_id => $handler->{data}{shipment_item}{$id}{product_id},
                live => 1,
                schema => $handler->schema,
            });
    }

    # get the shipment address
    $handler->{data}{shipment_address} = get_address_info( $handler->{dbh}, $handler->{data}{shipment}{shipment_address_id} );

    # use the shipment country to get country info
    my $country_info = get_country_info( $handler->{dbh}, $handler->{data}{shipment_address}{country} );

    # Identify xtracker version
    my $xt_version = instance();


    # flag as a Gratuity Invoice
    $handler->{data}{for_gratuity}  = 1;

    # form fields
    $handler->{data}{type_id}       = $handler->{param_of}{type_id};
    $handler->{data}{shipping}      = d2( $handler->{param_of}{shipping} ) || 0.00;
    $handler->{data}{misc_refund}   = d2( $handler->{param_of}{misc_refund} ) || 0.00;

    #get shipment country
    my $ship_country= $shipment->shipment_address->country_table;


    # loop over refund items
    foreach my $form_field ( %{ $handler->{param_of} } ) {

        # Populate markdown fields for shipment items
        if ( $form_field =~ /^(applied_markdown|current_markdown)_(\d+)/ ) {
            $handler->{data}{shipment_item}{$2}{$1} = $handler->{param_of}{$form_field};
        }

        if ( $form_field =~ /^(apply|unit_price|tax|duty)_(\d+)/ ) {
            my $field_type = $1;
            my $item_id = $2;

            # If automatic refund already applied
            next if exists $handler->{data}{shipment_item}{$item_id}{refund}{auto};

            # If manual refund already applied
            next if exists $handler->{data}{shipment_item}{$item_id}{refund}{manual};

            my $current_markdown = $handler->{param_of}{"current_markdown_$item_id"};
            my $applied_markdown = $handler->{param_of}{"applied_markdown_$item_id"};

            #available stock
            if ( ( $handler->{param_of}{"available_stock_$item_id"} // '' ) =~ m{(\d+)} ) {
                $handler->{data}{shipment_item}{$item_id}{available_stock} = $1;
            }

            # If manual percentage selected from dropdown list
            if ( ($handler->{param_of}{"applied_percentage_$item_id"} // '' )=~ m{(\d+)} ) {
                $handler->{data}{shipment_item}{$item_id}{refund}{manual}{applied_percentage} = $1;

                foreach my $type ( qw{unit_price tax duties} ) {
                    $handler->{data}{shipment_item}{$item_id}{refund}{manual}{$type}
                        = d2(
                            $handler->{data}{shipment_item}{$item_id}{$type}
                          * $1
                          / 100
                        )
                    ;
                }
                next;
            }

            # If automatic refund checkbox selected
            if ( $field_type eq 'apply' ) {

                # Reset item's tax and duty refunds
                $handler->{data}{shipment_item}{$item_id}{refund}{tax} = 0.00;
                $handler->{data}{shipment_item}{$item_id}{refund}{duty} = 0.00;

                # Automatic tax refund
                if( $ship_country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX )  )
                {
                        $handler->{data}{shipment_item}{$item_id}{refund}{tax} = d2(
                            calculate_refund(
                                $handler->{data}{shipment_item}{$item_id}{tax},
                                $applied_markdown,
                                $current_markdown,
                                $handler->{data}{shipment_item}{$item_id}{promotion_tax},
                            )
                        );
                }

                # Apply automatic refund for unit_price, tax, duty for item
                $handler->{data}{shipment_item}{$item_id}{refund}{unit_price} = d2(
                    calculate_refund(
                        $handler->{data}{shipment_item}{$item_id}{unit_price},
                        $applied_markdown,
                        $current_markdown,
                        $handler->{data}{shipment_item}{$item_id}{promotion_unit_price},
                    )
                );

                $handler->{data}{shipment_item}{$item_id}{refund}{auto} = 1;
            }

            # If textboxes filled manually and automatic refund not checked
            elsif ( $handler->{param_of}{$form_field} != 0 ) {
                $handler->{data}{shipment_item}{$item_id}{refund}{$field_type}
                    = d2($handler->{param_of}{$form_field});
            }
        }
    }


    $handler->{data}{sidenav} = [
        { 'None' => [
            {
                'title' => 'Back',
                'url'   => $short_url.'/Invoice?order_id='.$handler->{data}{order_id}.'&shipment_id='.$handler->{data}{shipment_id}.'&action=Create',
            }
        ]}
    ];
    return $handler->process_template( undef );
}

### Subroutine : calculate_refund               ###
# usage        : calculate_refund( $amount,       #
#                                  $applied,      #
#                                  $current)      #
# description  : Calculates the customer's refund #
#                given the amount the customer    #
#                paid, the markdown at shipping   #
#                and returns the amount to be     #
#                returned looking at the current  #
#                markdown                         #
# parameters   : $amount, $applied, $current      #
# returns      : $refund                          #

sub calculate_refund {
    my ( $amount, $applied_discount, $current_discount, $promotion_value ) = @_;

    my $refund        = 0;
    my $full_price    = 0;
    my $current_price = 0;

    # If there is a non-zero current markdown
    if ( $current_discount ) {

        # add applied discount & promotions to get back to full price
        $promotion_value =  0 unless ( defined $promotion_value) ;
        $full_price = ($amount + $promotion_value) * ( 100 / ( 100 - $applied_discount ) );

        # apply current markdown to full price
        $current_price = $full_price * ( 1 - ( $current_discount / 100 ) );

        # refund the difference between current and paid
        $refund = $amount - $current_price;
    }

    return $refund;

}

### Subroutine : d2                             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub d2 {
    my $val = shift;
    my $n = sprintf( "%.2f", $val );
    return $n;
}

1;
