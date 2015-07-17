package XTracker::Order::Functions::Return::Create;
# vim: set et ts=4 sw=4:

use strict;
use warnings;
use Data::Dump qw/pp/;

use XTracker::Config::Local qw / can_deny_store_credit_for_channel /;
use XTracker::Handler;
use XTracker::Image qw( get_images );
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::Database::Shipment qw( :DEFAULT );
use XTracker::Database::Return qw(generate_RMA);
use XTracker::Database::Invoice;
use XTracker::Database::Product;
use XTracker::Database::Stock;
use XTracker::Database::Channel qw(get_channel_details);
use XTracker::EmailFunctions;
use XTracker::Error qw/xt_warn/;
use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw(
  :shipment_item_status
  :correspondence_templates
  :shipment_type
  :renumeration_type
  :renumeration_status
  :renumeration_class
  :customer_issue_type
  :department
);

our $RENUMERATION_TYPE__FULL_CASH_REFUND = 99;

use XTracker::Config::Local qw( returns_email localreturns_email config_var );

# FIXME|XXX
# FIXME|XXX this entire handler needs to be factored out into DBIC level, XT::Domain::Return at least
# FIXME|XXX it seems most of this is around calculating stuff - need to bring it into one place for returns
# FIXME|XXX using a stash of random fields depend on keys from various places is not a good API
# FIXME|XXX
sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    my $data = $handler->{data};
    my $dbh = $handler->{dbh};

    $data->{SHIPMENT_ITEM_STATUS__DISPATCHED} = $SHIPMENT_ITEM_STATUS__DISPATCHED;

    $data->{section}       = $section;
    $data->{subsection}    = $subsection;
    $data->{subsubsection} = 'Create Return';
    $data->{short_url}     = $short_url;

    # get order_id and shipment_id from URL
    $data->{order_id}      = $handler->{param_of}{order_id};
    $data->{shipment_id}   = $handler->{param_of}{shipment_id};
    # list of reasons for user to select from
    $data->{reasons}       = $handler->schema->resultset('Public::CustomerIssueType')->return_reasons_for_rma_pages;

    # back link in left nav
    push( @{ $data->{sidenav}[0]{'None'} },
        { title => 'Back to Returns',
          url   => "$short_url/Returns/View?order_id=$data->{order_id}&shipment_id=$data->{shipment_id}" }
    );

    # get shipment info required
    $data->{order}             = get_order_info( $dbh, $data->{order_id} );
    $data->{channel}           = get_channel_details( $dbh, $data->{order}{sales_channel} );
    $data->{shipment_info}     = get_shipment_info( $dbh, $data->{shipment_id} );
    $data->{shipment_address}  = get_address_info( $dbh, $data->{shipment_info}{shipment_address_id} );
    $data->{shipment_items}    = get_shipment_item_info( $dbh, $data->{shipment_id} );

    # set sales channel
    $data->{sales_channel} = $data->{order}{sales_channel};

    $data->{deny_store_credit} = can_deny_store_credit_for_channel( $handler->schema, $data->{channel}->{id} );

    # get exchange sizes & images for each shipment item
    foreach my $shipment_item_id ( keys %{ $data->{shipment_items} } ) {

        # Gift Vouchers Can't be Returned
        if ( $data->{shipment_items}{$shipment_item_id}{voucher} ) {
            delete $data->{shipment_items}{$shipment_item_id};
            next;
        }

        if ( $data->{shipment_items}{$shipment_item_id}{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__DISPATCHED ) {
            $data->{shipment_items}{$shipment_item_id}{sizes}  = {
                %{ get_exchange_variants( $dbh, $shipment_item_id ) },
                %{ get_cust_reservation_variants( $dbh, $shipment_item_id ) }
            };
        }

        $data->{shipment_items}{$shipment_item_id}{images} = get_images( {
          product_id => $data->{shipment_items}{$shipment_item_id}{product_id},
          live => 1,
          size => 'l',
          schema => $handler->schema,
        } );
    }

    # user has selected items for return
    # validate form data
    # work out refund/debit
    # and preview email template
    my $form_submitted = $handler->{param_of}{select_items};

    if ( $form_submitted ) {
        $data->{content}       = 'ordertracker/returns/create_page2.tt';

        # get a DBIC 'orders' record
        my $order_rec = $handler->{schema}->resultset('Public::Orders')->find( $data->{order_id} );

        push(@{ $data->{sidenav}[0]{'None'} }, { 'title' => 'Back to Item Selection', 'url' => "$short_url/Returns/Create?order_id=$data->{order_id}&shipment_id=$data->{shipment_id}" } );

        # set up some counters to keep track of things
        $data->{num_return_items}      = 0;
        $data->{num_exchange_items}    = 0;
        $data->{charge_tax}            = 0;
        $data->{charge_duty}           = 0;

        # get general form data
        $data->{pickup}        = $handler->{param_of}{pickup};
        $data->{notes}         = $handler->{param_of}{notes};
        $data->{email_type}    = $handler->{param_of}{email_type};
        $data->{refund_id}     = $handler->{param_of}{refund_id};


        # loop over form post and get data
        # return items into a format we can use
        my $param_of = $handler->{param_of};

        my $no_items_selected = 1;
        foreach my $form_key ( %{ $param_of } ) {
            if ( $form_key =~ m/selected-/ ) {
                my ($field_name, $shipment_item_id) = split( /-/, $form_key );

                if (!$param_of->{'exchange-'.$shipment_item_id} &&
                    $param_of->{'type-'.$shipment_item_id} eq 'Exchange')
                {
                    xt_warn("You must select an exchange size for all exchange items");
                    $data->{return_items} = {};
                    $no_items_selected = 0;
                    last;
                }

                $data->{return_items}{$shipment_item_id} = {
                    return           => 1,
                    type             => $param_of->{'type-'.$shipment_item_id},
                    exchange_variant => $param_of->{'exchange-'.$shipment_item_id},
                    reason_id        => $param_of->{'reason_id-'.$shipment_item_id},
                    full_refund       => $param_of->{'full_refund-'.$shipment_item_id},
                };
            }
        }


        if ( keys %{ $data->{return_items} } ) {
            my $txn = $handler->{schema}->txn_scope_guard;


            # generate the RMA number up front
            # as we need it in the email template
            $data->{rma_number} = generate_RMA( $dbh, $data->{shipment_id} );

            $data->{refund_type_id} = $data->{refund_id};

            my $refund_type = $handler->{schema}->resultset('Public::RenumerationType')->find({
                id => ( $data->{refund_id} == $RENUMERATION_TYPE__FULL_CASH_REFUND
                        ? $RENUMERATION_TYPE__CARD_REFUND
                        : $data->{refund_id} ),
            });

            # set the name properly
            if ( $refund_type ) {
                $data->{refund_name} = $refund_type->type;
                # if the Order was paid for using a Credit Card then
                # check to see if it was actually paid using a Third
                # Party Payment such as PayPal.
                if ( $refund_type->id == $RENUMERATION_TYPE__CARD_REFUND
                  && $order_rec->is_paid_using_third_party_psp ) {
                    $data->{refund_name} = $order_rec->get_third_party_payment_method->payment_method . ' Account';
                }
            }
            if ( !$data->{refund_name} && defined $data->{refund_id} && $data->{refund_id} == 0 ) {
                $data->{refund_name}    = 'No Refund';
            }
            if ( !$data->{refund_name} ) {
                # use the split if we have to show how the return will be split-up
                my $split   = $handler->domain('Returns')->get_renumeration_split( {
                                                                    return_items => $data->{return_items},
                                                                    shipment_id => $data->{shipment_id},
                                                                } );
                my $tmp = "";
                foreach my $renum ( @{ $split } ) {
                    my $currency    = $handler->{schema}->resultset('Public::Shipment')
                                                          ->find( $data->{shipment_id} )
                                                          ->order
                                                          ->currency
                                                          ->currency;

                    # if the Refund type is for a Card Refund then check the Order to see
                    # if it was actually paid using a Third Party Payment such as PayPal.
                    my $renum_type;
                    if ( $renum->{renumeration_type_id}->id == $RENUMERATION_TYPE__CARD_REFUND
                      && $order_rec->is_paid_using_third_party_psp ) {
                        $renum_type = $order_rec->get_third_party_payment_method->payment_method . ' Account';
                    }
                    else {
                        $renum_type  = $handler->{schema}->resultset('Public::RenumerationType')
                                                          ->find( $renum->{renumeration_type_id} )
                                                          ->type;
                    }

                    my $sum = 0;
                    foreach my $tender ( @{ $renum->{renumeration_tenders} } ) {
                        $sum    += $tender->{value};
                    }
                    $tmp    .= sprintf("%0.2f %s %s<br/>", $sum, $currency, $renum_type);
                }
                $tmp    =~ s/<br\/>$//;
                $data->{refund_name}    = $tmp;
            }

            eval {
                # create a return object, pass it to render email then throw it away by rolling back the transaction
                $data->{called_in_preview_create_mode}  = 1;        # CANDO-180: set the flag that means we don't really mean it
                my $return = $handler->domain('Returns')->create(  {%$data} );

                my $h = $handler->domain('Returns')->render_email( {
                    return => $return,
                    return_items => $data->{return_items},
                    email_type => $data->{email_type},
                }, $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE);

                $data->{email_msg} = delete $h->{email_body};
                $data->{$_} = $h->{$_} for keys %$h;
            };

            if (my $err = $@) {
               xt_warn("Unable to create return : $err");
               $form_submitted = 0;
            }

            # This is a hack to rollback without throwing an exception
            $txn->{storage}->txn_rollback;
            $txn->{inactivated} = 1;
        }
        else {
            $data->{no_items_selected} = $no_items_selected;
            $form_submitted = 0;
        }
    }

    if (!$form_submitted) {
        # Not an else if to redisplay the submit when something wasn't filled in properly


        $data->{content} = 'ordertracker/returns/create.tt';
        $data->{order}   = $handler->{schema}->resultset('Public::Orders')->find($data->{order_id});
        # check if a Full Cash Refund can be given
        $data->{can_full_cash_refund} = (
            $handler->department_id == $DEPARTMENT__CUSTOMER_CARE_MANAGER
                &&
            $data->{order}->payment_method_allows_full_refund_using_only_the_payment
        );
        die "can't find order with id $data->{order_id}" unless $data->{order};
    }

    return $handler->process_template( undef );
}

1;
