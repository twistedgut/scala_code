package Test::XT::Script::Seaview::GenResponses;

use NAP::policy "tt", 'class';
with qw/MooseX::Getopt MooseX::Runnable/;

BEGIN {
    use Test::XTracker::Data;
}

use XT::Net::Seaview::Client;
use XTracker::Config::Local qw/config_var/;

use Data::Printer;
use Path::Class qw/file dir/;
use JSON;

=head1 NAME

Test::XT::Script::Seaview::GenResponses

=head1 DESCRIPTION

Generate canned responses from a running version of the Seaview service to be
saved as static files and used in future unit tests. The responses should be
regenerated when the service version we are integrating with changes

=cut

around 'BUILDARGS' => sub {
    my $orig = shift;
    my $class = shift;

    if( config_var("Seaview", "useragent_class")
          eq 'XT::Net::Seaview::TestUserAgent'){
        die   '[No Seaview Service] Test response generation requires '
            . 'a real user agent and a running Seaview service';
    }

    return $class->$orig(@_);
};

=head1 ATTRIBUTES

=head2 account_urn

A Seaview account

=cut

has 'account_urn' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy     => 1,
    builder  => '_build_account_urn',
);

sub _build_account_urn {
    my $self = shift;

    # Create a Seaview account with two addresses
    my $account_data_obj
      = XT::Data::Customer::Account->new(
          { email              => 'cv-test-' . int(rand(1000)) . '@net-a-porter.com',
            encrypted_password => 'my secret password',
            title              => 'Miss',
            first_name         => 'Test First Name ' . int(rand(1000)),
            last_name          => 'Test Last Name ' . int(rand(1000)),
            country_code       => 'GB',
          });

    # Add account to Seaview
    my $account_urn = $self->seaview->add_account($account_data_obj);

    # Add address to account
    my $addr_data_obj
      = XT::Data::Address->new(
          { schema       => $self->schema,
            address_type => 'Shipping',
            first_name   => 'Test First Name ' . int(rand(1000)),
            last_name    => 'Test Last Name ' . int(rand(1000)),
            line_1       => 'Test Line 1',
            line_2       => 'Test Line 2',
            line_3       => 'Test Line 3',
            town         => 'Testville',
            postcode     => 'T5T 101',
            country_code => 'GB',
            account_urn  => $account_urn,
          });

    $self->{address_urn} = $self->{seaview}->add_address($addr_data_obj);

    return $account_urn;
}

=head2 schema

An XT schema

=cut

has schema => (
    is => 'ro',
    lazy => 1,
    default => sub { Test::XTracker::Data->get_schema },
);

=head2 seaview

A Seaview client

=cut

has seaview => (
    is => 'ro',
    lazy => 1,
    builder => '_build_seaview',
);

sub _build_seaview {
    return XT::Net::Seaview::Client->new(
             { schema => $_[0]->schema,
               useragent_class => config_var("Seaview", "useragent_class")});
}

=head2 response_dir

=cut

has 'response_dir' => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    required => 1,
    builder  => '_build_response_dir',
);

sub _build_response_dir {
    return dir(config_var("SystemPaths", "xt_base_dir"),
               't', 'data', 'seaview');
}

=head1 METHODS

=head2 run

The output of this script is a set of static JSON files that mirror Seaview
service responses

=cut

sub run {
    my $self = shift;

    # Generate json docs
    $self->gen_customer_json;
    $self->gen_account_json;
    $self->gen_address_json;

    return 1;
}

=head2 gen_customer_json

Generate template JSON-LD response for Seaview Customer;

=cut

sub gen_customer_json {
    my $self = shift;

    # Find customer
    my $customer_urn
      = $self->seaview->discover_customer_urn($self->account_urn);

    # Load Seaview customer
    $self->seaview->customer($customer_urn);

    my $customer
      = JSON->new->utf8->decode(
          $self->seaview->customers->cache->{$customer_urn}->src);

    # Create JSON string
    my $customer_json = $self->create_json($customer);

    # Create files from munged responses
    my $fh = file($self->response_dir, 'customer.json')->open('>');

    # Write files to test data directory
    print $fh $customer_json;
    $fh->close;

    return 1;
}

=head2 gen_account_json

Generate template JSON-LD response for Seaview Account;

=cut

sub gen_account_json {
    my $self = shift;

    # Load up Seaview account
    $self->seaview->account($self->account_urn);

    my $account
      = JSON->new->utf8->decode(
          $self->seaview->accounts->cache->{$self->account_urn}->src);

    # Create JSON string
    my $account_json = $self->create_json($account);

    # Create files from munged responses
    my $fh = file($self->response_dir, 'account.json')->open('>');

    # Write files to test data directory
    print $fh $account_json;
    $fh->close;

    return 1;
}

=head2 gen_address_json

Generate template JSON-LD response for Seaview Address;

=cut

sub gen_address_json {
    my $self = shift;

    # Load up Seaview account
    $self->seaview->accounts->by_uri($self->account_urn);
    my $address_urn = (keys $self->seaview->all_addresses($self->account_urn))[0];

    my $address
      = JSON->new->utf8->decode(
          $self->seaview->addresses->cache->{$address_urn}->src);

    # Create JSON string
    my $address_json = $self->create_json($address);

    # Add in template placeholders
    my $addr_id_value = qr/("\@id"\s*:\s*)"urn:nap:address:[a-z0-9]+"/xms;
    $address_json =~ s/$addr_id_value/$1"[% address_urn %]"/;

    # Create files from munged responses
    my $fh = file($self->response_dir, 'address.json')->open('>');

    # Write files to test data directory
    print $fh $address_json;
    $fh->close;

    return 1;
}


=head2 create_json

=cut

sub create_json {
    my ($self, $data) = @_;

    return JSON->new->utf8->pretty->encode($data);
}
