package Test::XT::Address::Format::PSP;
use NAP::policy 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::Address::Format::Country

=head1 DESCRIPTION

Tests the XT::Address::Format::Country class.

=cut

use Test::XTracker::Data;
use Test::MockModule;

=head1 TESTS

=head2 startup

Check we can load all the classes we need and set up shared data.

=cut

sub startup : Tests( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    use_ok('XT::Address');
    use_ok('XT::Address::Format::PSP');

    $self->{schema}     = Test::XTracker::Data->get_schema();
    $self->{country}    = $self->{schema}->resultset('Public::Country')->first;

}

=head2 setup

Begins a transaction and creates a new L<Public::OrderAddress> record.

=cut

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();

    $self->{schema}->txn_begin;

    $self->{order_address}  = $self->{schema}->resultset('Public::OrderAddress')->create({
        address_hash    => 'address_hash',
        address_line_1  => 'address_line_1',
        address_line_2  => 'address_line_2',
        address_line_3  => 'address_line_3',
        country         => lc( $self->{country}->country ),
        county          => 'county',
        first_name      => 'first_name',
        last_name       => 'last_name',
        postcode        => 'postcode',
        title           => 'title',
        towncity        => 'towncity',
        urn             => 'urn',
    });

}

=head2 teardown

Rolls back the transaction.

=cut

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    $self->{schema}->txn_rollback;

}

=head2 test_APPLY_FORMAT

Test the method correctly formats the address to be suitable for the PSP.

=cut

sub test_APPLY_FORMAT : Tests {
    my $self = shift;

    my $xt_address      = new_ok( 'XT::Address' => [ $self->{order_address} ] );
    my $format_country  = new_ok( 'XT::Address::Format::PSP' => [{ address => $xt_address }] );

    $format_country->APPLY_FORMAT;

    my $expected = {
        address1        => $self->{order_address}->address_line_1,
        streetName      => '',
        houseNumber     => '',
        address2        => $self->{order_address}->address_line_2,
        city            => $self->{order_address}->towncity,
        stateOrProvince => $self->{order_address}->county,
        postcode        => $self->{order_address}->postcode,
        country         => $self->{order_address}->country_ignore_case->code,
    };

    cmp_deeply( $xt_address->as_hashref, $expected,
        'The address has been formatted correctly' );

}
