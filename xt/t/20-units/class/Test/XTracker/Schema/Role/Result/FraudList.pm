package Test::XTracker::Schema::Role::Result::FraudList;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XTracker::Schema::Role::Result::FraudList

=head1 SYNOPSIS

Will test Both 'Result' and 'ResulSet' Roles.

=head1 TESTS

=cut

use Test::XT::Data;
use Test::XT::Data::FraudList;

# to be done first before ALL the tests start
sub startup : Test( startup => 0 ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema}     = Test::XTracker::Data->get_schema;

}

# to be done BEFORE each test runs
sub setup : Test( setup => 0 ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->{list_obj} = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::FraudList',
        ],
    );

    $self->schema->txn_begin;
}

# to be done AFTER every test runs
sub teardown : Test( teardown => 0 ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}

=head2 values_by_list_id

Tests the values_by_list_id method in the ResultSet Role.

The method should require a list id and die if one is not supplied.

Supplied with a valid list ID the method should return an array
reference containing all of the values in that list.

=cut

sub values_by_list_id : Tests() {
    my $self = shift;

    my $list = $self->{list_obj}->fraud_list;
    my $list_items = $self->{list_obj}->fraud_list_items;
    my $list_id = $list->id;

    throws_ok( sub {
        $self->{schema}->resultset('Fraud::StagingList')->values_by_list_id();
        },
    qr/You must pass in the list id/,
    "Dies with correct error if called with no list id" );

    my @got = $self->{schema}->resultset('Fraud::StagingList')->values_by_list_id($list_id);
    cmp_bag( \@got, $list_items, "List contains same values" );
}

=head2 all_list_items

Should return an array reference containing all list items

=cut

sub all_list_items : Tests() {
    my $self = shift;

    my $list = $self->{list_obj}->fraud_list;
    my $list_items = $self->{list_obj}->fraud_list_items;

    cmp_bag( $list->all_list_items, $list_items, "All list items present" );
}
