package Test::XT::Override::TraitFor::NAP::Carrier::UPS;
use NAP::policy "tt", 'role';

use FindBin::libs;
use Test::RoleHelper;
use Test::XT::Net::UPS;
use XTracker::Config::Local qw/config_var/;

=head1 NAME

Test::XT::Override::TraitFor::NAP::Carrier::UPS - A role with overrides to be
applied to NAP::Carrier::UPS.

=head1 DESCRIPTION

This module is a Moose role with overrides for NAP::Carrier::UPS. You can use
L<Test::XT::Override> to apply these, or just apply them manually yourself.

=head1 METHOD MODIFIERS

=head2 around _build_net_ups() : $test_xt_net_ups_obj

This method overrides the call to NAP::Carrier::UPS::_build_net_ups. The only
accepted addresses will be those produced by
L<Test::Role::Address::ca_good_address_data>.

=cut

around '_build_net_ups' => sub {
    my $orig = shift;
    my $self = shift;

    # Only do this if we have configured our system to do so
    return $self->$orig(@_) unless config_var('UPS', 'use_fake_api_calls');

    # Retrieve the expected values
    my $helper = Test::RoleHelper->new_with_roles( 'Test::Role::Address' );
    my $expected = $helper->ca_good_address_data;

    # Build a hash that tells us which values we need to compare
    my %compare_fields = (
        address => [
            ( map { "address_line_$_" } (1..3) ),
            qw/towncity county postcode country/
        ],
        shipment => [qw/email telephone/],
    );

    my $simulate_response = 'Success';
    my $shipment = $self->shipment;
    my $address = $shipment->shipment_address;

    # Compare the values, mark the response as a failure if they differ
    TABLE: while ( my ( $key, $cols ) = each %compare_fields ) {
        my $table = $key eq 'address' ? $address : $shipment;
        for my $col ( @$cols ) {
            next if $expected->{$key}{$col} eq $table->$col;
            $simulate_response = 'Failure';
            last TABLE;
        }
    }
    return Test::XT::Net::UPS->new({
        simulate_response => $simulate_response,
        config => $self->config,
        shipment => $self->shipment,
    });
};
