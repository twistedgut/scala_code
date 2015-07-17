package XTracker::Schema::ResultSet::Public::IntegrationContainerItem;

use NAP::policy 'class';
use MooseX::NonMoose;

extends 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB qw/
    :integration_container_item_status
/;

=head1 NAME

XTracker::Schema::ResultSet::Public::IntegrationContainerItem

=head1 DESCRIPTION

Resultset cass for integration_container table.

=head1 METHODS

=head2 filter_non_missing : $self

Leave only non missing items in current resultset.

=cut

sub filter_non_missing {
    my $self = shift;

    my $me = $self->current_source_alias;

    return $self->search({
        "$me.status_id" => { '!=' => $INTEGRATION_CONTAINER_ITEM_STATUS__MISSING },
    });
}
