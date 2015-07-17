package NAP::XT::Exception::Recode::ThirdPartySkuRequired;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::Recode::ThirdPartySkuRequired

=head1 DESCRIPTION

Thrown when attempting a recode with a variant on a "fulfilment_only" channel' and no
 third-party-sku

=head1 ATTRIBUTES

=head2 variant

Variant that does not match expected channel

=cut
has 'variant' => (
    is => 'ro',
    isa => 'XTracker::Schema::Result::Public::Variant',
    required => 1,
);

sub sku {
    my ($self) = @_;
    return $self->variant->sku();
}

has '+message' => (
    default => 'SKU %{sku}s requires a third-party-sku for recode',
);

1;
