package Test::XTracker::Schema::Result::Public::RenumerationReason;

use NAP::policy 'test';
use parent 'NAP::Test::Class';

=head1 NAME

Test::XTracker::Schema::Result::Public::RenumerationReason

=head1 DESCRIPTION

Tests various Methods & Result Set Methods for 'XTracker::Schema::Result::Public::RenumerationReason'

=cut

use Test::XTracker::Data;


sub setup : Test(setup) {
    my $self = shift;

    $self->schema->txn_begin;
}

sub teardown : Test(teardown) {
    my $self = shift;

    $self->schema->txn_rollback;
}

=head1 TESTS

=head2 test_get_reasons_for_type

Tests the 'get_reasons_by_type' Result Set method to get
Renumeration Reasons for a Type (such as 'Compensation').

=cut

sub test_get_reasons_for_type : Tests {
    my $self = shift;

    my @departments = $self->rs('Public::Department')->all;

    # create test data
    my %test_data   = (
        reason_types    => [
            'Test Reason Type 1',
            'Test Reason Type 2',
            'Test Reason Type 3',
        ],
        reasons => [
            { reason => 'Test Reason 1', type => 'Test Reason Type 1',
              department => undef },
            { reason => 'Test Reason 2', type => 'Test Reason Type 1',
              department => undef },
            { reason => 'Test Reason 3', type => 'Test Reason Type 2',
              department => undef },
            { reason => 'Test Reason 4', type => 'Test Reason Type 2',
              department => $departments[0] },
            { reason => 'Test Reason 5', type => 'Test Reason Type 3',
              department => $departments[0] },
            { reason => 'Test Reason 6', type => 'Test Reason Type 3',
              department => $departments[1] },
            { reason => 'Test Reason 7', type => 'Test Reason Type 1',
              department => $departments[1] },
        ],
    );
    my $reason_types    = $self->_create_reason_test_data( \%test_data );

    my $renum_reason_rs = $self->rs('Public::RenumerationReason');

    throws_ok {
            $renum_reason_rs->get_reasons_for_type();
        } qr/Renumeration Reason Type Id/i,
        "'get_reasons_by_type' throws an error when passed without a Reason Type Id";

    # specify tests to do
    my %tests   = (
        "Want 'Test Reason Type 1' Reasons with NO Department" => {
            reason_type => $reason_types->{'Test Reason Type 1'},
            department  => undef,
            expected    => [
                'Test Reason 1',
                'Test Reason 2',
            ],
        },
        "Want 'Test Reason Type 2' Reasons with NO Department" => {
            reason_type => $reason_types->{'Test Reason Type 2'},
            department  => undef,
            expected    => [
                'Test Reason 3',
            ],
        },
        "Want 'Test Reason Type 1' Reasons WITH Department" => {
            reason_type => $reason_types->{'Test Reason Type 1'},
            department  => $departments[1],
            expected    => [
                'Test Reason 1',
                'Test Reason 2',
                'Test Reason 7',
            ],
        },
        "Want 'Test Reason Type 3' Reasons with NO Department" => {
            reason_type => $reason_types->{'Test Reason Type 3'},
            department  => undef,
            expected    => [ ],
        },
        "Want 'Test Reason Type 3' Reasons WITH a Department" => {
            reason_type => $reason_types->{'Test Reason Type 3'},
            department  => $departments[0],
            expected    => [
                'Test Reason 5',
            ],
        },
        "Want 'Test Reason Type 3' Reasons WITH another Department" => {
            reason_type => $reason_types->{'Test Reason Type 3'},
            department  => $departments[1],
            expected    => [
                'Test Reason 6',
            ],
        },
        "Want 'Test Reason Type 1' Reasons WITH Department Id" => {
            reason_type => $reason_types->{'Test Reason Type 1'},
            department  => $departments[1]->id,
            expected    => [
                'Test Reason 1',
                'Test Reason 2',
                'Test Reason 7',
            ],
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        my $department  = $test->{department};
        note "using Department: " . $self->_get_dept_description( $department );

        my $got = $renum_reason_rs->get_reasons_for_type(
            $test->{reason_type}->id,
            $department
        );
        isa_ok( $got, 'XTracker::Schema::ResultSet::Public::RenumerationReason',
                        "'get_reasons_for_type' returned as expected" );

        my @got_reasons = map { $_->reason } $got->all;
        is_deeply(
            [ sort @got_reasons ],
            [ sort @{ $test->{expected} } ],
            "and contained the Expected Reasons"
        );
    }

}

=head2 get_compensation_reasons

Test the Method 'get_compensation_reasons' to make sure the only Reasons returned
are those for the Renumeration Reason 'Compensation' type.

=cut

sub get_compensation_reasons : Tests {
    my $self    = shift;

    my @departments = $self->rs('Public::Department')->all;

    # create test data
    my %test_data   = (
        reason_types    => [
            'Compensation',
            'Test Reason Type 1',
        ],
        reasons => [
            { reason => 'Test Reason 1', type => 'Compensation',
              department => undef },
            { reason => 'Test Reason 2', type => 'Compensation',
              department => undef },
            { reason => 'Test Reason 3', type => 'Test Reason Type 1',
              department => undef },
            { reason => 'Test Reason 4', type => 'Compensation',
              department => $departments[0] },
            { reason => 'Test Reason 5', type => 'Test Reason Type 1',
              department => $departments[0] },
            { reason => 'Test Reason 6', type => 'Compensation',
              department => $departments[1] },
            { reason => 'Test Reason 7', type => 'Test Reason Type 1',
              department => $departments[2] },
        ],
    );
    my $reason_types    = $self->_create_reason_test_data( \%test_data );

    my %tests   = (
        "With NO Department"    => {
            department  => undef,
            expect      => [
                'Test Reason 1',
                'Test Reason 2',
            ],
        },
        "With Department that has a Compensation Reason" => {
            department  => $departments[0],
            expect      => [
                'Test Reason 1',
                'Test Reason 2',
                'Test Reason 4',
            ],
        },
        "With a Department that doesn't have any Compensation Reasons, should still get the unassigned ones" => {
            department  => $departments[2],
            expect      => [
                'Test Reason 1',
                'Test Reason 2',
            ],
        },
    );

    my $renum_reason_rs = $self->rs('Public::RenumerationReason');

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        my $department  = $test->{department};
        note "using Department: " . $self->_get_dept_description( $department );

        my $got = $renum_reason_rs->get_compensation_reasons( $department );
        isa_ok( $got, 'XTracker::Schema::ResultSet::Public::RenumerationReason',
                        "'get_compensation_reasons' returned as expected" );

        my @got_reasons = map { $_->reason } $got->all;
        cmp_deeply(
            [ sort @got_reasons ],
            superbagof( @{ $test->{expected} } ),
            "and contained the Expected Reasons"
        );
    }
}

