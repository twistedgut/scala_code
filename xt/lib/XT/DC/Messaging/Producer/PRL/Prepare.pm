package XT::DC::Messaging::Producer::PRL::Prepare;

use NAP::policy 'tt', 'class';
use Carp qw/confess/;

use XT::DC::Messaging::Spec::PRL;

with 'XT::DC::Messaging::Role::Producer',
     'XT::DC::Messaging::Producer::PRL::ReadyToSendRole',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

use XTracker::Config::Local;
use XTracker::Config::Parameters 'sys_param';

=head1 NAME

XT::DC::Messaging::Producer::PRL::Prepare

=head1 DESCRIPTION

Sends C<Prepare> message to PRL.

=head1 SYNOPSIS

    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::Prepare' => {
            allocation_id => $allocation_id,
        }
    );

=head1 METHODS

=cut

has '+type' => ( default => 'prepare' );

sub message_spec {
    return XT::DC::Messaging::Spec::PRL->prepare;
}

=head2 transform

Accepts the AMQ header (which will be provided by the message producer),
and following HASH ref:

    allocation_id : ID of the allocation to ask PRL to prepare;
    destination   : destination where to prepare.

Notes:

All possible exceptions occurring while validating passed data structure are propagated further.

=cut

sub transform {
    my ($self, $header, $args) = @_;

    confess 'Expected a hashref of arguments' unless 'HASH' eq ref $args;

    my $destination = $args->{destination};

    my $allocation = $args->{allocation}
        or confess 'Expected a value for $args->{allocation}';

    my $destination_row;
    if (defined $destination) {
        # If the $destination is defined, then it needs to be a real
        # destination for this PRL (so we can use its id later on).
        my $destination_rs = $allocation->prl->prl_delivery_destinations;
        $destination_row = $destination_rs->find({
            message_name => $destination,
        });

        if (!$destination_row) {
            confess "$destination is not a valid PRL delivery destination.";
        }
    } else {
      $destination_row = $allocation->get_prl_delivery_destination;

      if (defined $destination_row) {
          $destination = $destination_row->message_name,
          $allocation->update({
              prl_delivery_destination_id => $destination_row->id,
          });
      } else {
          confess "Can't find a value for delivery destination";
      }
    }

    # Message body
    my $payload = {
        allocation_id => $allocation->id,
        destination   => $destination,
    };

    # Include 'deliver_within_seconds' if
    # * single item shipment
    # * destination allows single item grouping (i.e. direct lane)
    if ($allocation->is_single_item_shipment &&
        $destination_row->allows_single_item_grouping) {
        $payload->{deliver_within_seconds} =
          $args->{deliver_within_seconds} //
          sys_param('goh/deliver_within_seconds');
    }

    my $destinations = [$allocation->prl->amq_queue];

    return $self->amq_cruft({
        header       => $header,
        payload      => $payload,
        destinations => $destinations,
    });
}

__PACKAGE__->meta->make_immutable;

