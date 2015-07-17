package SOS::Exception::InvalidChannelCode;
use NAP::policy 'exception';

=head1 NAME

SOS::Exception::InvalidChannelCode

=head1 DESCRIPTION

Thrown if a channel code is passed that can not be matched to a known channel

=head1 ATTRIBUTES

=head2 channel_code

Channel code that was passed

=cut
has 'channel_code' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has '+message' => (
    default => q/No channel could be found with the code %{channel_code}s/,
);
