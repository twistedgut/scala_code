package NAP::XT::Exception::Recode::NotEnoughTransitStock;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::Recode::NotEnoughTransitStock

=head1 DESCRIPTION

Thrown if when recoding a variant, there is not as much stock in transit for one or more
variants as was requested to destroy

=head1 ATTRIBUTES

=head2 bad_variants

A hashref of variant's that do not have enough stock to be recoded, where:
    key = variant sku
    value = amount of stock available

=cut

has 'bad_variants' => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

sub _bad_variant_string {
    my ($self) = @_;
    my $bad_variants = $self->bad_variants;
    return join(', ', map { "$_ ($bad_variants->{$_})" } keys %$bad_variants);
}

has '+message' => (
    default => 'Not enough stock to recode for the following variants: %{_bad_variant_string}s',
);

1;
