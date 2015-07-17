package Test::NAP::Carrier::DHL::Role::Address;

use NAP::policy qw/test class/;

BEGIN { extends 'NAP::Test::Class'; };

use Test::MockObject;
use Test::MockObject::Extends;
use Test::XTracker::Data;

use NAP::Carrier::DHL::Role::Address;

=head1 NAME

Test::NAP::Carrier::DHL::Role

=head1 METHODS

=head2 test_role_validate_address

=cut

sub test_role_validate_address : Tests {
    my $self = shift;

    # Mock a few shipment/carrier methods we're not interested in testing for
    # now
    my $mocked_shipment = Test::MockObject::Extends->new(
        Test::XTracker::Data->create_shipment
    );
    $mocked_shipment->mock(is_carrier_automated => sub { 0 });

    my $mocked_carrier = $self->mocked_carrier(
        $mocked_shipment, [ is_virtual_shipment => sub { 0 } ],
    );
    for (
        [ 'address validates successfully', 'LHR', 1 ],
        [ 'address fails validation', q{}, 0 ],
    ) {
        my ( $test_name, $destination_code, $should_be_valid ) = @$_;

        subtest $test_name => sub {
            my $got;
            # Fugly mocking of an imported sub
            {
                no warnings 'redefine';
                local *NAP::Carrier::DHL::Role::Address::get_dhl_destination_code = sub { $destination_code };
                $got = NAP::Carrier::DHL::Role::Address::role_validate_address($mocked_carrier);
            }
            if ( $should_be_valid ) {
                ok( $got, 'role_validate_address should return true' );
            }
            else {
                ok( !$got, 'role_validate_address should return false' );
            }

            is( $mocked_shipment->destination_code, $destination_code,
                q{destination code should be set to get_dhl_destination_code's return value} );
        };
    }
}

=head2 mocked_carrier($shipment, @mocks?) : $mocked_carrier

Return a mocked carrier for the given C<$shipment> with the given C<@mocks>
applied to it. Note that mocks is an arrayref.

=cut

sub mocked_carrier {
    my ( $self, $shipment, @mocks ) = @_;

    my $mock = Test::MockObject->new;
    $mock->mock(@$_) for (
        [ schema      => sub { $self->schema } ],
        [ shipment_id => sub { $shipment->id } ],
        [ shipment    => sub { $shipment } ],
        @mocks,
    );
    return $mock;
}
