package XT::Business::Logic::JC::Fulfilment;

use Moose;
use Readonly;
use XTracker::Constants::FromDB qw/ :currency /;

extends 'XT::Business::Base';

use XTracker::Constants::FromDB qw/ :business /;
use Carp qw/ croak /;

=head1 NAME

XT::Business::Logic::JC::Fulfilment - business specific logic for order
fulfilment

=head1 get_real_sku

Given a variant object return the real sku

=cut

sub get_real_sku {
    my($self,$variant) = @_;

    return $variant->third_party_sku->third_party_sku if ($variant && $variant->third_party_sku);

    return $variant->sku;
}

=head1 get_xt_sku

    Given a third party SKU return related internal sku.

=cut

sub get_xt_sku {
    my ( $self, $schema, $third_party_sku ) = @_;

    croak 'Third Party Sku not Passed' unless $third_party_sku;

    if ( ref( $schema ) !~ m/Schema/ ) {
        croak 'No Schema object passed in to get_xt_sku';
    }

    my $xt_sku = $schema->resultset('Public::ThirdPartySku')->find_variant_by_sku({
        sku         => $third_party_sku,
        business_id => $BUSINESS__JC,
    });

    return $xt_sku->sku if $xt_sku;
    return;


}

1;
