package XTracker::Order::Actions::SelectShipments;

use strict;
use warnings;

use XTracker::Handler;
use Data::Dump qw(pp);
use XTracker::Error;
use XTracker::Logfile qw/ xt_logger /;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    # form post data
    my $channel_key     = $handler->{param_of}->{'channel_key'};
    my $selection_type  = $handler->{param_of}->{'selection_type'};
    my $selection       = $handler->{param_of}->{'selection'};

    my $redirect_url    = "/Fulfilment/Selection?selection_type=$selection_type";

    $redirect_url .= "&selection=$selection" if ($selection);

    # No form submitted - and we were expecting one
    unless ( keys %{$handler->{param_of}} ) {
        xt_warn('No shipments to select');
        return $handler->redirect_to( $redirect_url );
    }

    my (@errors, $count_per_channel);
    my $schema = $handler->schema;
    my $shipments_prioritised;
    # loop over form data and process each shipment
    foreach my $item ( keys %{$handler->{param_of}} ) {
        my ( $prefix, $shipment_id ) = split( m{-}, $item );
        next unless $prefix eq $selection_type; # We only want to process checkboxes in this loop

        # Process tickbox to pick shipment now
        if ( $prefix eq 'pick' && $handler->{param_of}{$item} ) {
            eval {
                $schema->txn_do(sub{
                    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id)
                        or return;
                    $shipment->select($handler->operator_id) or return;
                    if ($shipment->is_premier){
                        $count_per_channel->{Premier} //= 0;
                        $count_per_channel->{Premier}++;
                    }
                    else {
                        my $channel = $shipment->link_orders__shipment->order->channel
                            || $shipment->link_stock_transfer__shipment->stock_transfer->channel;
                        $count_per_channel->{$channel->business->config_section.' standard'} //= 0;
                        $count_per_channel->{$channel->business->config_section.' standard'}++;
                    }
                });
            };
        }

        # Process tickbox to prioritise shipment
        elsif ( $prefix eq 'prioritise' && $handler->{param_of}{$item} ) {
            eval {
                # Set flag on shipment in database to prioritise it
                $shipments_prioritised = 1;
                $schema->resultset('Public::Shipment')->
                    search_rs({ id => $shipment_id })->
                    update({is_prioritised => 1});
                xt_logger->info(sprintf(
                    "Shipment %d prioritised by operator id %d",
                    $shipment_id,
                    $handler->operator_id
                ));
            }
        }

        if ($@) {
          push @errors, "An error occured trying to select shipment $shipment_id: $@";
        }
    }

    # WHM-1297: Premier should be listed first, followed by standard in this channel order
    my %message_sort_order;
    {
        my @message_keys = ('Premier', map { "$_ standard" } qw( NAP MRP OUTNET JC ));
        %message_sort_order = map { ( $message_keys[$_] => $_ ) } 0..$#message_keys;
    }

    xt_warn( $_ ) for @errors;
    if ( keys %{$count_per_channel} ) {
        my @messages;
        my $total = 0;
        foreach my $count_type (sort { $message_sort_order{$a} <=> $message_sort_order{$b} } keys %{$count_per_channel}){
            push @messages , $count_per_channel->{$count_type}." ".$count_type."\n";
            $total += $count_per_channel->{$count_type};
        }
        xt_success(
            sprintf '%d shipment%s successfully selected:',
            $total,
            ($total == 1 ? q{} : q{s})
        );
        xt_success($_) for @messages;
    }
    elsif (!$shipments_prioritised) {
        xt_info("No shipments selected");
    }

    return $handler->redirect_to( $redirect_url );
}


1;
