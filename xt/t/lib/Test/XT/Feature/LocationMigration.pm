package Test::XT::Feature::LocationMigration;

# Wrapper methods around Test::XTracker::LocationMigration

use strict;
use warnings;
use Moose::Role;
use Test::XTracker::LocationMigration;

has 'location_migration_test_object' => (
    isa     => 'Test::XTracker::LocationMigration',
    is      => 'rw',
);

# Not using handles here as don't know how to wrap those values so these methods
# return self
sub test_db__location_migration__snapshot {
    my $self = shift;
    $self->location_migration_test_object->snapshot(@_);
    return $self;
}
sub test_db__location_migration__test_delta {
    my $self = shift;
    $self->location_migration_test_object->test_delta(@_);
    return $self;
}


sub test_db__location_migration__init {
    my $self = shift;
    my $variant_id = shift;
    my $test = Test::XTracker::LocationMigration->new(
        variant_id => $variant_id,
        debug => 0,
    );
    $self->location_migration_test_object( $test );
    return $self;
}

1;
