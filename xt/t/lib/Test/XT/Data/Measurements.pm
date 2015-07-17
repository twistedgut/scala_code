package Test::XT::Data::Measurements;

use NAP::policy "tt",     qw( test role );

#
# Data for the testing measurements
#
use XTracker::Config::Local;
use Test::XTracker::Data;
use Test::XTracker::Model;


# hashref keyed on variant id, for variants of $self->product
# values are another hashref of measurement_id => value
has attr__measurements__variant_measurement_values => (
    is          => 'rw',
    isa         => 'HashRef',
    lazy        => 1,
    builder     => '_attr__measurements__set_variant_measurement_values',
);

# arrayref of measurement ids, for $self->product
# default values derived from correct measurements according to db config
has attr__measurements__measurement_types => (
    is          => 'rw',
    isa         => 'ArrayRef',
    lazy        => 1,
    builder     => '_attr__measurements__set_measurement_types',
);

############################
# Attribute default builders
############################

# Create some default measurement values
# Assumes we already have a product
#
sub _attr__measurements__set_variant_measurement_values {
    my ($self) = @_;

    my $product = $self->product;
    return unless ($product);

    my $measurement_values;

    foreach my $variant ($self->product->variants()) {
        foreach my $measurement (@{$self->attr__measurements__measurement_types()}) {
            my $value = int(rand(23))+1;
            $measurement_values->{$variant->id}->{$measurement->id} = $value;
        }
    }

    return $measurement_values;
}

# The relevant measurements for $self->product
#
sub _attr__measurements__set_measurement_types {
    my ($self) = @_;

    my $product = $self->product or return [];

    return [$product->product_type
        ->measurements_for_channels(map {$_->channel_id} $product->product_channel->all)
        ->related_resultset('measurement')
        ->all];
}

# Updates measurement values to something else
# Will break if there aren't any, so if there's no $self->product for example
sub data__measurements__update_variant_measurement_values {
    my ($self) = @_;

    my $measurement_values = $self->attr__measurements__variant_measurement_values;

    foreach my $variant_id (keys %$measurement_values) {
        foreach my $measurement_id (keys %{$measurement_values->{$variant_id}}) {
            $measurement_values->{$variant_id}->{$measurement_id}+=2;
        }
    }

    $self->attr__measurements__variant_measurement_values($measurement_values)
}

1;
