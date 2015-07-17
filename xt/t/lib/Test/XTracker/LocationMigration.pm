package Test::XTracker::LocationMigration;

use NAP::policy "tt", qw (test class);
use Test::Differences;

use XTracker::Database qw(xtracker_schema);

use Data::Dumper;

=head1 NAME

Test::XTracker::LocationMigration

=head1 DESCRIPTION

Run tests relating to the Location Migration part of DCEA

=head1 SYNOPSIS

 my $test = Test::XTracker::LocationMigration->new( variant_id => $variant_id );

 $test->snapshot('Before');
 ... do some stuff...
 $test->snapshot('After');

 # test_delta compares the number of the variant we have per location-type
 $test->test_delta(
    from => 'Before',
    to   => 'After',
    stock_status => { 'Main Stock' => -5, 'In Transit' => +5 }
 );


=head1 OVERVIEW

Fundamentally many of our tests want to make sure that the number of items in
various states - whether that state comes from their location (currently), or
whether that comes from an explicit state id (what we're developing)
changes when processes are run. This module simplifies those testing tasks.

Create a new object per C<variant_id> that you want to track. You can save the
current state using the C<snapshot> method and providing a name for your
snapshot.

=cut

has 'states' => ( is => 'rw', isa => 'HashRef', default  => sub { return {}; } );
has 'variant_id' => ( is => 'ro', isa => 'Int', required => 1 );
has 'debug'  => ( is => 'ro', isa => 'Int', default => 0 );
has '_test_states' => (
    is  => 'ro',
    isa => 'ArrayRef',
    default => sub {
        return ['stock_status'];
    }
);

sub BUILD {
    my $self = shift;
    if ( $self->debug ) {
        note "New LocationMigration object created for variant_id = " .
            $self->variant_id;
    }
}

=head2 snapshot

 $test->snapshot('Some name');

Saves a summary of what stock_statuses our variant_id is in, and in which quantity

=cut

sub snapshot {
    my ( $self, $name ) = @_;
    die "You already have a state called '$name'" if $self->states->{$name};
    $self->states->{$name} = $self->_create_state( $name );
    return 1;
};

sub _create_state {
    my ($self, $name) = @_;

    my $dbh = xtracker_schema()->storage->dbh;

    my $result = {};
    for (
        [ stock_status =>
            'SELECT
                SUM(quantity.quantity) AS item_count,
                flow.status.name AS stock_status
            FROM quantity
                JOIN flow.status ON quantity.status_id = flow.status.id
            WHERE quantity.variant_id = ?
            GROUP BY flow.status.name'
        ]
    ) {
        my ( $key, $sql ) = @$_;
        next unless grep { $_ eq $key } @{$self->_test_states};
        my $count_by_type = $dbh->prepare($sql);
        $count_by_type->execute( $self->variant_id );

        $result->{$key} = { map {
            $_->{'stock_status'} => $_->{'item_count'}
        } @{$count_by_type->fetchall_arrayref({})} };
        if ( $self->debug ) {
            note "States via $key at snapshot '$name': ";
            note Dumper $result->{$key};
        }
        if ( $self->debug > 1 ) {
            note "General quantity-table search for that variant ID";
            my $general_search = $dbh->prepare("
                SELECT
                    q.variant_id AS variant_id,
                    q.location_id AS location_id,
                    q.quantity AS quantity,
                    f.name AS status
                FROM
                    quantity q
                JOIN
                    flow.status f ON (q.status_id = f.id)
                WHERE q.variant_id = ?
            ");
            $general_search->execute( $self->variant_id );
            note Dumper $general_search->fetchall_arrayref({});
        }
    }

    return $result;
}

=head2 test_delta

Checks two snapshots against a hashref you provide with expected stock movements
- checks that actual delta against your reference using C<eq_or_diff>.

=cut

sub test_delta {
    my ( $self, %args ) = @_;

    for my $type ( @{$self->_test_states} ) {
        unless ($args{ $type }) {
            note "No $type test to run" ;
            next;
        }

        my $start = $self->states->{$args{'from'}}->{$type}
            || die "No state called " . $args{'from'};
        my $end   = $self->states->{$args{'to'}  }->{$type}
            || die "No state called " . $args{'to'};

        # Shared keys
        my %combined_hash = (%$start, %$end);
        my @combined_keys = keys %combined_hash;
        my $diff = {};
        for my $key (@combined_keys) {
            my $from  = $start->{$key} || 0;
            my $to    = $end->{$key}   || 0;
            my $delta = $to - $from;
            $diff->{$key} = $delta if $delta;
        }

        # Clean '' markers out of diff for cases where stock disappears from the
        # quantity table as part of a process(!)
        my $spec = $args{$type};
        delete $spec->{''};

        # Run the test
        my $description =
            $args{'description'} || sprintf(
            'Variant [%s]: Delta from "%s" to "%s" is correct (using %s)',
            $self->variant_id, $args{'from'}, $args{'to'}, $type );
        eq_or_diff( $diff, $spec, $description );
    }
}

1;
