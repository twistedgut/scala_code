package NAP::XT::Exception::Message::MismatchingClient;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::Message::MismatchingClient

=head1 DESCRIPTION

Exception thrown if a a 'client' parameter supplied in a message conflicts with the
identified data in XT

=cut

has 'sku' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

has 'supplied_client' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);
has 'actual_client' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

has '+message' => (
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return 'The client associated with sku "'
            . $self->sku()
            . '" in XT is "'
            . $self->actual_client()
            . '" but we were expecting "'
            . $self->supplied_client()
            . '"';
    },
);
