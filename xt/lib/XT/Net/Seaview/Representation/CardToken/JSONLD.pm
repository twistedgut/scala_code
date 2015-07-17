package XT::Net::Seaview::Representation::CardToken::JSONLD;

use NAP::policy "tt", 'class';
extends qw/ XT::Net::Seaview::Representation::CardToken /;
with qw/ XT::Net::Seaview::Role::Representation::JSONLD
         XT::Net::Seaview::Role::Interface::Representation /;

=head1 NAME

XT::Net::Seaview::Representation::CardToken::JSONLD

=head1 DESCRIPTION

CardToken objects as Seaview-able JSONLD representations

=head1 DATA ACCESS METHODS

JSON field name mappings. This is the all important XT::Data to Seaview JSON
mapping. If something is in here then it will be part of the Seaview
request. The keys are XT::Data::Customer::CardToken methods and the values are
the corresponding Seaview JSON keys

=cut

my $auto_fields   = { card_token => 'cardToken' };
my $manual_fields = { };

with 'XT::Net::Seaview::Role::GenAttrs' => { fields => $auto_fields };

=head1 ATTRIBUTES

=cut

has 'auto_fields' => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { $auto_fields },
);

has 'manual_fields' => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { $manual_fields },
);

=head1 METHODS

=head2 media_type

This representation's media type

=cut

sub media_type {
    return 'application/ld+json';
}

=head2 to_rep

Create a JSON-LD representation of this card_token

This is currently just a stub method, as it's not used.

=cut

sub to_rep {
    my $self = shift;

    my $card_token = {};

    # We currently have no need to produce JSON-LD so just create a JSON
    # document for the moment. This is valid JSON-LD
    return JSON->new->utf8->encode( $card_token );
}
