package XT::DC::Messaging::Producer::Sync::FraudHotlist;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer';

use XTracker::Config::Local     qw( config_var );


use XT::DC::Messaging::Spec::OnlineFraud   ();
sub message_spec { return XT::DC::Messaging::Spec::OnlineFraud->update_fraud_hotlist(); }

has '+type' => ( default => 'update_fraud_hotlist' );

=head2 transform

This is the payload for transfering Fraud Hot-List values to other DC's

=cut

sub transform {
    my ( $self, $header, $data ) = @_;

    # make sure $data is in an Array Ref
    $data   = ( ref( $data ) eq 'ARRAY' ? $data : [ $data ] );

    # remove any 'undef' Order Numbers
    # 'empty string' ones are fine
    my @rows    = map {
        delete $_->{order_number}   if ( !defined $_->{order_number} );
        $_;
    } @{ $data };

    my $msg = {
        from_dc => config_var('DistributionCentre','name'),
        records => \@rows,
    };

    return ( $header, $msg );
}
