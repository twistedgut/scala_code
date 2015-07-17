package NAP::Locale::Role::Product;

use NAP::policy "tt", qw( role );

use XT::Service::Product;

with 'NAP::Locale::Role';

=head1

=head2 localise_product_data

    my $data = $locale_obj->localise_product_data($data);

=cut

sub localise_product_data {
    my ($self, $data) = @_;

    return unless $data;

    unless ( $self->channel->can_access_product_service_for_email ) {
        # We do not localise the data if we cannot access product service
        return $data;
    }

    my $product_service = XT::Service::Product->new(
        channel => $self->channel
    );

    my $localised_data =  $product_service->localise_product_data_hash( {
        channel => $self->channel,
        language => $self->language,
        data => $data
    } );

    return $localised_data if $localised_data;

    return $data;
}