=head2 test_enabled_only

Tests the C<enabled_only> method on the ResultSet, to ensure it only returns
enabled reasons.

=cut

sub test_enabled_only : Tests {
    my $self = shift;

    my $reason_types = $self->_create_reason_test_data({
        reason_types    => [ 'Test Reason Type' ],
        reasons         => [
            { reason => 'Test Reason 1', type => 'Test Reason Type', enabled => 0 },
            { reason => 'Test Reason 2', type => 'Test Reason Type', enabled => 1 },
        ],
    });

    my $reason_type_id  = $reason_types->{'Test Reason Type'}->id;
    my $enabled_only    = $self->schema->resultset('Public::RenumerationReason')
        ->search({ renumeration_reason_type_id => $reason_type_id })
        ->enabled_only;

    cmp_ok( $enabled_only->count, '==', 1,
     'Only ONE Renumeration Reason is enabled' );

    cmp_deeply( { $enabled_only->first->get_columns }, {
        id                          => ignore(),
        renumeration_reason_type_id => $reason_type_id,
        reason                      => 'Test Reason 2',
        department_id               => undef,
        enabled                     => 1,
    }, ' .. and it contains the correct data');

}

#----------------------------------------------------------------------

sub _get_dept_description {
    my ( $self, $department )   = @_;

    return (
        $department
        ? ( ref( $department ) ? $department->department : $department )
        : 'undef'
    );
}

sub _create_reason_test_data {
    my ( $self, $test_data )    = @_;

    my %reason_types;
    foreach my $type ( @{ $test_data->{reason_types} } ) {
        my $rec = $self->rs('Public::RenumerationReasonType')
                            ->update_or_create( { type => $type } );
        $reason_types{ $type }  = $rec;
    }

    foreach my $reason ( @{ $test_data->{reasons} } ) {
        my $department  = $reason->{department};
        $self->rs('Public::RenumerationReason')
                ->create( {
            renumeration_reason_type_id => $reason_types{ $reason->{type} }->id,
            reason                      => $reason->{reason},
            department_id               => ( $department ? $department->id : undef ),
            enabled                     => $reason->{enabled} // 1,
        } );
    }

    return \%reason_types;
}

