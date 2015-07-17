package NAP::XT::Exception::Internal;
use NAP::policy "tt", "exception";

=head1 NAME

NAP::XT::Exception::Internal

=head1 DESCRIPTION

An Internal error, i.e. a programmer error indicating that something
that never should happen in fact did happen.

=head1 SYNOPSIS

    NAP::XT::Exception::Internal->throw({ message => "Bad thing just happened" });

=cut

sub as_string {
    my $self = shift;
    return "Internal error: " . $self->SUPER::as_string();
}

