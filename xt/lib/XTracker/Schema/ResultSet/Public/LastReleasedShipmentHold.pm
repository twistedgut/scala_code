package XTracker::Schema::ResultSet::Public::LastReleasedShipmentHold;
use NAP::policy;
use MooseX::Params::Validate;
use XTracker::Config::Local qw/config_var/;

use base 'DBIx::Class::ResultSet';

=head1 NAME

XTracker::Schema::ResultSet::Public::LastReleasedShipmentHold

=head1 DESCRIPTION

This view encapsulates a complex SQL query that efficiently finds the last time a shipment
 was released from 'manual' hold.

=head1 PUBLIC METHODS

=head2 get_released_datetime_for_last_shipment_hold

 param - shipment : The Result::Shipment object of which we wish to find the release date
 param - only_include_sla_changeable_reasons : (Optional, default = 0) If set to 1, only
    hold reasons that are configured to allow a new SLA to be regenerated will be
    considered
 param - only_include_holds_held_long_enough : (Optional, default = 0) If set to 1, only
    hold statuses that were released after the system configured number of minutes for
    a valid hold will be considered

 return - $release_date : A DateTime object representing the last time the shipment was
    released from a valid hold status. Undef if the shipment never has been

=cut
sub get_released_datetime_for_last_shipment_hold {
    my ($self, $shipment, $only_include_sla_changeable_reasons,
        $only_include_holds_held_long_enough) = validated_list(\@_,
        shipment                            => { isa => 'XTracker::Schema::Result::Public::Shipment' },
        only_include_sla_changeable_reasons => { isa => 'Bool', default => 0 },
        only_include_holds_held_long_enough => { isa => 'Bool', default => 0 },
    );

    my $last_hold = $self->search({
        ( $only_include_sla_changeable_reasons
            ? ( allow_new_sla_on_release => $only_include_sla_changeable_reasons )
            : ()
        ),
        ( $only_include_holds_held_long_enough
            ? ( held_long_enough => $only_include_holds_held_long_enough )
            : ()
        ),
    }, {
        bind        => [
            $self->_get_minimum_hold_minutes_to_allow_new_sla(),
            $shipment->id(),
        ],
        order_by    => { -desc => 'me.release_date' },
        rows        => 1,
    })->first();

    return undef unless $last_hold;

    $last_hold->release_date();
}

sub _get_minimum_hold_minutes_to_allow_new_sla {
    my ($self) = @_;
    return config_var('Fulfilment', 'minimum_minutes_passed_before_hold_release_allows_new_sla');
}
