package XT::Net::Seaview::Representation::Account::JSON;

use NAP::policy "tt", 'class';
extends qw/ XT::Net::Seaview::Representation::Account /;
with qw/ XT::Net::Seaview::Role::Representation::JSON
         XT::Net::Seaview::Role::Interface::Representation /;

use XTracker::Utilities qw/as_zulu/;

=head1 NAME

XT::Net::Seaview::Representation::Account::JSON

=head1 DESCRIPTION

Account objects as Seaview-able JSON representations

=head1 DATA ACCESS METHODS

JSON field name mappings. This is the all important XT::Data to Seaview JSON
mapping. If something is in here then it will be part of the Seaview
request. The keys are XT::Data::Customer methods and the values are the
corresponding Seaview JSON keys

=cut

my $auto_fields = { email              => 'email',
                    title              => 'title',
                    first_name         => 'firstName',
                    last_name          => 'lastName',
                    encrypted_password => 'passwordHash',
                    country_code       => 'registeredCountryCode',
                    email_sub          => 'emailSubscription',
                    welcome_pack_sent  => 'welcomePackSent',
                    addresses          => 'addresses',
                    origin_id          => 'originLocalId',
                    origin_region      => 'originRegion',
                    origin_name        => 'originName' ,
                    date_of_birth      => 'dateOfBirth',
                    porter_subscriber  => 'porterSubscriber',
                  };

my $manual_fields = { category => 'category' };

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
        my $urn = undef;
        my $cat = $self->data->{category};
        if(defined $cat){
            $urn = XT::Net::Seaview::Utils->category_urn($cat);
        }
        return $urn;
    },
);

=head1 METHODS

=head2 to_rep

Create a JSON representation of this account suitable for Seaview consumption

=cut

sub to_rep {
    my $self = shift;

    my $account = undef;

    # Add identity if we have one
    if(defined $self->identity){
        $account->{id} = $self->identity;
    }

    # Add all other defined values (apart from addresses)
    map { $account->{$self->serialised_fields->{$_}} = $self->$_ }
        grep { defined $self->$_  }
        grep { $_ ne 'addresses' }
        keys %{$self->serialised_fields};

    # Stringify datetime objects to zulu format
    if(defined $self->date_of_birth){
        $account->{$self->serialised_fields->{date_of_birth}}
          = as_zulu($self->date_of_birth);
    }

    # Convert boolean fields to something Seaview understands
    $account = $self->convert_booleans($account);

    return JSON->new->utf8->convert_blessed->encode($account);
}
