package Test::XTracker::Pick::TestScheduler;
use NAP::policy "class", "test";
extends "XTracker::Pick::Scheduler";

=head1 NAME

Test::XTracker::Pick::TestScheduler

=head1 DESCRIPTION

Test Pick::TestScheduler with a limited set of returned Shipments, and a
mocked set of capacities and prl capacities.

=cut

use XTracker::Pick::PrlCapacity;

use Test::MockModule;


=head1 ATTRIBUTES

=cut

# Shipment ids under test
has test_shipment_ids => (
    is      => "ro",
    isa     => "ArrayRef",
    lazy    => 1,
    default => sub { [] },
);

# Config keys/values for sysconfig_parameter to return
has mock_sysconfig_parameter => (
    is      => "ro",
    lazy    => 1,
    default => sub { {} },
);



# Limit the shipment list to the ones in ->test_shipment_ids
sub _build_shipments_to_schedule_rs {
    my $self = shift;
    scalar $self->shipment_selection_rs->search({
        "me.id" => $self->test_shipment_ids,
    }),
}

sub _build_prl_capacity {
    my $self = shift;

    my @prl_rows = @{$self->prl_rows};
    return +{
        map {
            $_->identifier_name => XTracker::Pick::PrlCapacity->new({
                prl_row                         => $_,
                prl_allocation_in_picking_count => {
                    full => 0,
                    dcd  => 0,
                    goh  => 0,
                },
                prl_container_in_staging_count => {
                    full => 0,
                },
            })
        }
        @{$self->prl_rows}
    };
}

sub _build_shipment_process_count { 100 }

has prl_rows => (
    is      => "ro",
    lazy    => 1,
    default => sub { return [ shift->prl_rs->all ] },
);

# Keep the mocked config alive until the pick scheduler goes out of
# scope
has mock_sysconfig_parameter_guard => (
    is  => "rw",
    isa => "Test::MockModule",
);



=head1 METHODS

=cut

sub BUILD {
    my $self = shift;

    $self->mock_sysconfig_parameter_guard(
        $self->mock_sysconfig_parameter_values($self->mock_sysconfig_parameter),
    );
}

sub mock_sysconfig_parameter_values {
    my ($self, $key_value) = @_;
    $key_value //= {};
    note "Mocking Prl->sysconfig_parameter";

    my $mock_prl = Test::MockModule->new(
        "XTracker::Schema::ResultSet::Public::Prl",
    );
    $mock_prl->mock(sysconfig_parameter => sub {
        my $self = shift;
        my ($name) = @_;
        # make the defaults high - if we haven't specified a particular
        # capacity, we probably don't want to run out of that one because
        # it's not what we're testing
        my $prl_picking_total_capacity = {
            packing_total_capacity      => 1000,
            full_picking_total_capacity => 1000,
            dcd_picking_total_capacity  => 1000,
            goh_picking_total_capacity  => 1000,
            full_staging_total_capacity => 1000,
            %$key_value,
        };
        return $prl_picking_total_capacity->{$name}
            // confess "Unknown sysconfig_parameter($name)";
    });

    return $mock_prl;
}
