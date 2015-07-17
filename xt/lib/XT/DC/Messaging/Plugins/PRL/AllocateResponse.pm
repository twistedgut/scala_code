package XT::DC::Messaging::Plugins::PRL::AllocateResponse;
use NAP::policy "tt", 'class';
use List::Util qw/reduce/;
use Data::Compare;
use Data::Dump qw/pp/;

use XTracker::Config::Local qw/config_var/;
use XTracker::Constants::FromDB qw( :flow_status :allocation_item_status );
use XTracker::Constants qw/:prl_type/;
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

=head1 NAME

XT::DC::Messaging::Consumer::Plugins::PRL::AllocateResponse - Handle allocate_response from PRL

=head1 DESCRIPTION

Handle allocate_response from PRL

=head1 METHODS

=head2 message_type

Returns the name of the message

=cut

sub message_type { 'allocate_response' }

=head2 handler

Receives the class name, context, and pre-validated payload.

=cut

sub handler {
    my ( $self, $c, $message ) = @_;

    # Get all allocation data from the DB
    my $allocation_id = $message->{allocation_id};
    my $allocation = $self->get_allocation( $c, $allocation_id )
        or die("Can't find an allocation with id [$allocation_id]");

    # We need to work out if this is a plausible reply to our last message. We
    # do this by checking if the count of allocated and requested for each SKU
    # matches the 'quantity requested' in the message. If not, we drop it.
    my @allocation_items = $allocation->allocation_items;
    my $expected_sku_count = reduce {
        my ( $hash, $item ) = ( $a, $b );
        if (
            $item->status_id eq $ALLOCATION_ITEM_STATUS__ALLOCATED ||
            $item->status_id eq $ALLOCATION_ITEM_STATUS__REQUESTED
        ) {
            $hash->{ $item->variant_or_voucher_variant->sku }++;
            $hash;
        } else {
            $hash;
        }
    } {}, @allocation_items;

    my $received_sku_count = reduce {
        my ( $hash, $item ) = ( $a, $b );
        $hash->{ $item->{'sku'} } = $item->{'quantity_requested'};
        $hash;
    } {}, @{ $message->{'item_details'} };

    # Log, return, unless we have a plausible reply.
    unless ( Compare( $expected_sku_count, $received_sku_count ) ) {
        $c->log->info( sprintf(
                'Out-of-order AllocateResponse for allocation [%s] received. Expected to find ' .
                'items matching: [%s], but received [%s]',
                $allocation_id,
                pp($expected_sku_count),
                pp($received_sku_count),
            ),
        );
        return;
    }

    # Dispatch to the AllocateManager
    XTracker::AllocateManager->allocate_response({
        allocation => $allocation,
        allocation_items => \@allocation_items,
        sku_data => {
            map {
                $_->{'sku'} => {
                    allocated => $_->{'quantity_allocated'},
                    short => $_->{'quantity_requested'} - $_->{'quantity_allocated'}
                }
            } @{ $message->{'item_details'} }
        },
        operator_id => $APPLICATION_OPERATOR_ID
    });
}

# This is temporary, until we can fix
# e.g. lib/XTracker/Stock/Actions/SetSampleRequest.pm to use
# Net/Stomp/Producer/Transactional.pm
#
# Afer that, remove all of this retry malarkey.
sub get_allocation {
    my ($self, $c, $allocation_id) = @_;
    my $schema = $c->model('Schema');

    my $delay_sec   = 1;
    my $retry_count = 4;

    # TODO: downgrade to debug once we're somewhat happy this works
    $c->log->info("AllocateResponse for allocation_id ($allocation_id)");
    for my $retry (0 .. $retry_count) {

        if( $retry ) {
            $c->log->warn(
                "  allocation_id ($allocation_id) not found (yet), sleeping ($delay_sec) seconds"
            );
            sleep($delay_sec);
        }

        my $allocation_row = $schema->resultset('Public::Allocation')->search(
            { 'me.id'  => $allocation_id },
            { prefetch => { allocation_items => 'shipment_item' } }
        )->first;

        if ( $allocation_row )  {
            $retry and $c->log->info(
                "    Failed at first, but found allocation_id($allocation_id) after retry ($retry)"
            );
            return $allocation_row;
        }

    }

    $c->log->error(
        "allocation_id ($allocation_id) not found after retrying $retry_count times, now failing"
    );
    return undef;
}

1;

