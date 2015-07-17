package XTracker::Schema::ResultSet::Public::Prl;
use parent 'DBIx::Class::ResultSet';
use Moose;
use MooseX::NonMoose;
with "XTracker::Schema::Role::ResultSet::GroupBy";

=head1 METHODS

=head2 sysconfig_parameter( $name ) : $value

Look up PRL sysconfig value for the PickScheduler parameter $name.

=cut

sub sysconfig_parameter {
    my ( $self, $name ) = @_;
    return $self->result_source->schema
        ->resultset("SystemConfig::ParameterGroup")
        ->parameter("prl_pick_scheduler_v2", $name);
}

=head2 filter_active : $prl_rs

Filters a resultset to return only active PRLs.

=cut

sub filter_active {
    my $self    = shift;

    return $self->search({ is_active => 1 });
}

=head2 prl_capacity() : $prl_capacity

Return hashref with (keys: prl.identifier_name; values
XTracker::Pick::PrlCapacity objects) for all PRLs in the resultset.

=cut

sub prl_capacity {
    my $self = shift;

    my $allocation_rs = $self->result_source->schema->resultset(
        "Public::Allocation",
    );
    my $prl_allocation_in_picking_count = $self->prl_count_to_hashref(
        scalar $allocation_rs->filter_picking->prl_allocation_count_rs(),
    );
    my $prl_container_in_staging_count = $self->prl_count_to_hashref(
        scalar $allocation_rs->filter_staged->prl_container_count_rs(),
    );

    return {
        map {
            $_->identifier_name => $_->as_prl_capacity(
                $prl_allocation_in_picking_count,
                $prl_container_in_staging_count,
            );
        }
        $self->all
    };
}

=head2 prl_count_to_hashref($prl_count_rs) : $hashref

Return hashref with the row columns ("prl", "count") for each row in
$prl_count_rs.

e.g. return value:

    {
        full => 3,
        dcd  => 44,
    }

=cut

sub prl_count_to_hashref {
    my ($self, $prl_count_rs) = @_;
    return +{
        map { $_->get_column("prl") => $_->get_column("count") }
        grep { defined $_->get_column("count") }
        $prl_count_rs->all
    };
}

1;
