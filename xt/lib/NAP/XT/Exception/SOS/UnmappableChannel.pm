package NAP::XT::Exception::SOS::UnmappableChannel;
use NAP::policy 'exception';

=head1 NAME

NAP::XT::Exception::SOS::UnmappableChannel

=head1 DESCRIPTION

Thrown when attempting to match a shippable's channel to the equivalent
SOS channel, if no matching channel could be found.

=head1 ATTRIBUTES

=head2 channel

Channel that could not be matched

=cut

has 'channel' => (
    is => 'ro',
    isa => 'XTracker::Schema::Result::Public::Channel',
    required => 1,
);

sub _channel_name {
    my ($self) = @_;
    return $self->channel->name();
}

has '+message' => (
    default => q/Channel with name '%{_channel_name}s' could not be matched to a known SOS channel'/,
);

1;
