package Test::XTracker::Schema::ResultSet::Public::CustomerIssueType;
use NAP::policy qw( test class );

BEGIN {
    extends 'NAP::Test::Class';
    with    'Test::Role::WithSchema';
};

use Test::XTracker::Data;

=head1 NAME

Test::XTracker::Schema::ResultSet::Public::CustomerIssueType

=head1 DESCRIPTION

Test the XTracker::Schema::ResultSet::Public::CustomerIssueType class.

=cut

sub test_setup : Test( setup => no_plan ) {
    my $self = shift;
     $self->SUPER::setup;

}

sub test_teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;


}

=head1 TESTS

=head2 test_html_select_data

The C<html_select_data> method is provided by the role
L<XTracker::Schema::Role::ResultSet::HTMLSelect>.

=cut

sub test_html_select_data : Tests {
    my $self = shift;

    my %tests = (
        'Single Visible Category' => {
            setup => {
                categories => [
                    { description => 'Visible Category', description_visible => 1, display_sequence => 0 },
                ],
                customer_issue_types => [
                    { description => 'Single Issue', category => 'Visible Category', display_sequence => 0, enabled => 1 },
                ]
            },
            arguments => [],
            expected => [
                { action => 'start-group', data => { label => 'Visible Category' } },
                { action => 'insert-option', data => { value => ignore(), display => 'Single Issue', selected => 0 } },
                { action => 'end-group' },
            ],
        },
        'Single Invisible Category' => {
            setup => {
                categories => [
                    { description => 'Invisible Category', description_visible => 0, display_sequence => 0 },
                ],
                customer_issue_types => [
                    { description => 'Single Issue', category => 'Invisible Category', display_sequence => 0, enabled => 1 },
                ]
            },
            arguments => [],
            expected => [
                { action => 'insert-option', data => { value => ignore(), display => 'Single Issue', selected => 0 } },
            ],
        },
        'Disabled Issue Type' => {
            setup => {
                categories => [
                    { description => 'Invisible Category', description_visible => 0, display_sequence => 0 },
                ],
                customer_issue_types => [
                    { description => 'Disabled Issue', category => 'Invisible Category', display_sequence => 0, enabled => 0 },
                    { description => 'Enabled Issue', category => 'Invisible Category', display_sequence => 0, enabled => 1 },
                ]
            },
            arguments => [],
            expected => [
                { action => 'insert-option', data => { value => ignore(), display => 'Enabled Issue', selected => 0 } },
            ],
        },
        'No Ordering On Issue Type' => {
            setup => {
                categories => [
                    { description => 'Invisible Category', description_visible => 0, display_sequence => 0 },
                ],
                customer_issue_types => [
                    { description => 'B Should Come Second', category => 'Invisible Category', display_sequence => 0, enabled => 1 },
                    { description => 'A Should Come First', category => 'Invisible Category', display_sequence => 0, enabled => 1 },
                ]
            },
            arguments => [],
            expected => [
                { action => 'insert-option', data => { value => ignore(), display => 'A Should Come First', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'B Should Come Second', selected => 0 } },
            ],
        },
        'Ordering On Issue Type' => {
            setup => {
                categories => [
                    { description => 'Invisible Category', description_visible => 0, display_sequence => 0 },
                ],
                customer_issue_types => [
                    { description => 'A Should Come Second', category => 'Invisible Category', display_sequence => 2, enabled => 1 },
                    { description => 'B Should Come First', category => 'Invisible Category', display_sequence => 1, enabled => 1 },
                ]
            },
            arguments => [],
            expected => [
                { action => 'insert-option', data => { value => ignore(), display => 'B Should Come First', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'A Should Come Second', selected => 0 } },
            ],
        },
        'Two Categories, One Visible, One Invisible, With Ordering' => {
            setup => {
                categories => [
                    { description => 'B Visible Category', description_visible => 1, display_sequence => 1 },
                    { description => 'A Invisible Category', description_visible => 0, display_sequence => 2 },
                ],
                customer_issue_types => [
                    { description => 'Issue Type 1', category => 'B Visible Category', display_sequence => 1, enabled => 1 },
                    { description => 'Issue Type 2', category => 'B Visible Category', display_sequence => 2, enabled => 1 },
                    { description => 'Issue Type 3', category => 'A Invisible Category', display_sequence => 1, enabled => 1 },
                    { description => 'Issue Type 4', category => 'A Invisible Category', display_sequence => 2, enabled => 1 },
                ]
            },
            arguments => [],
            expected => [
                { action => 'start-group', data => { label => 'B Visible Category' } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 1', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 2', selected => 0 } },
                { action => 'end-group' },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 3', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 4', selected => 0 } },
            ],
        },
        'Two Categories, One Visible, One Invisible, No Ordering' => {
            setup => {
                categories => [
                    { description => 'B Visible Category', description_visible => 1, display_sequence => 0 },
                    { description => 'A Invisible Category', description_visible => 0, display_sequence => 0 },
                ],
                customer_issue_types => [
                    { description => 'Issue Type 1', category => 'B Visible Category', display_sequence => 1, enabled => 1 },
                    { description => 'Issue Type 2', category => 'B Visible Category', display_sequence => 2, enabled => 1 },
                    { description => 'Issue Type 3', category => 'A Invisible Category', display_sequence => 1, enabled => 1 },
                    { description => 'Issue Type 4', category => 'A Invisible Category', display_sequence => 2, enabled => 1 },
                ]
            },
            arguments => [],
            expected => [
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 3', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 4', selected => 0 } },
                { action => 'start-group', data => { label => 'B Visible Category' } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 1', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 2', selected => 0 } },
                { action => 'end-group' },
            ],
        },
        'Two Categories, Both Visible, With Ordering' => {
            setup => {
                categories => [
                    { description => 'B Visible Category', description_visible => 1, display_sequence => 1 },
                    { description => 'A Visible Category', description_visible => 1, display_sequence => 2 },
                ],
                customer_issue_types => [
                    { description => 'Issue Type 1', category => 'B Visible Category', display_sequence => 1, enabled => 1 },
                    { description => 'Issue Type 2', category => 'B Visible Category', display_sequence => 2, enabled => 1 },
                    { description => 'Issue Type 3', category => 'A Visible Category', display_sequence => 1, enabled => 1 },
                    { description => 'Issue Type 4', category => 'A Visible Category', display_sequence => 2, enabled => 1 },
                ]
            },
            arguments => [],
            expected => [
                { action => 'start-group', data => { label => 'B Visible Category' } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 1', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 2', selected => 0 } },
                { action => 'end-group' },
                { action => 'start-group', data => { label => 'A Visible Category' } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 3', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 4', selected => 0 } },
                { action => 'end-group' },
            ],
        },
        'Two Categories, Both Visible, No Ordering' => {
            setup => {
                categories => [
                    { description => 'B Visible Category', description_visible => 1, display_sequence => 0 },
                    { description => 'A Visible Category', description_visible => 1, display_sequence => 0 },
                ],
                customer_issue_types => [
                    { description => 'Issue Type 1', category => 'B Visible Category', display_sequence => 1, enabled => 1 },
                    { description => 'Issue Type 2', category => 'B Visible Category', display_sequence => 2, enabled => 1 },
                    { description => 'Issue Type 3', category => 'A Visible Category', display_sequence => 1, enabled => 1 },
                    { description => 'Issue Type 4', category => 'A Visible Category', display_sequence => 2, enabled => 1 },
                ]
            },
            arguments => [],
            expected => [
                { action => 'start-group', data => { label => 'A Visible Category' } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 3', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 4', selected => 0 } },
                { action => 'end-group' },
                { action => 'start-group', data => { label => 'B Visible Category' } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 1', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 2', selected => 0 } },
                { action => 'end-group' },
            ],
        },
        'Two Categories, Both Invisible, With Ordering' => {
            setup => {
                categories => [
                    { description => 'B Invisible Category', description_visible => 0, display_sequence => 1 },
                    { description => 'A Invisible Category', description_visible => 0, display_sequence => 2 },
                ],
                customer_issue_types => [
                    { description => 'Issue Type 1', category => 'B Invisible Category', display_sequence => 1, enabled => 1 },
                    { description => 'Issue Type 2', category => 'B Invisible Category', display_sequence => 2, enabled => 1 },
                    { description => 'Issue Type 3', category => 'A Invisible Category', display_sequence => 1, enabled => 1 },
                    { description => 'Issue Type 4', category => 'A Invisible Category', display_sequence => 2, enabled => 1 },
                ]
            },
            arguments => [],
            expected => [
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 1', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 2', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 3', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 4', selected => 0 } },
            ],
        },
        'Two Categories, Both Invisible, No Ordering' => {
            setup => {
                categories => [
                    { description => 'B Invisible Category', description_visible => 0, display_sequence => 0 },
                    { description => 'A Invisible Category', description_visible => 0, display_sequence => 0 },
                ],
                customer_issue_types => [
                    { description => 'Issue Type 1', category => 'B Invisible Category', display_sequence => 1, enabled => 1 },
                    { description => 'Issue Type 2', category => 'B Invisible Category', display_sequence => 2, enabled => 1 },
                    { description => 'Issue Type 3', category => 'A Invisible Category', display_sequence => 1, enabled => 1 },
                    { description => 'Issue Type 4', category => 'A Invisible Category', display_sequence => 2, enabled => 1 },
                ]
            },
            arguments => [],
            expected => [
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 3', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 4', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 1', selected => 0 } },
                { action => 'insert-option', data => { value => ignore(), display => 'Issue Type 2', selected => 0 } },
            ],
        },
    );

    while ( my ( $name, $test ) = each %tests ) {

        subtest $name => sub {
            $self->schema->txn_do( sub {

                my $group = $self->new_customer_issue_type_group('Test Group');

                my %categories =
                    map { $_->{description} => $self->new_customer_issue_type_category( $_ ) }
                    @{ $test->{setup}->{categories} };

                my %customer_issue_types =
                    map { $_->{description} => $self->new_customer_issue_type( $group, \%categories, $_ ) }
                    @{ $test->{setup}->{customer_issue_types} };

                my $got = $self->schema->resultset('Public::CustomerIssueType')
                    ->search({ group_id => $group->id })
                    ->html_select_data;

                cmp_deeply( $got, $test->{expected},
                    'The result of "html_select_data" contains the correct data' );

                $self->schema->txn_rollback;

            });
        };

    }

}

