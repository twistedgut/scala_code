package XT::Net::Seaview::Representation::Account::JSONLD;

use NAP::policy "tt", 'class';
extends qw/ XT::Net::Seaview::Representation::Account /;
with qw/ XT::Net::Seaview::Role::Representation::JSONLD
         XT::Net::Seaview::Role::Interface::Representation /;

use XT::Net::Seaview::Utils;

=head1 NAME

XT::Net::Seaview::Representation::Account::JSONLD

=head1 DESCRIPTION

Account objects as Seaview-able JSONLD representations

=head1 DATA ACCESS METHODS

JSON field name mappings. This is the all important XT::Data to Seaview JSON
mapping. If something is in here then it will be part of the Seaview
request. The keys are XT::Data::Customer::Account methods and the values are
the corresponding Seaview JSON keys

=cut

my $auto_fields = { email        => 'email',
                    title        => 'title',
                    first_name   => 'firstName',
                    last_name    => 'lastName',
                    customer_urn => 'customer',
                    client       => 'client',
                    channel      => 'channel',
                    country_code => 'registeredCountryCode',
                    addresses    => 'addresses',
                    welcome_pack_sent  => 'welcomePackSent',
                    origin_id => 'originLocalId',
                    origin_region => 'originRegion' ,
                    origin_name => 'originName' ,
                    date_of_birth => 'dateOfBirth',
                    porter_subscriber => 'porterSubscriber',
                };

my $manual_fields = { category => 'category', };

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

has category => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $urn = $self->data->{category};
        my $cat = undef;
        if(defined $urn){
            $cat = XT::Net::Seaview::Utils->urn_to_category($urn);
        }
        return $cat;
    },
);

=head1 METHODS

=head2 media_type

This representation's media type

=cut

sub media_type {
    return 'application/ld+json';
}

=head2 to_rep

Create a JSON-LD representation of this account

=cut

sub to_rep {
    my $self = shift;

    my $account = {};

    # We currently have no need to produce JSON-LD so just create a JSON
    # document for the moment. This is valid JSON-LD
    return JSON->new->utf8->encode($account);
}
