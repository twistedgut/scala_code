package Test::XTracker::Data::Manifest;
use NAP::policy qw/class/;

with 'XTracker::Role::WithSchema';

use DateTime;
use XTracker::Constants::FromDB qw(
    :manifest_status
);
use MooseX::Params::Validate;

sub create_db_manifest {
    my ($self, $filename, $cut_off, $status_id, $carrier_id, $restricted_to_channel_ids) = validated_list(\@_,
        filename                    => { isa => 'Str', default => 'manifest.csv' },
        cut_off                     => { isa => 'HashRef', optional => 1 },
        status_id                   => { isa => 'Str', default => $PUBLIC_MANIFEST_STATUS__COMPLETE },
        carrier_id                  => { isa => 'Str', optional => 1 },
        restricted_to_channel_ids   => { isa => 'ArrayRef[Str]', optional => 1 },
    );

    my $cutoff_datetime = ( $cut_off ? DateTime->new(%$cut_off) : DateTime->now() );

    # If no carrier is specified, we'll assume it doesn't matter which one is used,
    # So just grab the first entry we find in the table
    $carrier_id //= $self->schema->resultset('Public::Carrier')->first->id();

    my $manifest = $self->schema->resultset('Public::Manifest')->create({
        filename    => $filename,
        cut_off     => $cutoff_datetime,
        status_id   => $status_id,
        carrier_id  => $carrier_id,
    });

    if($restricted_to_channel_ids) {
        my @channel_links = map {{
            channel_id  => $_,
            manifest_id => $manifest->id()
        }} @$restricted_to_channel_ids;
        $self->schema->resultset('Public::LinkManifestChannel')->populate(\@channel_links);
    }

    return $manifest;
}