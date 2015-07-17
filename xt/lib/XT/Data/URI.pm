package XT::Data::URI;

use NAP::policy "tt", qw/class overloads/;

use URI;

use overload ('""' => sub { $_[0]->as_string }, fallback => 1);

=head1 NAME

XT::Data::URI

=head1 DESCRIPTION

Wrapper type around URI. Basically here to allow us to add the TO_JSON method

=cut

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    return $class->$orig(_uri => URI->new(@_));
};

=head1 ATTRIBUTES

=head2 _uri

A URI. Delegate everything apart from overloaded methods

=cut

has _uri => (
    is      => "ro",
    isa     => "URI",
    handles => qr/^[^(].*/,
);

=head1 METHODS

=head2 TO_JSON

Stringify for JSON serialisation

=cut

# newer versions of URI have a TO_JSON method, so we can just delegate
# there; if they don't, we'll provide our own
if (not URI->can('TO_JSON')) {
    __PACKAGE__->meta->add_method(
        TO_JSON => sub {
            my ($self) = @_;
            return $self->as_string;
        }
    );
}

