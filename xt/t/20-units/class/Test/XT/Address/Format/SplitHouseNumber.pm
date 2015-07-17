package Test::XT::Address::Format::SplitHouseNumber;
use NAP::policy 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::Address::Format::SplitHouseNumber

=head1 DESCRIPTION

Tests the XT::Address::Format::SplitHouseNumber class.

=cut

use Test::XTracker::Data;

=head1 TESTS

=head2 startup

Check we can load the required classes.

=cut

sub startup : Tests( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    use_ok('XT::Address');
    use_ok('XT::Address::Format::SplitHouseNumber');

    $self->{schema} = Test::XTracker::Data->get_schema();

}

=head2 test_APPLY_FORMAT

Run the following tests against this formatter:

    Address With Just A Street
    Address With Just A Street - Extra Spaces
    Address With Just A Number
    Address With Just A Number - Extra Spaces
    Address With A Street And House Number
    Address With A Street And House Number - Extra Spaces
    Address With A Number At The Beginning
    Empty Address

=cut

sub test_APPLY_FORMAT : Tests {
    my $self = shift;

    my %tests = (
        'Address With Just A Street' => {
            address_line_1  => 'Gällerstraße',
            expected        => {
                street_name     => 'Gällerstraße',
                house_number    => '',
            },
        },
        'Address With Just A Street - Extra Spaces' => {
            address_line_1  => '  Gällerstraße  ',
            expected        => {
                street_name     => 'Gällerstraße',
                house_number    => '',
            },
        },
        'Address With Just A Number' => {
            address_line_1  => '123',
            expected        => {
                street_name     => '123',
                house_number    => '',
            },
        },
        'Address With Just A Number - Extra Spaces' => {
            address_line_1  => '  123  ',
            expected        => {
                street_name     => '123',
                house_number    => '',
            },
        },
        'Address With A Street And House Number' => {
            address_line_1  => 'Gällerstraße 123',
            expected        => {
                street_name     => 'Gällerstraße',
                house_number    => '123',
            },
        },
        'Address With A Street And House Number - Extra Spaces' => {
            address_line_1  => '  Gällerstraße   123  ',
            expected        => {
                street_name     => 'Gällerstraße',
                house_number    => '123',
            },
        },
        'Address With A Number At The Beginning' => {
            address_line_1  => '123 Gällerstraße',
            expected        => {
                street_name     => '123 Gällerstraße',
                house_number    => '',
            },
        },
        'Empty Address' => {
            address_line_1  => '',
            expected        => {
                street_name     => '',
                house_number    => '',
            },
        },
    );

    while ( my ( $name, $test ) = each %tests ) {

        subtest $name => sub {

            $self->{schema}->txn_begin;

            my $order_address = Test::XTracker::Data
                ->create_order_address_in('current_dc', {address_line_1 => $test->{address_line_1}})
                ->discard_changes;

            my $address = new_ok( 'XT::Address' => [ $order_address ] );
            my $object  = new_ok( 'XT::Address::Format::SplitHouseNumber' => [{ address => $address }] );

            # XTracker::Schema::Result::Public::OrderAddress uses a
            # FilterColumn to trim certain fields (including address_line_1),
            # so we cannot test with leading/trailing spaces unless we
            # manually update the field in the XT::Address object after it's
            # been created.
            $address->set_field( address_line_1 => $test->{address_line_1} );

            $object->APPLY_FORMAT;

            # Address line one should not change.
            cmp_ok( $address->get_field('address_line_1'), 'eq', $test->{address_line_1},
                'Address line one has not changed.' );

            # Make sure the new fields now exist.
            ok( $address->field_exists('street_name'), 'Field "street_name" exists');
            ok( $address->field_exists('house_number'), 'Field "house_number" exists');

            # Check the street name.
            cmp_ok( $address->get_field('street_name'), 'eq', $test->{expected}->{street_name},
                "Street name is '$test->{expected}->{street_name}' as expected" );

            # Check the house number.
            cmp_ok( $address->get_field('house_number'), 'eq', $test->{expected}->{house_number},
                "House number is '$test->{expected}->{house_number}' as expected" );

            $self->{schema}->txn_rollback;

        }

    }

}
