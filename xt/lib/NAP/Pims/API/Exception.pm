package NAP::Pims::API::Exception;
use NAP::policy qw/class exception/;

=head1 NAME

NAP::Pims::API::Exception

=head1 DESCRIPTION

Exception thrown if there is a problem when calling the PIMS API

=head1 ATTRIBUTES

=head2 status_code

The HTTP status code returned from the call to PIMS

=cut
has status_code => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
);

=head2 description

A textual description of what has goen wrong

=cut
has description => (
  is      => 'ro',
  isa     => 'Str',
  default => 'An unknown error occured',
);

has '+message' => (
    default => q/The call to Pims failed with status-code: %{status_code}s with this description: %{description}s/,
);