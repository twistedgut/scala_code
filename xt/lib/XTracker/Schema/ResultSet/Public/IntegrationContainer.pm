package XTracker::Schema::ResultSet::Public::IntegrationContainer;

use NAP::policy 'class';
use MooseX::NonMoose;

extends 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB qw/
    :prl
/;
use vars qw/$PRL__DEMATIC $PRL__GOH/;

=head1 NAME

XTracker::Schema::ResultSet::Public::IntegrationContainer

=head1 DESCRIPTION

Resultset slcass for integratioon_container table.

=head1 METHODS

=head2 filter_goh() : $integration_container_rs

Leave only GOH related records.

=cut

sub filter_goh {
    my $self = shift;

    $self->search({
        prl_id => $PRL__GOH,
    });
}

=head2 filter_from_dcd() : $integration_container_rs

Leave only contaierns that are comming from Dematic.

=cut

sub filter_from_dcd {
    my $self = shift;

    $self->search({
        from_prl_id => $PRL__DEMATIC,
    });
}

=head2 filter_active() : $integration_container_rs

Leave active records only.

=cut

sub filter_active {
    my $self = shift;

    $self->search({
        is_complete => 0,
    });
}

=head2 get_active_container_row($container_id) : $integration_container_row

For provided container ID return Integration container record
for tote that is in GOH and is not completed yet.

=cut

sub get_active_container_row {
    my ($self, $container_id) = @_;

    return $self
        ->filter_goh
        ->filter_active
        ->search({
            container_id => $container_id,
        },{
            order_by => { -desc => 'id' },
        })
        ->first;
}

=head2 get_last_routed_but_not_arrived_container_row_for($container_id) : $integration_container_row

Get the Integration container record for provided container ID, that
stands for case when user marked container as complete and forgot
to place it to the conveyor, but then scan it on GOH integration
screen once again.

=cut

sub get_last_routed_but_not_arrived_container_row_for {
    my ($self, $container_id) = @_;

    my $me = $self->current_source_alias;
    return $self
        ->filter_goh
        ->search({
            is_complete              => 1,
            container_id             => $container_id,
            'container.pack_lane_id' => { '!=' => undef },
            'container.routed_at'    => { '!=' => undef },
            'container.has_arrived'  => 0,
        },{
            join     => 'container',
            order_by => { -desc => "$me.id" }
        })
        ->first;
}

