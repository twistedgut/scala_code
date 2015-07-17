package XT::Net::Seaview::Role::Representation::Text;
use NAP::policy "tt", 'role';

requires 'src';

=head1 NAME

XT::Net::Seaview::Role::Representation::Text

=head1 DESCRIPTION

Text Representation.

=head1 ATTRIBUTES

=head2 identity

Resource identity for Text representations is the contents of the data.

=cut

sub _build_identity {
    return shift->data;
}

=head2 media_type

This representation's media type

=cut

sub media_type {
    return 'text/plain';
}

=head2 data

Build a HashRef of Text data from a source.

=cut

has data => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_data',
);

sub _build_data {
    my $self = shift;

    return { value => $self->src };

}
