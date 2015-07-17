package XT::DC::Messaging::Producer::Sync::VariantMeasurement;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer';

use XTracker::Config::Local qw( config_var );
use XT::DC::Messaging::Spec::VMSync ();
use JSON::XS ();

=head1 NAME

XT::DC::Messaging::Producer::Sync::VariantMeasurement

=head1 SYNOPSIS

This sends the VariantMeasurements updates to all other DCs

    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::Sync::VariantMeasurement',
        {
            variants => [$variant_id, ... ]
        },
    );

=cut

sub message_spec { return XT::DC::Messaging::Spec::VMSync::vmsync() }

has '+type' => ( default => 'vmsync' );

sub transform {
    my ( $self, $header, $data ) = @_;

    my @variant_ids = @{$data->{variants}};
    my $schema = $data->{schema};

    my @ret = ();

    for my $vid (@variant_ids) {

        my $variant = $schema->resultset('Public::Variant')->find($vid);

        my $payload = {
            product_id => $variant->product_id,
            variant_id => $vid,
            measurements => $variant->get_measurements_payload(),
        };

        # this shallow-copy is needed because
        # XT::DC::Messaging::Role::Producer edits the header,
        # so only the first one would be correct
        my %loc_header = ( %$header, JMSXGroupID => $variant->product_id );
        push @ret,\%loc_header,$payload;
    }

    return @ret;
}

1;
