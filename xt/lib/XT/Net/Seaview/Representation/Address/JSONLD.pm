package XT::Net::Seaview::Representation::Address::JSONLD;

use NAP::policy "tt", 'class';
extends qw/ XT::Net::Seaview::Representation::Address /;
with qw/ XT::Net::Seaview::Role::Representation::JSONLD
         XT::Net::Seaview::Role::Interface::Representation /;

=head1 NAME

XT::Net::Seaview::Representation::Address::JSONLD

=head1 DESCRIPTION

XT address objects as Seaview-able JSONLD representations

=head1 ATTRIBUTES

=head2 fields

JSON field name mappings. This is the all important XT::Data to Seaview JSON
mapping. If something is in here then it will be part of the Seaview
request. The keys are XT::Data::Address methods and the values are the
corresponding Seaview JSON keys

=cut

my $auto_fields = {
    title         => 'title',
    first_name    => 'firstName',
    last_name     => 'lastName',
    line_1        => 'address1',
    line_2        => 'address2',
    line_3        => 'address3',
    town          => 'townCity',
    county        => 'county',
    postcode      => 'postcode',
    country_code  => 'country',
    state         => 'state',
    account_urn   => 'account',
    address_type  => 'addressType',
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

Create a JSON-LD representation of this address

=cut

sub to_rep {
    my $self = shift;

    my $address = {};

    # Just create a JSON document for the moment
    return JSON->new->utf8->encode($address);
}
