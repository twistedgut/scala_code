package XTracker::Order::Finance::ViewInvoice;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Config::Local qw / can_deny_store_credit_for_channel /;
use XTracker::Database::Channel qw/ get_channel_details /;
use XTracker::Database::Invoice;
use XTracker::Database::Order;
use XTracker::Database::Stock qw( get_saleable_item_quantity );
use XTracker::Database::Shipment;
use XTracker::Database::Utilities       qw( is_valid_database_id );
use XTracker::Image;
use XTracker::Order::Printing::RefundForm;
use XTracker::Utilities qw( parse_url );
use XTracker::Constants         qw( :refund_error_messages );
use XTracker::Constants::FromDB qw( :department :shipment_item_status );
use XTracker::Error;

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

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

    $handler->{data}{section} = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'ordertracker/finance/viewinvoice.tt';
    $handler->{data}{js}            = [
        '/javascript/finance/view_invoice.js',
    ];
    $handler->{data}{short_url}     = $short_url;

    if ( defined $handler->{param_of}{invoice_id} &&
                 ! is_valid_database_id( $handler->{param_of}{invoice_id} ) ) {
        xt_error("No Invoice ID supplied on call to View Invoice");
        return $handler->process_template(undef);
    }

    # get url params
    $handler->{data}{order_id}      = $handler->{param_of}{order_id};
    $handler->{data}{shipment_id}   = $handler->{param_of}{shipment_id};
    $handler->{data}{action}        = $handler->{param_of}{action};
    $handler->{data}{invoice_id}    = $handler->{param_of}{invoice_id};
    $handler->{data}{invalid}       = $handler->{param_of}{invalid} || 0;
    $handler->{data}{why}           = $handler->{param_of}{why} || 0;
    $handler->{data}{invalid_item}  = $handler->{param_of}{invalid_item} || 0;
    $handler->{data}{edit_error}    = $handler->{param_of}{edit_error} || 0;

    my $order = $handler->schema->resultset('Public::Orders')->find( $handler->{data}{order_id} );

    $handler->{data}{deny_store_credit} = can_deny_store_credit_for_channel( $handler->schema, $order->channel->id );

    # get list of renumeration types to build select field
    $handler->{data}{renum_type}    = get_invoice_type( $handler->{dbh} );

    # get list of renumeration statuses to build select field
    $handler->{data}{renum_status}  = get_invoice_status( $handler->{dbh} );

    # auth for people to edit refunds - Customer Care Managers & Finance
    if ( grep { $_ == $handler->{data}{department_id} }
        $DEPARTMENT__FINANCE,
        $DEPARTMENT__CUSTOMER_CARE_MANAGER,
    ) {
        $handler->{data}{auth_edit} = 1;
    }

    # auth for people to amend refunds (auth debits and cancel manual refunds) - Customer Care & Shipping
    if ( grep { $_ == $handler->{data}{department_id} }
        $DEPARTMENT__CUSTOMER_CARE,
        $DEPARTMENT__CUSTOMER_CARE_MANAGER,
        $DEPARTMENT__SHIPPING, $DEPARTMENT__SHIPPING_MANAGER,
    ) {
        $handler->{data}{auth_amend} = 1;
    }

    # set-up error message for 'misc_refund' validation if the
    # Order's Payment Method doesn't allow pure Goodwill Refunds
    if ( !$order->payment_method_allows_pure_goodwill_refunds ) {
        my $payment_method = $order->payments->first->payment_method;
        $handler->{data}{validation_fields} = {
            misc_refund => {
                error_message => sprintf( $GOODWILL_REFUND_AGAINST_CARD_ERR_MSG, $payment_method->payment_method ),
            },
        };
    }


    my $schema = $handler->schema;

    my $renumeration;
    if ( is_valid_database_id( $handler->{data}{invoice_id} ) ) {
        $renumeration = $schema->resultset('Public::Renumeration')
                                ->find( $handler->{data}{invoice_id} );
    }

    $handler->{data}{renumeration}  = $renumeration;
    $handler->{data}{for_gratuity}  = (
        $handler->{data}{action} eq 'Create'
        || ( $renumeration && $renumeration->for_gratuity )
        ? 1
        : 0
    );

    # print off refund form
    if ( $handler->{data}{action} eq 'print' ) {
        generate_refund_form( $handler->{dbh}, $handler->{data}{invoice_id}, 'Finance', 1 );
    }
    # print off invoice
    elsif ( $handler->{data}{action} eq 'print_invoice' ) {
        $renumeration->generate_invoice({
            printer => 'Finance',
            copies  => 1,
        });
    }
    # we're viewing/editing an existing refund
    elsif ( ( $handler->{data}{action} eq 'Edit' || $handler->{data}{action} eq 'View' ) && $handler->{data}{invoice_id} ) {

        # set form action url
        $handler->{data}{form_submit} = $short_url.'/EditInvoice?invoice_id='.$handler->{data}{invoice_id}.'&order_id='.$handler->{data}{order_id}.'&shipment_id='.$handler->{data}{shipment_id};

        # set page title
        if ( $handler->{data}{action} eq 'Edit' ) {
            $handler->{data}{subsubsection} = 'Edit Invoice';
        }
        else {
            $handler->{data}{subsubsection} = 'View Invoice';
        }

        # get refund/shipment info
        $handler->{data}{invoice}       = get_invoice_info( $handler->{dbh}, $handler->{data}{invoice_id} );
        $handler->{data}{sales_channel} = $handler->{data}{invoice}{sales_channel};
        $handler->{data}{shipment}      = get_shipment_info($handler->{dbh}, $handler->{data}{shipment_id});

        # tidy up values for display
        $handler->{data}{invoice}{shipping}        = _d2( $handler->{data}{invoice}{shipping} );
        $handler->{data}{invoice}{misc_refund}     = _d2( $handler->{data}{invoice}{misc_refund} );
        $handler->{data}{invoice}{gift_credit}     = _d2( $handler->{data}{invoice}{gift_credit} );
        $handler->{data}{invoice}{store_credit}    = _d2( $handler->{data}{invoice}{store_credit} );
        $handler->{data}{invoice}{renum_total}     = $handler->{data}{invoice}{shipping}
                                     + $handler->{data}{invoice}{misc_refund}
                                     + $handler->{data}{invoice}{gift_credit}
                                     + $handler->{data}{invoice}{store_credit}
                                     - abs($renumeration->gift_voucher);

        $handler->{data}{invoice_item}              = get_invoice_item_info( $handler->{dbh}, $handler->{data}{invoice_id} );

        foreach my $item_id ( keys %{ $handler->{data}{invoice_item} } ) {
            $handler->{data}{invoice_item}{$item_id}{sub_total}  = _d2( $handler->{data}{invoice_item}{$item_id}{unit_price}
                                                                    + $handler->{data}{invoice_item}{$item_id}{tax}
                                                                    + $handler->{data}{invoice_item}{$item_id}{duty}
            );
            $handler->{data}{invoice_item}{$item_id}{unit_price}    = _d2( $handler->{data}{invoice_item}{$item_id}{unit_price} );
            $handler->{data}{invoice_item}{$item_id}{tax}           = _d2( $handler->{data}{invoice_item}{$item_id}{tax} );
            $handler->{data}{invoice_item}{$item_id}{duty}          = _d2( $handler->{data}{invoice_item}{$item_id}{duty} );
            $handler->{data}{invoice}{renum_total}                  += $handler->{data}{invoice_item}{$item_id}{sub_total};
        }

        $handler->{data}{invoice}{renum_total}  = _d2( $handler->{data}{invoice}{renum_total} );
        $handler->{data}{invoice_log}           = get_invoice_log_info( $handler->{dbh}, $handler->{data}{invoice_id} );
        $handler->{data}{invoice_change_log}    = get_invoice_change_log( $handler->{dbh}, $handler->{data}{invoice_id} );

    }
    # we're creating a new refund
    else {

        # set form action url
        $handler->{data}{form_submit}    = $short_url.'/ConfirmInvoice?action=Confirm&order_id='.$handler->{data}{order_id}.'&shipment_id='.$handler->{data}{shipment_id};

        # set page title
        $handler->{data}{subsubsection}  = 'Create Invoice';

        # get Renumeration Reasons
        $handler->{data}{compensation_reasons}  = [
            $schema->resultset('Public::RenumerationReason')
                ->get_compensation_reasons( $handler->department_id )
                ->enabled_only
                ->order_by_reason
                ->all
        ];

        # get order and shipment details
        $handler->{data}{order}          = get_order_info($handler->{dbh}, $handler->{data}{order_id});
        $handler->{data}{sales_channel}  = $handler->{data}{order}{sales_channel};

        # get specific shipment info if a shipment id has been passed
        if ( $handler->{data}{shipment_id} ) {

            $handler->{data}{invoice}       = get_invoice_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
            $handler->{data}{shipment}      = get_shipment_info($handler->{dbh}, $handler->{data}{shipment_id});
            $handler->{data}{shipment_item} = get_shipment_item_info($handler->{dbh}, $handler->{data}{shipment_id});

            # add markdown info for each shipment item
            foreach my $shipment_item ( keys %{$handler->{data}{shipment_item}} ) {

                $handler->{data}{shipment_item}{$shipment_item}{image}
                    = XTracker::Image::get_images({
                        product_id => $handler->{data}{shipment_item}{$shipment_item}{product_id},
                        live => 1,
                        schema => $schema,
                    });

                my $markdown_info_ref = get_markdown_info($handler->{dbh}, $shipment_item);

                $handler->{data}{shipment_item}{$shipment_item}{applied_markdown} = $markdown_info_ref->{applied_markdown};
                $handler->{data}{shipment_item}{$shipment_item}{current_markdown} = $markdown_info_ref->{current_markdown};

                #Get available stock
                my $stock =  get_saleable_item_quantity( $handler->{dbh}, $handler->{data}{shipment_item}{$shipment_item}{product_id} );
                $handler->{data}{shipment_item}{$shipment_item}{available_stock}  = $stock->{ $handler->{data}{sales_channel} }->{ $handler->{data}{shipment_item}{$shipment_item}{variant_id} };


                if ( $markdown_info_ref->{interval} ) {

                    #get only numeric part of days from sql result
                    if ( $markdown_info_ref->{interval} =~ m/(^-?\d+)/ ) {
                        $handler->{data}{shipment_item}{$shipment_item}{interval} = $1;
                    }
                    else {
                        xt_warn('An error was encountered: the numeric part of the interval could not be parsed');
                    }

                }

            }
        }
        # otherwise get all shipments on the order for user to select from
        else {
            $handler->{data}{shipments} = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );
        }

    }


    # populate left nav links
    if ( $handler->{data}{section} eq 'Finance' && $handler->{data}{action} eq 'Edit' ) {
        $handler->{data}{sidenav} = [{ 'None' => [{ 'title' => 'Back', 'url' => $short_url }]}];
    }
    else {
        $handler->{data}{sidenav} = [{ 'None' => [{ 'title' => 'Back', 'url' => $short_url.'/OrderView?order_id='.$handler->{data}{order_id} }]}];
    }


    return $handler->process_template( undef );
}

sub _d2 {
    my $val = shift;
    my $n = sprintf( "%.2f", $val );
    return $n;
}

1;
