package XTracker::Stock::Actions::CancelStockDelivery;

use strict;
use warnings;

use List::MoreUtils qw( uniq );
use XTracker::Handler;
use XTracker::Database::Delivery        qw( cancel_delivery );
use XTracker::Database::Logging         qw( log_delivery );
use XTracker::Database::PurchaseOrder   qw( check_soi_status check_stock_order_status check_purchase_order_status
                                            set_soi_status set_purchase_order_status );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;
    my ( $successful_complete, $successful_incomplete );
    foreach my $form_key ( keys %{ $handler->{param_of} } ) {

        my $delivery_id
            = $form_key eq 'cancel_delivery_number' || $form_key =~ m{^cancel-}
            ? $handler->{param_of}{$form_key}
            : q{};

        next unless $delivery_id;

        $delivery_id =~ s{^\s*}{}; $delivery_id =~ s{\s*$}{};
        unless ( $delivery_id =~ m{^\d+$} ) {
            xt_warn( "Invalid delivery Id: '$delivery_id'" );
            next;
        }

        my $delivery = $schema->resultset('Public::Delivery')->find( $delivery_id );
        unless ( $delivery ) {
            xt_warn( "Could not find delivery $delivery_id" );
            next;
        }
        unless ( $delivery->stock_order ) {
            xt_warn( "Delivery $delivery_id is not part of a purchase order and cannot be cancelled" );
            next;
        }
        if ( $delivery->is_cancelled ) {
            xt_warn( "Delivery $delivery_id already cancelled" );
            next;
        }
        if ( $delivery->is_voucher_delivery ) {
            xt_warn( "Delivery $delivery_id is a voucher delivery, its cancelling is not currently supported" );
            next;
        }
        # Check if the deliveries has any stock process that have been QCed but
        # not putaway yet. We don't allow cancelling here as this can cause
        # stock inconsistencies with IWS. Technically this only needs to be
        # done for DC1, but taking a shortcut here and disallowing it across
        # the board
        unless ( $delivery->is_complete ) {
            my @outstanding_group_ids = map {
                $_->group_id
            } grep {
                $_->pre_advice_sent_but_not_putaway
            } $delivery->delivery_items
                       ->related_resultset('stock_processes')
                       ->all;
            if ( @outstanding_group_ids ) {
                xt_warn(sprintf(
                    'Cannot cancel delivery %d as there are process groups that are yet to be put away: %s',
                    $delivery_id,
                    join q{, }, sort { $a <=> $b } uniq @outstanding_group_ids
                ));
                next;
            }
        }

        eval {
            $delivery->cancel_delivery( $handler->operator_id );
            push @{$delivery->is_complete ? $successful_complete : $successful_incomplete},
                $delivery_id;
        };
        if (my $e = $@) {
            xt_warn("An error occured whilst trying to cancel delivery $delivery_id: $e");
        }
    }

    for (
        [
            'Deliver%s %s has been cancelled, but please verify stock levels '
          . 'as the cancellation is being done after putaway',
            $successful_complete,
        ],
        [ 'Deliver%s %s cancelled', $successful_incomplete, ],
    ) {
        my ( $msg, $delivery_ids ) = @$_;
        xt_success(sprintf($msg,
            ( @$delivery_ids == 1 ? q{y} : q{ies} ),
            join q{, }, sort { $a <=> $b } @$delivery_ids
        )) if @{$delivery_ids||[]};
    }

    return $handler->redirect_to( '/GoodsIn/DeliveryCancel' );
}

1;
