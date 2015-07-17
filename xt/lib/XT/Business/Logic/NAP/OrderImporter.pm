package XT::Business::Logic::NAP::OrderImporter;

use NAP::policy "tt", 'class';

use XTracker::Constants::FromDB qw/ :currency /;
use XT::Net::Seaview::Client;
use XTracker::Logfile qw/xt_logger/;

extends 'XT::Business::Base';

=head1 NAME

XT::Business::Logic::NAP::OrderImporter - business specific logic for order
importer

=head1 ATTRIBUTES

=cut

has logger => (
    is => 'ro',
    required => 1,
    default => sub { xt_logger },
);

=head1 METHODS

=head2 apply_welcome_pack

We have a Welcome Pack. Its multi-language

=cut

sub apply_welcome_pack {
    my ( $self, $order ) = @_;

    my $send_welcome_pack = 0;

    # Seaview client per-method-invocation as we use the DBIC schema from the
    # order as-per the rest of the Business::Logic methods
    my $seaview = XT::Net::Seaview::Client->new(
                    {schema => $order->result_source->schema});

    my $account_urn = $seaview->registered_account($order->customer->id);

    if ( defined $account_urn ) {
        # If the Seaview flag indicates we've not sent a welcome pack then
        # send one with this order
        try{
            unless($seaview->account($account_urn)->welcome_pack_sent){
                $send_welcome_pack = 1;
            }
        }
        catch {
            # Fall back to the local check
            $self->logger->info( "Falling Back to Local Welcome Pack Qualification because couldn't get Seaview Flag: " . ( $_ // 'undef' ) );
            if ( $self->local_welcome_pack_qualification( $order ) ) {
                $send_welcome_pack = 1
            }
        };
    }
    elsif ( $self->local_welcome_pack_qualification( $order ) ) {
        # We either have no Seaview available or the customer is not
        # registered centrally. Send a welcome pack if this is the customer's
        # first order in this DC
        $send_welcome_pack = 1
    }
    else {
        # Don't send a welcome pack
    }

    # Only send a welcome pack if we've not sent one before - according to our
    # best source of information
    if ( $send_welcome_pack ) {

        # Apply a welcome pack promotion to the order
        my $pack_applied = $self->apply_multi_language_welcome_pack( $order );

        if ( $pack_applied && defined $account_urn ) {
            # Update the flag on the remote resource
            my $attempts = 0;
            $seaview->update_welcome_pack_flag(
                $account_urn,
                1, # set flag to true
                $attempts
            );
        }
    }

    return 1;
}

1;
