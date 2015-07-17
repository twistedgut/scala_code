package XTracker::Document::Role::CopiesInContent;

use NAP::policy 'role';

=head1 NAME

XTracker::Document::Role::CopiesInContent - Pass copies to print_at_location for documents with copies in their content

=head1 DESCRIPTION

There are cases when the number of copies is not passed to 'C<lp>' but is in
the document's content. In order to have a consistent interface for printing,
this role allows us to pass the number of copies to
L<XTracker::Document::print_at_location>, the same way we would do for regular
documents.

It does this by providing a C<copies> attribute that is accessible to the
class to set the numbe of copies to be printed in the content when
L<print_at_location> is called.

=head1 ATTRIBUTES

=head2 copies

Use this attribute in your consuming class to set the number of copies you want
to print in your content.

=cut

has copies => (
    is       => 'rw',
    isa      => 'Int',
    init_arg => undef,
    clearer  => 'clear_copies',
);

requires 'print_at_location';

around print_at_location => sub {
    my $orig = shift;
    my $self = shift;
    my ( $filename, $copies ) = @_;

    $self->copies($copies//1);
    my $return = $self->$orig($filename,1);
    $self->clear_copies;
    return $return;
};
