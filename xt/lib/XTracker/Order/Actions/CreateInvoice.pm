package XTracker::Order::Actions::CreateInvoice;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Constants::FromDB (qw(
    :renumeration_class
    :renumeration_status
    :renumeration_type
) );
use XTracker::Database;
use XTracker::Database::Invoice;
use XTracker::Database::Shipment;
use XTracker::Utilities qw( parse_url );
use XTracker::Error;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    # set up vars and get query string data
    my $invalid_msg     = '';
    my $renum_id        = 0;
    my $total_renum     = 0;
    my $order_id        = $handler->{param_of}{order_id};
    my $shipment_id     = $handler->{param_of}{shipment_id};
    my $type_id         = $handler->{param_of}{type_id};
    my $shipping        = $handler->{param_of}{shipping};
    my $misc_refund     = $handler->{param_of}{misc_refund};
    my $gift_credit     = $handler->{param_of}{gift_credit};
    my $store_credit    = $handler->{param_of}{store_credit};
    my $currency_id     = $handler->{param_of}{currency_id};
    my $reason_id       = $handler->{param_of}{invoice_reason_id};
    my $redirect_url    = $short_url.'/Invoice?order_id='.$order_id.'&shipment_id='.$shipment_id;

    my $schema = $handler->schema;
    my $renumeration_rs = $handler->schema->resultset('Public::Renumeration');

    eval {

        if ( $type_id == $RENUMERATION_TYPE__CARD_DEBIT && $shipping > 0 ) {
            $shipping *= -1;
        }
        if ( $type_id == $RENUMERATION_TYPE__CARD_DEBIT && $misc_refund > 0 ) {
            $misc_refund *= -1;
        }

        # get current shipment info
        my $dbh = $schema->storage->dbh;
        my $guard = $schema->txn_scope_guard;
        my $shipment        = get_shipment_info( $dbh, $shipment_id );
        my $shipment_item   = get_shipment_item_info( $dbh, $shipment_id );

        # take off any existing refunds from shipment values before checking
        my $refunds = get_shipment_invoices( $dbh, $shipment_id );

        foreach my $ref_id ( keys %{ $refunds } ) {

            if ( $refunds->{$ref_id}{renumeration_type_id} < $RENUMERATION_TYPE__CARD_DEBIT
              && $refunds->{$ref_id}{renumeration_status_id} < $RENUMERATION_STATUS__CANCELLED
            ) {
                # take off shipping
                if ( defined $refunds->{$ref_id}{shipping} ) {
                    $shipment->{shipping_charge} -= $refunds->{$ref_id}{shipping};
                }

                $refunds->{$ref_id}{renum_item} = get_invoice_item_info( $dbh, $ref_id );

                foreach my $ref_item_id ( keys %{ $refunds->{$ref_id}{renum_item} } ) {
                    my $shipment_item_id = $refunds->{$ref_id}{renum_item}{$ref_item_id}{shipment_item_id};

                    foreach my $type ( qw( unit_price tax duty ) ) {
                        $shipment_item->{$shipment_item_id}{$type} -= $refunds->{$ref_id}{renum_item}{$ref_item_id}{$type};
                    }
                }
            }
        }

        # get items from form post
        foreach my $item_id ( keys %{ $shipment_item } ) {

            foreach my $type ( qw( unit_price tax duty ) ) {
                $shipment_item->{$item_id}{"refund_$type"} = $handler->{param_of}{$type.q{_}.$item_id} || 0;
            }

            $invalid_msg = _check_refund_range( $shipment_item->{$item_id} );

            if ( $invalid_msg ne '' ) {
                die 'The data entered is not valid: '.$invalid_msg;
            }

            $total_renum += $shipment_item->{$item_id}{refund_unit_price}
                          + $shipment_item->{$item_id}{refund_tax}
                          + $shipment_item->{$item_id}{refund_duty};
        }

        $shipment->{refund_shipping} = $shipping;
        $shipment->{refund_misc}     = $misc_refund;

        $invalid_msg = _check_refund_range_type(
            $shipment->{refund_shipping},
            $shipment->{shipping_charge},
            'shipping',
        );

        if ( $invalid_msg ne '' ) {
            die 'The data entered is not valid: '.$invalid_msg;
        }

        $total_renum += $shipment->{refund_shipping} + $shipment->{refund_misc};

        if ( $total_renum > 0 && $type_id == $RENUMERATION_TYPE__CARD_DEBIT ) {
            $invalid_msg = 'The total value of the debit must be a negative figure- '.$total_renum;
        }
        if ( $total_renum < 0 && $type_id < $RENUMERATION_TYPE__CARD_DEBIT ) {
            $invalid_msg = 'The total value of the refund must be a positive figure - '.$total_renum;
        }

        if ( $invalid_msg ne '' ) {
            die 'The data entered is not valid: '.$invalid_msg;
        }



        # passed validation - create the invoice
        my $renumeration = $renumeration_rs->create( {
            shipment_id             => $shipment_id,
            invoice_nr              => '',      # needs to be an Empty String
            renumeration_type_id    => $type_id,
            renumeration_class_id   => $RENUMERATION_CLASS__GRATUITY,
            renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
            shipping                => $shipment->{refund_shipping},
            misc_refund             => $shipment->{refund_misc},
            currency_id             => $currency_id,
            renumeration_reason_id  => $reason_id,
        } );
        # use 'discard_changes' to get Default values into $renumeration
        $renum_id   = $renumeration->discard_changes->id;

        # log creation
        $renumeration->update_status(
            $RENUMERATION_STATUS__AWAITING_ACTION,
            $handler->{data}{operator_id},
        );

        # create invoice items
        foreach my $item_id ( keys %{ $shipment_item } ){

            if (   $shipment_item->{$item_id}{refund_unit_price } != 0
                || $shipment_item->{$item_id}{refund_tax        } != 0
                || $shipment_item->{$item_id}{refund_duty       } != 0 )
            {
                $renumeration->create_related( 'renumeration_items', {
                    shipment_item_id    => $item_id,
                    unit_price          => $shipment_item->{$item_id}{refund_unit_price},
                    tax                 => $shipment_item->{$item_id}{refund_tax},
                    duty                => $shipment_item->{$item_id}{refund_duty},
                } );
            }
        }

        $guard->commit();
        $redirect_url .= "&action=View&invoice_id=$renum_id";
        xt_success('Invoice created successfully.');
    };

    if ( my $err = $@ ) {
        xt_warn( $err );
        $redirect_url .= '&action=Create';
    }

    return $handler->redirect_to( $redirect_url );
}

sub _check_refund_range {
    my ( $shipment_item ) = shift;

    my $invalid;
    foreach my $type ( qw( unit_price tax duty ) ) {
        $invalid = _check_refund_range_type(
            $shipment_item->{"refund_$type"},
            $shipment_item->{$type},
            $type,
            $shipment_item->{sku}
        );

        if ($invalid ne '') {
            return $invalid;
        }
    }

    return '';
}

# Checks if refund is greater than the original price
sub _check_refund_range_type {
    my ( $refund, $total, $type, $sku ) = @_;
    my $invalid = $type eq 'unit_price' ? 'There was an error with the unit price value for item '.$sku
                : $type eq 'tax'        ? 'There was an error with the tax value for item '.$sku
                : $type eq 'duty'       ? 'There was an error with the duty value for item '.$sku
                : $type eq 'shipping'   ? 'There was an error with the shipping value entered'
                :                         ''
    ;

    if ( $type eq 'tax' ) {
        $refund -= 0.15;
    }

    if ( $refund > $total ) {
        return $invalid;
    }

    return '';
}

1;
