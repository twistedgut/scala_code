package XTracker::Schema::ResultSet::Public::ShipmentHoldReason;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants::FromDB     qw( :shipment_hold_reason );


=head1 METHODS

=head2 get_reasons_for_hold_page

    $hash_ref = $self->get_reasons_for_hold_page( $iws_rollout_phase );

Returns a Hash Ref of Reasons keyed by Id. If no IWS Phase is passed then
the setting from the Config Section will be used to determin whether the
'Incomplete Pick' reason is returned.

=cut

sub get_reasons_for_hold_page {
    my ( $self, $iws_rollout_phase ) = @_;

    # TODO: remove the IWS rollout phase check once we
    # update the database to remove 'Incomplete Pick' as
    # a valid hold reason, post phase 1 deployment

    $iws_rollout_phase ||= config_var('IWS', 'rollout_phase');

    my $search_args;
    if ( $iws_rollout_phase >= 1 ) {
        $search_args->{id}  = { '!=' => $SHIPMENT_HOLD_REASON__INCOMPLETE_PICK };
    }

    my %hash = map { $_->id => $_ } $self->search( $search_args )->all;

    return \%hash;
}

1;
