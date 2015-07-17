package XT::Net::Seaview::Representation::Error::JSONLD;

use NAP::policy "tt", 'class';
extends qw/ XT::Net::Seaview::Representation /;
with qw/ XT::Net::Seaview::Role::Representation::JSONLD
         XT::Net::Seaview::Role::Interface::Representation /;

=head1 NAME

XT::Net::Seaview::Representation::Error::JSONLD

=head1 DESCRIPTION

Seaview error responses as JSONLD representations

=head1 ATTRIBUTES

=head2 fields

=cut

my $auto_fields = {
    code      => 'code',
    error_msg => 'message',
};

my $manual_fields = {};

with 'XT::Net::Seaview::Role::GenAttrs' => { fields => $auto_fields };

=head1 ATTRIBUTES

=cut

has 'auto_fields' => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    default => sub { $auto_fields },
);

has 'manual_fields' => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    default => sub { $manual_fields },
);

=head1 METHODS

=head2 to_rep

Create a JSON-LD representation of this error

=cut

sub to_rep {
    my $self = shift;

    my $error = {};

    # We currently have no need to produce JSON-LD so just create a JSON
    # document for the moment. This is valid JSON-LD
    return JSON->new->utf8->encode($error);
}
