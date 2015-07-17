package XT::DC::Messaging::Producer::PRL::Allocate;

use Moose;
use XTracker::Constants qw/:prl_type/;
use MooseX::Params::Validate;
use XT::Domain::PRLs;
use XT::DC::Messaging::Spec::PRL;

with 'XT::DC::Messaging::Role::Producer',
     'XT::DC::Messaging::Producer::PRL::ReadyToSendRole',
     'XTracker::Role::WithPRLs';

=head1 NAME

XT::DC::Messaging::Producer::PRL::Allocate

=head1 DESCRIPTION

Sends C<Allocate> message to PRL.

=head1 SYNOPSIS

    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::Advice' => {
            allocation => XTracker::Schema::Result::Public::Allocation
        }
    );

=head1 METHODS

=cut

has '+type' => ( default => 'allocate' );

sub message_spec {
    return XT::DC::Messaging::Spec::PRL->allocate();
}

=head2 transform

Accepts the AMQ header from the message producer, and an
L<XTracker::Schema::Result::Public::Allocation> object.

=cut

sub transform {
    my $self = shift;

    my ( $header, $allocation ) = pos_validated_list(
        \@_,
        { isa => 'HashRef' },
        { isa => 'XTracker::Schema::Result::Public::Allocation'},
    );

    # Basics
    my $message = {
        allocation_id  => $allocation->id,
        has_print_docs => $allocation->shipment->list_picking_print_docs() ?
            $PRL_TYPE__BOOLEAN__TRUE: $PRL_TYPE__BOOLEAN__FALSE,
    };

    my $client;

    # Item details
    my %items;
    for my $item ( $allocation->allocation_items->filter_active ) {
        my $variant = $item->variant_or_voucher_variant;

        # Only one CLIENT lookup needed
        $client //= $variant->prl_client;

        $items{ $variant->id } //= {
            client          => $client,
            sku             => $variant->sku,
            stock_status    => $PRL_TYPE__STOCK_STATUS__MAIN,
            return_priority => "",
            quantity        => 0,
        };
        $items{ $variant->id }->{'quantity'}++;
    }

    $message->{'item_details'} =
        [ sort {$a->{'sku'} cmp $b->{'sku'}} (values %items) ];

    # Pack in AMQ cruft
    my @message_parts = $self->amq_cruft({
        header       => $header,
        payload      => $message,
        destinations => [$allocation->prl->amq_queue],
    });
    return @message_parts;
}

__PACKAGE__->meta->make_immutable;

1;
