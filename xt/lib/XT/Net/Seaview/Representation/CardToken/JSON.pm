package XT::Net::Seaview::Representation::CardToken::JSON;

use NAP::policy "tt", 'class';
extends qw/ XT::Net::Seaview::Representation::CardToken /;
with qw/ XT::Net::Seaview::Role::Representation::JSON
         XT::Net::Seaview::Role::Interface::Representation /;

=head1 NAME

XT::Net::Seaview::Representation::CardToken::JSON

=head1 DESCRIPTION

CardToken objects as Seaview-able JSON representations

=head1 DATA ACCESS METHODS

JSON field name mappings. This is the all important XT::Data to Seaview JSON
mapping. If something is in here then it will be part of the Seaview
request. The keys are XT::Data::Customer methods and the values are the
corresponding Seaview JSON keys

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

=head2 to_rep

Create a JSON representation of this card_token suitable for Seaview consumption

=cut

sub to_rep {
    my $self = shift;

    my %card_token = (
        map { $self->auto_fields->{ $_ } => $self->src->{ $_ } }
              keys %{ $self->auto_fields }
    );

    return JSON->new->utf8->convert_blessed->encode( \%card_token );
}
