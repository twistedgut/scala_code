package XTracker::Schema::ResultSet::Public::ThirdPartySku;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Carp qw/croak/;

=head1 NAME

XTracker::Schema::ResultSet::ThirdPartySKU - Resultset methods.

=head1 DESCRIPTION

Resultset level methods for the third_party_sku table.

=head1 METHODS

=head2 find_variant_by_sku

    my $variant = $tps_rs->find_variant_by_sku({ sku => 1, business_id => 1 });

Given a [third party] SKU and a business ID, attempts to find the related variant.

=cut

sub find_variant_by_sku {
    my ( $self, $args ) = @_;

    croak 'SKU required' unless $args->{sku};
    croak 'Business ID required' unless $args->{business_id};

    my $sku = $self->search({
        third_party_sku => $args->{sku},
        business_id     => $args->{business_id},
    })->first;

    return $sku->variant if $sku;

    return;
}

=head2 find_by_sku_and_business({ $sku, $business_id }) : $third_party_sku_row | undef

Return the first $third_party_sku_row for the $sku and
$business_id, or undef if none was found.

=cut

sub find_by_sku_and_business {
    my ($self, $args) = @_;

    my ($product_id, $size_id) = $self->product_size_from_sku( $args->{sku} );
    return $self->search(
        {
            "variant.size_id"    => $size_id,
            "variant.product_id" => $product_id,
            "business_id"        => $args->{business_id},
        },
        { join => "variant" },
    )->first;
}

sub product_size_from_sku {
    my ($self, $sku) = @_;
    return $self->result_source->schema
        ->resultset("Public::Variant")->product_size_from_sku($sku);
}

=head1 SEE ALSO

L<XTracker::Schema::Result::Public::ThirdPartySku>

=head1 AUTHOR

Adam Taylor <adam.taylor@net-a-porter.com>

=cut

1;
