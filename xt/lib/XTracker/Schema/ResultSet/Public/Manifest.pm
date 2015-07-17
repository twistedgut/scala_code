package XTracker::Schema::ResultSet::Public::Manifest;
use NAP::policy qw/class/;
extends 'XTracker::Schema::ResultSetBase';

use XTracker::Constants::FromDB qw(
    :manifest_status
);

use MooseX::Params::Validate;

=head1 NAME

XTracker::Schema::ResultSet::Public::Manifest

=head1 PUBLIC METHODS

=head2 create_manifest

Create a new manifest, including links to relevant channels and logging the initial status

First param is a hashref that will be passed to resultset('Public'::Manifest)->create(...)

Second param is a hashref with these keys:

channel_ids : An arrayref of channel_ids that this manifest will be associated with

return - $manifest : The new manifest Row object

=cut
sub create_manifest {
    my $self = shift;
    my $constructor_args = shift;
    $constructor_args //= {};
    $constructor_args->{status_id} //= $PUBLIC_MANIFEST_STATUS__EXPORTING;

    my ($channel_ids) = validated_list(\@_,
        channel_ids => { isa => 'ArrayRef[Int]' },
    );

    my $manifest;

    $self->result_source->schema->txn_do(sub {
        $manifest = $self->create($constructor_args);

        $manifest->log_status($constructor_args->{status_id});

        if(@$channel_ids) {
            my @channel_links_defs = map {{
                manifest_id => $manifest->id(),
                channel_id  => $_,
            }} @$channel_ids;
            $self->result_source->schema->resultset('Public::LinkManifestChannel')->populate(\@channel_links_defs)
        }
    });

    return $manifest;
}

=head2 search_locking_status

Searches the current resultset for manifests that are in the correct status to
 prevent another manifest being created

=cut
sub search_locking_status {
    my ($self) = @_;
    return $self->search({
        status_id => { -in => [$self->_lock_statuses()] }
    });
}

sub _lock_statuses {
    my ( $self ) = @_;
    return (
        $PUBLIC_MANIFEST_STATUS__EXPORTING,
        $PUBLIC_MANIFEST_STATUS__EXPORTED
    );
}

=head2 search_by_channel_ids

Filter the current resultset by a list of channel_ids. A manifest will match if it
is linked to *any* of the given channel_ids. Manifests with *no* associated links
are assumed to be linked to all current channels (for backwards compatability
with manifest created before the link__manifest_channel table)

param - $channel_ids : Arrayref of channel_ids to search by

return - $rs : Filtered resultset

=cut
sub search_by_channel_ids {
    my ($self, $channel_ids) = @_;

    # Manifests with no associated channels are assumed to be associated with
    # all channels
    return $self->search({
        'link_manifest__channels.channel_id' => [
            @$channel_ids,
            undef
        ],
    }, {
        join => 'link_manifest__channels',
    });
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

