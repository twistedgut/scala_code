package NAP::XT::Exception::Recode::FromChannelMismatch;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::Recode::FromChannelMismatch

=head1 DESCRIPTION

Thrown if when recoding from multiple variants, they are not all on the same current
channel

=head1 ATTRIBUTES

=head2 expected_channel

Channel that variant was expected to be on

=cut

has 'expected_channel' => (
    is => 'ro',
    isa => 'XTracker::Schema::Result::Public::Channel',
    required => 1,
);

sub _channel_name {
    my ($self) = @_;
    return $self->expected_channel->name();
}

=head2 variant

Variant that does not match expected channel

=cut
has 'variant' => (
    is => 'ro',
    isa => 'XTracker::Schema::Result::Public::Variant',
    required => 1,
);

sub _sku {
    my ($self) = @_;
    return $self->variant->sku();
}

has '+message' => (
    default => q/SKU %{_sku}s can not be recoded as it is not on the expected channel: '%{_channel_name}s'/,
);

1;
