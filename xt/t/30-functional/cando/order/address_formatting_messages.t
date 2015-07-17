use NAP::policy 'test';
use parent 'NAP::Test::Class';

=head1 NAME

t/30-functional/cando/order/address_formatting_messages.t

=head1 DESCRIPTION

Tests the country drop-down on the /*/*/EditAddress page contains the correct
metadata to attach messages to the address line items.

=cut

use Test::XT::Flow;
use Test::XT::Data;
use Test::XTracker::Data;

use XTracker::Constants::FromDB ':authorisation_level';

=head1 TESTS

=head2 startup

Setup the L<Test::XT::Flow> framework, L<Test::XT::Data> and various bits of
data, then log.

=cut

sub startup : Test( startup => no_plan ) {
    my $self = shift;

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [ 'Test::XT::Flow::CustomerCare' ],
    );

    $self->{data} = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order' ],
    );

    # Ignore any countries that don't have a code, otherwise
    # C<address_formatting_messages_for_country> in L<XTracker::Config::Local>
    # will return an empty HashRef, because storing messages against a blank
    # country code makes no sense.
    my $countries_with_a_code = $self->schema->resultset('Public::Country')
        ->search({ code => { '!=' => '' } });

    $self->{order_data} = $self->{data}->new_order;
    $self->{country}    = $countries_with_a_code->first;
    $self->{group_name} = 'AddressFormatingMessagesByCountry';

    $self->{framework}->mech->force_datalite(1);
    $self->{framework}->login_with_permissions({
        dept    => 'Customer Care',
        perms   => {
            $AUTHORISATION_LEVEL__MANAGER => [
                "Customer Care/Customer Search",
                "Customer Care/Order Search",
            ],
       },
    });

}

=head2 setup

Clear the 'AddressFormatingMessagesByCountry' system configuration group and
re-create it with known values.

=cut

sub setup : Test( setup => no_plan ) {
    my $self = shift;

    my $settings = [ {
        sequence    => 0,
        setting     => $self->country->code,
        value       => 'address_line_1:This is Address Line One',
    }, {
        sequence    => 1,
        setting     => $self->country->code,
        value       => 'postcode:This is the Postcode',
    } ];

    # Remove and re-create the Group and Settings (saving it first).
    Test::XTracker::Data->save_config_group_state( $self->group_name );
    Test::XTracker::Data->remove_config_group( $self->group_name );
    Test::XTracker::Data->create_config_group( $self->group_name => { settings => $settings } );

}

=head2 teardown

Restore the system configuration back to it's original state.

=cut

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;

    # Put the config back how it was.
    Test::XTracker::Data->restore_config_group_state( $self->group_name );

}

=head2 test_edit_shipping_address

Test the Drop-Down on the Edit Shipping Address page.

=cut

sub test_edit_shipping_address : Tests {
    my $self = shift;

    $self->framework
        ->flow_mech__customercare__orderview( $self->order->id )
        ->flow_mech__customercare__edit_shipping_address
        ->flow_mech__customercare__choose_address;

    $self->country_list_ok;

}

=head2 test_edit_billing_address

Test the Drop-Down on the Edit Billing Address page.

=cut

sub test_edit_billing_address : Tests {
    my $self = shift;

    $self->framework
        ->flow_mech__customercare__orderview( $self->order->id )
        ->flow_mech__customercare__edit_billing_address
        ->flow_mech__customercare__choose_address;

    $self->country_list_ok;

}

=head1 METHODS

=head2 country_list_ok

Calls C<country_attributes_ok> method to ensure the country that should
contain the attributes, does and all the others don't.

=cut

sub country_list_ok {
    my $self = shift;

    $self->country_attributes_ok( $self->country->country, 1 );

    my @other_countries = $self->schema->resultset('Public::Country')
        ->search( {
            id   => { '!=' => $self->country->id },
            code => { '!=' => '' },
        } )->all;

    $self->country_attributes_ok( $_->country, 0 )
        foreach @other_countries;

}

=head2 country_attributes_ok( $country, $attributes_expected )

Find the given C<$country> name in the Drop-Down, ensure all the attributes
are correct and if C<$attributes_expected> is TRUE, ensure the 'data'
attributes are also present.

=cut

sub country_attributes_ok {
    my $self = shift;
    my ( $country, $attributes_expected ) = @_;

    # Find the country in the drop-down.
    my ( $country_data ) =
        grep { $_->{name} eq $country }
        @{ $self->framework->mech->as_data->{country} };

    # We're not interested which country is selected.
    delete $country_data->{selected};

    my $expected = {
        name    => $country,
        value   => $country,
    };

    if ( $attributes_expected ) {
        $expected->{'data-address_line_1'}  = 'This is Address Line One';
        $expected->{'data-postcode'}        = 'This is the Postcode';
    }

    # Test the attributes are present.
    cmp_deeply( $country_data, $expected,
        $country . ' has the correct attributes.');

}

=head2 framework

Return the L<Test::XT::Flow> object.

=head2 order

Return a C<Public::Order> object.

=head2 country

Return a C<Public::Country> object.

=head2 group_name

Return the name of the system configuration group name.

=cut

sub framework   { return shift->{framework} }
sub order       { return shift->{order_data}->{order_object} }
sub country     { return shift->{country} }
sub group_name  { return shift->{group_name} }

Test::Class->runtests;
