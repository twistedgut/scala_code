package XTracker::Script::Shipping::SendAll;
use NAP::policy "tt", 'class';
extends 'XT::Common::Script';
with 'XTracker::Role::WithSchema';

sub invoke {
    my ($self,$args) = @_;

    my $shipping_description_rs
        = $self->schema->resultset('Shipping::Description');

    if ( $args->{sku} ) {
        $shipping_description_rs = $shipping_description_rs->search_related(
            'shipping_charge', {
                sku => { '-in', $args->{sku} }
            }
        )->related_resultset('shipping_description');
    }

    # Handle the "upload"
    if ( $args->{upload} && $args->{sku} ) {
        _upload_shipping_product($args,$shipping_description_rs);
    }
    # "Normal" broadcast
    else {
        _broadcast_shipping_product($args,$shipping_description_rs);
    }

    # We're done now
    exit(0);

}

sub _upload_shipping_product {
    my ($args, $shipping_description_rs) = @_;

    # Handle the upload
    while ( my $shp_dsc = $shipping_description_rs->next ) {
        say "Broadcasting shipping product with SKU "
            . $shp_dsc->shipping_charge->sku if $args->{verbose};

        $shp_dsc->upload() unless $args->{dryrun};

    }

}

sub _broadcast_shipping_product {
    my ($args, $shipping_description_rs) = @_;

    my %envs;
    if ( $args->{live} ) {
       $envs{live} = 1;
    }
    if ( $args->{staging} ) {
        $envs{staging} = 1;
    }

    while ( my $shp_dsc = $shipping_description_rs->next ) {
        say "Broadcasting shipping product with SKU "
            . $shp_dsc->shipping_charge->sku if $args->{verbose};

        $shp_dsc->broadcast( { envs => \%envs } ) unless $args->{dryrun};
    }

}

=head1 NAME

XTracker::Script::Shipping::SendAll - Broadcast all shipping products

=head1 DESCRIPTION

Loops through all the L<XTracker::Schema::Shipping::Description> objects and
broadcasts their data.

=head1 METHODS

=head2 C<invoke>

Do the work.

=cut
