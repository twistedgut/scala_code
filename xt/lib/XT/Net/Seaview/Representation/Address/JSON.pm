package XT::Net::Seaview::Representation::Address::JSON;

use NAP::policy "tt", 'class';
extends qw/ XT::Net::Seaview::Representation::Address /;
with qw/ XT::Net::Seaview::Role::Representation::JSON
         XT::Net::Seaview::Role::Interface::Representation /;

=head1 NAME

XT::Net::Seaview::Representation::Address::JSON

=head1 DESCRIPTION

XT address objects as Seaview-able JSON representations

=head1 DATA ACCESS METHODS

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
    account_urn   => 'accountURN',
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

Create a JSON representation of this address suitable for Seaview consumption

=cut

sub to_rep {
    my $self = shift;

    my $address = undef;

    # Add identity if we have one
    if(defined $self->identity){
        $address->{id} = $self->identity;
    }

    # Add all other defined values
    map { $address->{$auto_fields->{$_}} = $self->$_ }
        grep { defined $self->$_  }
        keys %$auto_fields;

    return JSON->new->utf8->convert_blessed->encode($address);
}
