package XTracker::CSV::Importer::LatePostcodes;
use NAP::policy 'class';

=head1 NAME

XTracker::CSV::Importer::LatePostcodes

=head1 DESCRIPTION

CSV Importer for postcodes where we can't deliver to on time (as they are remote locations)

=cut

with 'XTracker::Role::WithSchema';
with 'XTracker::Role::CSV::Importer';

sub get_import_config {
    return {
        target_result_set   => 'Public::ShippingChargeLatePostcode',
        required_columns    => [qw/
            shipping_sku
            country_code
            postcode
        /],
    };
}

has 'country_cache' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);
sub _get_country_from_code {
    my ($self, $country_code) = @_;
    my $country_cache = $self->country_cache();
    if (!exists($country_cache->{$country_code})) {
        my $schema = $self->schema();
        $country_cache->{$country_code} = $schema->resultset('Public::Country')->find({
            code => $country_code
        });
    }
    return $country_cache->{$country_code};
}

has 'shipping_charge_cache' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);
sub _get_shipping_charge_from_sku {
    my ($self, $shipping_sku) = @_;
    my $shipping_charge_cache = $self->shipping_charge_cache();
    if (!exists($shipping_charge_cache->{$shipping_sku})) {
        my $schema = $self->schema();
        $shipping_charge_cache->{$shipping_sku} = $schema->resultset('Public::ShippingCharge')->find({
            sku => $shipping_sku
        });
    }
    return $shipping_charge_cache->{$shipping_sku};
}

sub munge_imported_row_data {
    my ($self, $row_data) = @_;

    my $schema = $self->schema();

    my $country = $self->_get_country_from_code($row_data->{country_code})
        // die sprintf('Could not find a country with code: %s', $row_data->{country_code});

    my $shipping_charge = $self->_get_shipping_charge_from_sku($row_data->{shipping_sku})
        // die sprintf('Could not find a shipping_charge with sku: %s', $row_data->{shipping_sku});

    return {
        postcode            => $row_data->{postcode},
        shipping_charge_id  => $shipping_charge->id(),
        country_id          => $country->id(),
    };
}
