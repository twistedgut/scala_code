package XT::DC::Messaging::Producer::PRL::Pick;
use NAP::policy "tt", 'class';
use Carp qw/confess/;

use XT::DC::Messaging::Spec::PRL;

with 'XT::DC::Messaging::Role::Producer',
     'XT::DC::Messaging::Producer::PRL::ReadyToSendRole',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema'; # be a message

use XTracker::Config::Local;

use XTracker::Constants::FromDB qw(
    :shipment_class
);

=head1 NAME

XT::DC::Messaging::Producer::PRL::Pick

=head1 DESCRIPTION

Sends the pick message from XT to a PRL

=head1 SYNOPSIS

    # destination queues will come from config
    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::Pick' => {
            allocation_id => $allocation_id,
        }
    );

=head1 METHODS

=cut

has '+type' => ( default => 'pick' );

sub message_spec {
    return XT::DC::Messaging::Spec::PRL->pick();
}

=head2 transform

Accepts the AMQ header (which will be provided by the message producer),
and a hashref of arguments containing an 'allocation'

=cut

sub transform {
    my ( $self, $header, $args ) = @_;

    confess 'Expected a hashref of arguments' unless 'HASH' eq ref $args;

    my $allocation_id = $args->{allocation_id}
        // confess 'Expected a value for $args->{allocation_id}';

    my $allocation = $self->schema->resultset('Public::Allocation')->find($allocation_id)
        || confess "Could not find allocation for id $allocation_id";

    my $shipment = $allocation->shipment;

    # TODO DC2A: We'll have new rules for the SLA at some point, but for
    # now we just need to send something.
    my $sla_cutoff = $shipment->sla_cutoff //
        DateTime->now(
            time_zone => config_var('DistributionCentre', 'timezone'),
        )->add(
            hours => config_var('PickingSLA', 'default_cutoff'),
        );

    # WHM-1847: When talking to the PRL and the shipment has had its
    # priority 'bumped', subtract a week from the SLA to make sure it
    # appears higher
    $sla_cutoff->subtract(weeks => 1)
        if $shipment->is_prioritised() and $self->prl_rollout_phase();

    # Details for printing pick sheets (WHM-1524)
    my %order_options;
    if( my $order_row = $shipment->order ) {
        %order_options = (sales_channel => $order_row->channel->business->name);
    }
    else {
        my $stock_transfer = $shipment->link_stock_transfer__shipment->stock_transfer;
        %order_options = (
            sales_channel         => $stock_transfer->channel->business->name,
            stock_transfer_reason => $stock_transfer->type->type,
        );
    }
    my $x_prl_specific = {
        shipment_id   => $shipment->id,
        shipment_type => $shipment->shipment_type->type,
        list_class    => $shipment->list_class,
        is_exchange   => !!($shipment->shipment_class->id == $SHIPMENT_CLASS__EXCHANGE),
        is_gift       => !!($shipment->gift),
        %order_options,
    };

    # Message body
    my $payload = {
        allocation_id      => $allocation->id,
        mix_group          => $allocation->picking_mix_group,
        date_time_required => $sla_cutoff->strftime('%FT%T%z'),
        'x-prl-specific'   => $x_prl_specific,
    };

    # Where are we sending it?
    my $destinations = [$allocation->prl->amq_queue];

    # Pack in AMQ cruft
    return $self->amq_cruft({
        header       => $header,
        payload      => $payload,
        destinations => $destinations,
    });
}
