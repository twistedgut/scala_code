package XTracker::Order::Fulfilment::EmptyTote;
use NAP::policy "tt";

use NAP::DC::Barcode::Container;
use XTracker::Handler;
use XTracker::Error;
use XTracker::Database::Container qw( :validation );
use XTracker::Constants::FromDB qw( :container_status );
use List::MoreUtils qw( uniq );
use XTracker::Database::Logging         qw( log_stock );
use XTracker::Constants::FromDB         qw( :stock_action :shipment_item_status );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {
    my $handler = XTracker::Handler->new( shift );

    return try { return _handler( $handler ) }
    catch {
        xt_warn($_);
        return $handler->process_template();
    };
}

sub _handler {
    my $handler = shift;

    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Packing';
    $handler->{data}{subsubsection} = 'Empty Tote';
    $handler->{data}{content}       = 'ordertracker/fulfilment/emptytote.tt';

    # get container result set
    my $ids = $handler->{param_of}{'container_id'};
    $ids = ref($ids) ? $ids : [$ids];

    # remove undefs and duplicates from list, just in case.
    $ids = [ uniq(
        map  { NAP::DC::Barcode::Container->new_from_id( $_ ) }
        grep { defined && m/\w/ }
        @$ids
    ) ];
    my $container_rs
        = $handler->{schema}->resultset('Public::Container')->search({
            'me.id' => {-in => $ids},
        });

    # check that we should be here and redirect if we shouldn't.
    if ($container_rs->contains_packable){
        # TODO: This is broken: CheckShipment expectes a single
        # shipment_id (which, "cleverly", can be either a Shipment or
        # Container ID). But whatevs...
        return $handler->redirect_to( "/Fulfilment/Packing/CheckShipment?".
                                      join '&', map {"shipment_id=$_"} @$ids );
    }

    my @tote_ids;
    my @pigeonhole_ids;
    foreach my $container ($container_rs->all) {
        if ($container->is_pigeonhole()) {
            # if it has cancelled items
            my $cancelled_ph_count = $container->shipment_items->search({
                'shipment_item_status_id' => [
                    $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
                    $SHIPMENT_ITEM_STATUS__CANCELLED
                ],
            })->count();
            push @pigeonhole_ids, $container->id if ($cancelled_ph_count);
        } else {
            # it's probably a tote, so pass it through and ask the user
            push @tote_ids, $container->id;
        }
    }

    # provide list of container_ids to template
    $handler->{data}->{container_ids} = \@tote_ids;

    # list of pigeon hole ids that need to be dealt with
    $handler->{data}->{pigeonhole_id_list} = join(', ',@pigeonhole_ids);

    # OK. have they submitted the form?
    if ($handler->{param_of}{'is_empty'}){

        # Empty the container regardless of the contents WE know it has for now.
        # Also send item_moved messages and mark as cancelled as they're not getting put away
        # And this applies only to cancelled shipment_items as we can't have an missing orphan items... :D
        my $cp_si = $container_rs->search_related('shipment_items')->cancel_pending;
        while (my $item = $cp_si->next){
            # PH items stay in the same place and go to PE
            if ($item->container_id->is_type("pigeon_hole")) {
                $item->container->update({
                    'status_id' => $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS,
                });
                next;
            }

            $item->set_cancelled($handler->operator_id);
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::WMS::ItemMoved',{
                shipment_id => $item->shipment_id,
                from  => { container_id => $item->container_id },
                to    => { place      => 'lost',
                           stock_status => 'main' },
                items => [{
                    sku     => $item->get_sku,
                    quantity=> 1,
                    client  => $item->get_client()->get_client_code(),
                }],
            });
            $item->unpick;

            log_stock(
                $handler->dbh,
                {
                    variant_id  => $item->get_true_variant->id,
                    action      => $STOCK_ACTION__MANUAL_ADJUSTMENT,
                    quantity    => -1, # Things aren't decremented from log stock quantity until packed,
                                       # so this action is affecting quantity in this log
                    operator_id => $handler->operator_id,
                    notes       => 'missing cancelled item at Packing for shipment '.$item->shipment_id,
                    channel_id  => $item->shipment->get_channel->id,
                }
            );
        }

        # make sure that containers are no longe presented on PackLane
        $_->remove_from_packlane foreach $container_rs->all;

        # fine. redirect to packing page
        my $message = "Packing of container" . (@$ids > 1 ? 's ' : ' ') . join(', ', @$ids) . " complete. ";
        $message .= "Please set aside and scan a new container.";
        xt_success("Packing of container" . (@$ids > 1 ? 's ' : ' ') . join(', ', @$ids) . " complete. Please set aside and scan a new container");
        return $handler->redirect_to( "/Fulfilment/Packing");
    } elsif ($handler->{param_of}{'not_empty'}) {
        # over to Pack Into Packing Exception Orphan (PIPEO) page
        return $handler->redirect_to( "/Fulfilment/Packing/PlaceInPEOrphan?".
                                      join '&', map {"source_containers=$_"} @$ids);
    }

    return $handler->process_template;
}

1;
