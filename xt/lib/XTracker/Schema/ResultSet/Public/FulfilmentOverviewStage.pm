package XTracker::Schema::ResultSet::Public::FulfilmentOverviewStage;
use NAP::policy;

use base 'DBIx::Class::ResultSet';
use XTracker::Config::Local     qw(
    config_var
);
use XTracker::Constants::FromDB qw(
    :fulfilment_overview_stage
);

=head1 NAME

XTracker::Schema::ResultSet::Public::FulfilmentOverviewStage

=head1 METHODS

=head2 filter_active : $stages_rs

Filters a resultset to return only active fulfilment overview stages.

=cut

sub filter_active {
    my $self    = shift;
    return $self->search({ is_active => 1 });
}

=head2 id_stage_name() : \%id_stage_name_map

Return hashref with (keys: fulfilment_overview_stage.id, values: stage).

=cut

sub id_stage_name {
    my $self = shift;
    return {
        map { $_->id => $_->stage }
        $self->filter_active->all,
    };
}
