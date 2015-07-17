package SOS::Exception::MissingNomDayComponent;
use NAP::policy "tt", 'exception';

=head1 NAME

SOS::Exception::MissingNomDayComponent

=head1 DESCRIPTION

Thrown if there are missing parts to the nominated date

=head1 ATTRIBUTES

=head2 missing_fields

An arrayref of missing fields

=cut
has 'missing_fields' => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    required => 1,
);

sub _missing_fields_string {
    my ($self) = @_;
    return join ', ', @{$self->missing_fields()};
}

has '+message' => (
    default => q/The following fields were not present for the nominated day date:
        %{_missing_fields_string}s/,
);