=head1 METHODS

=head2 new_customer_issue_type_group( $name )

Create a new "Public::CustomerIssueTypeGroup" record with the given C<$name>.

=cut

sub new_customer_issue_type_group {
    my $self = shift;
    my ( $name ) = @_;

    my $customer_issue_type_group = $self->schema->resultset('Public::CustomerIssueTypeGroup');

    # This table has a broken sequence!
    Test::XTracker::Data->bump_sequence( $customer_issue_type_group->result_source->name );

    return $customer_issue_type_group->create({
        description => $name,
    });

}

=head2 new_customer_issue_type_category( $options )

Create a new "Public::CustomerIssueTypeCategory" record with the given
C<$options>, which are passed directly through to the L<DBIx::Class::ResultSet>
C<create> method.

=cut

sub new_customer_issue_type_category {
    my $self = shift;
    my ( $options ) = @_;

    return $self->schema->resultset('Public::CustomerIssueTypeCategory')->create( $options );

}

=head2 new_customer_issue_type( $group, $categories, $options )

Create a new "Public::CustomerIssueType" record using the given HashRef of
C<$options>. The record will be attached the C<$group> provided (which must
be a "Public::CustomerIssueTypeGroup" object) and the "category" specified in
C<$options> from the HashRef of C<$categories> (a HashRef of
"Public::CustomerIssueTypeCategory" records keyed by the name).

=cut

sub new_customer_issue_type {
    my $self = shift;
    my ( $group, $categories, $options ) = @_;

    $options->{group_id}    = $group->id;
    $options->{category_id} = $categories->{ delete $options->{category} }->id;

    return $self->schema->resultset('Public::CustomerIssueType')->create( $options );

}

