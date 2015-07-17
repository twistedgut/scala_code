package XT::DC::Messaging::Plugins::PRL::ItemPicked;
use NAP::policy "tt", 'class';

use XTracker::Constants::FromDB qw(:allocation_item_status);
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;
use List::Util qw/first/;
use XTracker::Logfile 'xt_logger';

=head1 NAME

XT::DC::Messaging::Consumer::Plugins::PRL::ItemPicked - Handle item_picked from PRL

=head1 DESCRIPTION

Handle item_picked from PRL

=head1 METHODS

=head2 message_type

Returns the name of the message

=cut

sub message_type { 'item_picked' }

=head2 handler

Receives the class name, context, and pre-validated payload.

=cut

sub handler {
    my ( $self, $c, $message ) = @_;

    my $schema = $c->model('Schema');

    # Lookup the allocation_id
    my $allocation = $schema->resultset('Public::Allocation')->search(
        { 'me.id' => $message->{'allocation_id' } },
        { prefetch => { allocation_items => 'shipment_item' } }
    )->first or die sprintf(
        "Can't find an allocation for item_picked message with id [%s]",
        $message->{'allocation_id'}
    );

    # Try and find a Picking Allocation Item for it
    my @allocation_items = $allocation->allocation_items;
    # We accept the first one that's in a reasonable state, because we don't
    # have any way distinguishing between Allocation Items based on what the
    # PRL sends us.

    xt_logger->info(sprintf("item_picked recieved (allocation_id=%d)"
        . "alloc item statuses: %s",
            $allocation->id,
            join(", ",
                map { sprintf("[allocation_item_id=%s,status_id=%s]",
                    $_->id,
                    $_->status_id)
                } @allocation_items
            )
    ));

    my $allocation_item = first {
        ($_->status_id eq $ALLOCATION_ITEM_STATUS__PICKING) &&
        ($_->variant_or_voucher_variant->sku eq $message->{'sku'})
    } @allocation_items;
    die sprintf(
        "Can't find an Allocation Item with SKU [%s] in status Picking for " .
        "Allocation [%d]",
        $message->{'sku'},
        $allocation->id
    ) unless $allocation_item;

    # See if we can find a matching operator to log the change against,
    # if not, we'll default to the application operator id.
    my $operator = $schema->resultset('Public::Operator')->find({
        'username' => $message->{'user'},
    });
    my $operator_id = $operator ? $operator->id : $APPLICATION_OPERATOR_ID;

    xt_logger->info(sprintf("Marking allocation item %d as Picked", $allocation_item->id));

    # Update that allocation item
    $schema->txn_do( sub {

        $allocation_item->update({
            picked_by   => $message->{'user'},
            picked_into => $message->{'container_id'},
            picked_at   => \'NOW()',
            status_id   => $ALLOCATION_ITEM_STATUS__PICKED,
        });

        $allocation_item->log_status( $operator_id );

    });

}

1;
