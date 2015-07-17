package XTracker::Order::Actions::ChangeShipmentItem;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::Database::Shipment qw(:DEFAULT );
use XTracker::Database::Stock qw( :DEFAULT get_saleable_item_quantity );
use XTracker::Database::Product;

use XTracker::Order::Printing::PickingList;

use XTracker::EmailFunctions;
use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :correspondence_templates :shipment_item_status :customer_issue_type :pws_action );
use XTracker::Error;
use XTracker::Config::Local qw( config_var );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r );
    my $schema      = $handler->schema;
    my $dbh         = $schema->storage->dbh;

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    # set up vars and get form data
    my ( $order_id, $shipment_id ) = map {
        $handler->{request}->param($_)
    } qw<order_id shipment_id>;

    my $email = { map {
        $_ => $handler->{param_of}->{ $_ }
    } qw<send_email email_from email_replyto email_to email_subject email_body email_content_type> };

    my $uri = URI->new( "$short_url/SizeChange" );
    # Not sure why insist on an order_id - maybe to guarantee we don't have a
    # sample shipment? If so there's better ways to do it
    if ( !$order_id ) {
        xt_warn( "No order id defined" );
        $uri->query_form({ shipment_id => $shipment_id });
        return $handler->redirect_to( $uri );
    }
    if ( !$shipment_id ) {
        xt_warn( 'No shipment id defined' );
        $uri->query_form({ order_id => $order_id });
        return $handler->redirect_to( $uri );
    }

    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);
    my $order = $shipment->order;

    # We should really check if the order ids don't match here...
    if ( $order->id != $schema->resultset('Public::Orders')->find($order_id)->id ) {
        xt_warn( "The inputted order id ($order_id) doesn't match the shipment's" );
        $uri->query_form({ shipment_id => $shipment_id });
        return $handler->redirect_to( $uri );
    }
    my $channel = $order->channel;
    my $shipment_items = get_shipment_item_info( $dbh, $shipment_id );

    # do the size changes
    my $stock_manager = $channel->stock_manager;
    eval {
        my $guard = $schema->txn_scope_guard;

        # track the Changes made
        my @item_changes_made;

        # loop through selected items
        foreach my $form_key ( keys %{ $handler->{param_of} } ) {
            next unless $form_key =~ m/-/;

            my ($field_name, $item_id) = split( m{-}, $form_key );

            next unless $field_name eq "item";

            # item selected for size change
            next unless $handler->{param_of}{$form_key} == 1;

            my $shipment_item = $schema->resultset('Public::ShipmentItem')->find($item_id);
            # check current status of item
            die 'Item already dispatched or cancelled'
                unless $shipment_item->is_pre_dispatch;

            # get info on what to change to
            my ( $change_to_variant_id, $change_to_size, $change_to_sku ) = split /_/, $handler->{param_of}{'exch-' . $item_id };

            # check stock level for new item
            my $product_id  = get_product_id( $dbh, { type => 'variant_id', id => $change_to_variant_id } );
            my $free_stock  = get_saleable_item_quantity( $dbh, $product_id );

            # no stock available on new item
            if ( $free_stock->{ $channel->name }{ $change_to_variant_id } < 1 ) {
                die 'Not enough stock on $change_to_sku to complete size change';
            }

            # set selected flag if required
            my $has_been_selected = grep {
                $_->is_selected || $_->has_been_picked
            } $shipment_item;

            # flag for a stock discrep if required...
            my $reason_id = $handler->{param_of}{'discrep-' . $item_id }
                          ? $CUSTOMER_ISSUE_TYPE__8__SIZE_CHANGE__DASH__STOCK_DISCREPANCY
                          : $CUSTOMER_ISSUE_TYPE__8__SIZE_CHANGE;
            $shipment_item->cancel({
                operator_id            => $handler->operator_id,
                customer_issue_type_id => $reason_id,
                pws_action_id          => $PWS_ACTION__SIZE_CHANGE,
                notes                  => "Size change on $shipment_id",
                stock_manager          => $stock_manager,
                no_allocate            => 1,
            });

            # create new shipment item
            my $item_status_id;
            if ($handler->prl_rollout_phase) {
                # If we have PRLs, we want everything to go back
                # in the selection queue for pick manager to decide
                # when to send the pick message.
                $item_status_id = $SHIPMENT_ITEM_STATUS__NEW;
            } else {
                # Otherwise, the new status depends on how far
                # we had got before.
                $item_status_id = $has_been_selected
                               ? $SHIPMENT_ITEM_STATUS__SELECTED
                               : $SHIPMENT_ITEM_STATUS__NEW;
            }
            my %new_shipment_item = (
                variant_id          => $change_to_variant_id,
                unit_price          => $shipment_items->{$item_id}{unit_price},
                tax                 => $shipment_items->{$item_id}{tax},
                duty                => $shipment_items->{$item_id}{duty},
                status_id           => $item_status_id,
                special_order       => $shipment_items->{$item_id}{special_order_flag},
                returnable_state_id => $shipment_items->{$item_id}->{returnable_state_id},
                sale_flag_id        => $shipment_items->{$item_id}->{sale_flag_id},
            );

            my $new_ship_item_id = create_shipment_item($dbh, $shipment_id, \%new_shipment_item);

            log_shipment_item_status( $dbh, $new_ship_item_id, $item_status_id, $handler->{data}{operator_id} );

            # store the change for later use
            push @item_changes_made, { orig_item_id => $item_id, new_item_id => $new_ship_item_id };

            # update return_item where exchange_shipment_id = $item_id with $new_ship_item_id
            $schema->resultset('Public::ReturnItem')->update_exchange_item_id(
                $item_id, $new_ship_item_id, 'exchange'
            );

            # adjust stock level
            $stock_manager->stock_update(
                quantity_change => -1,
                variant_id      => $change_to_variant_id,
                pws_action_id   => $PWS_ACTION__SIZE_CHANGE,
                operator_id => $handler->{data}{operator_id},
                notes       => "Size change on $shipment_id",
            );
        }

        # contact the PSP if the Payment Method used requires us to,
        # do it here before we start emailing the Customer or sending
        # out messages on AMQ so that if it fails we will Rollback
        if ( $shipment->should_notify_psp_when_basket_changes ) {
            $shipment->discard_changes->notify_psp_of_item_changes( \@item_changes_made );
        }

        # send customer email
        if ( $email->{send_email} eq 'yes' ) {
            my $email_sent = send_customer_email({
                to           => $email->{email_to},
                from         => $email->{email_from},
                reply_to     => $email->{email_replyto},
                subject      => $email->{email_subject},
                content      => $email->{email_body},
                content_type => $email->{email_content_type}
            });

            if ($email_sent == 1){
                log_shipment_email($dbh, $shipment_id, $CORRESPONDENCE_TEMPLATES__CHANGE_SIZE_OF_PRODUCT, $handler->{data}{operator_id});
            }
        }

        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::Orders::Update',
            { order_id       => $order->id, }
        );

        if ($shipment->does_iws_know_about_me && !$handler->prl_rollout_phase) {
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::WMS::ShipmentRequest',
                $shipment,
            );
        }

        $stock_manager->commit();
        $guard->commit();
        $shipment->allocate({
            factory => $handler->msg_factory,
            operator_id => $handler->{data}{operator_id}
        });

        xt_success( 'Size change completed successfully.' );
    };

    if ( my $err = $@ ) {
        xt_warn( $err );
        $stock_manager->rollback();
        # Calling rollback clears $@
        if ( $@ ) {
            xt_warn( join q{ },
                q{...and we couldn't roll back our changes to the website,},
                qq{so we may have a stock and order inconsistency, you'll need to check: $@}
            );
        }
    }

    $uri->query_form({
        order_id => $order_id,
        shipment_id => $shipment_id,
    });
    return $handler->redirect_to( $uri );
}

1;
