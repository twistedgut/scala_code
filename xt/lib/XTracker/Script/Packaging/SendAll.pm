package XTracker::Script::Packaging::SendAll;
use NAP::policy "tt", 'class';
extends 'XT::Common::Script';
with 'XTracker::Role::WithSchema';

sub invoke {
    my ($self,$args) = @_;

    my $packaging_attribute_rs
        = $self->schema->resultset('Public::PackagingAttribute');

    # Find the packaging SKU(s)
    if ( $args->{sku} ) {
        $packaging_attribute_rs = $packaging_attribute_rs->search_related(
            'packaging_type', {
                sku => { '-in', $args->{sku} }
            }
        )->related_resultset('packaging_attributes');
    }

    # Handle the "upload"
    if ( $args->{upload} && $args->{sku} ) {
        _upload_packaging_product($args,$packaging_attribute_rs);
    }
    # "Normal" broadcast
    else {
        _broadcast_packaging_product($args,$packaging_attribute_rs);
    }

    # We're done now
    exit(0);

}

sub _upload_packaging_product {
    my ($args, $packaging_attribute_rs) = @_;

    # Handle the upload
    while ( my $pa = $packaging_attribute_rs->next ) {
        say "Uploading packaging product with SKU " . $pa->sku
            if $args->{verbose};

        $pa->upload() unless $args->{dryrun};

    }

  }

sub _broadcast_packaging_product {
    my ($args, $packaging_attribute_rs) = @_;

    # Massage any environmnet options into the format the method expects
    my %envs;
    if ( $args->{live} ) {
       $envs{live} = 1;
    }
    if ( $args->{staging} ) {
        $envs{staging} = 1;
    }

    # Handle the broadcast
    while ( my $pa = $packaging_attribute_rs->next ) {
        say "Broadcasting packaging product with SKU " . $pa->sku
            if $args->{verbose};

        $pa->broadcast( { envs => \%envs } ) unless $args->{dryrun};
    }

}

=head1 NAME

XTracker::Script::Packaging::SendAll - Broadcast all packaging products

=head1 DESCRIPTION

Loops through all the L<XTracker::Schema::Public::PackagingAttribute> objects and
broadcasts their data.

=head1 METHODS

=head2 C<invoke>

Do the work.

=cut
