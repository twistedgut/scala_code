package XT::Net::Seaview::Client;

use NAP::policy "tt", 'class';

with qw/XT::Net::Role::UserAgent/;

use MooseX::SemiAffordanceAccessor;
use DateTime::Format::HTTP;

use XTracker::Logfile qw(xt_logger);
use XTracker::Config::Local qw(config_var);

use XT::Net::Seaview::Service;
use XT::Net::Seaview::Resource::Customer;
use XT::Net::Seaview::Resource::Account;
use XT::Net::Seaview::Resource::Address;
use XT::Net::Seaview::Resource::CardToken;
use XT::Net::Seaview::Resource::BOSH;

use XT::Net::Seaview::Exception::ParameterError;
use XT::Net::Seaview::Exception::NetworkError;

=head1 NAME

XT::Net::Seaview::Client

=head1 DESCRIPTION

Service interface class for the 'Seaview' customer service providing access to
customer and related resources.

=cut

sub BUILD {
    my $self = shift;

    if($self->ssl){
        # Ensure UserAgent is secure and add client certificate
        # If not refuse to do anything

        $self->enable_ssl({ client_cert => 1 });

        unless($self->is_ssl_enabled){
            $self->logger->warn('User agent SSL not enabled - Seaview will not work');
            # XT::Net::Seaview::Exception::NetworkError->throw(
            #     { error => 'Seaview client must use SSL' });
        }
    }
}

=head1 ATTRIBUTES

=head2 useragent_class

=cut

has +useragent_class => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        config_var("Seaview", "useragent_class") || "LWP::UserAgent",
    },
);

=head2 ssl

=cut

has ssl => (
    is      => 'ro',
    lazy    => 1,
    default => sub { config_var("Seaview", "ssl") || 1 },
);

=head2 service

Seaview service instance

=cut

has service => (
    is      => 'ro',
    isa     => 'XT::Net::Seaview::Service',
    default => sub { XT::Net::Seaview::Service->new() },
);

=head2 retry_limit

Maximum times we should retry a service call

=cut

has retry_limit  => (
    is       => "ro",
    lazy     => 1,
    required => 1,
    default  => sub { config_var("Seaview", "retry_limit") || 3 },
);

=head2 address_updates

Should we pass on address updates to Seaview? This is a feature switch to
ensure we don't allow address changes whilst they are unsafe

=cut

has address_updates  => (
    is       => "ro",
    lazy     => 1,
    required => 1,
    default  => sub { config_var("Seaview", "address_updates") || 0 },
);

=head2 logger

Logging object

=cut

has logger => (
    is  => 'ro',
    isa => 'Log::Log4perl::Logger',
    default => sub { return xt_logger(); }
);

=head2 schema

XT Schema

=cut

has schema => (
    is       => 'ro',
    isa      => 'XTracker::Schema|XT::DC::Messaging::Model::Schema',
    required => 1,
);

=head2 customer

Customer interactions

=cut

has customers => (
    is       => 'ro',
    isa      => 'XT::Net::Seaview::Resource::Customer',
    init_arg => undef,
    lazy     => 1,
    default  => sub { XT::Net::Seaview::Resource::Customer->new(
                        { schema    => $_[0]->schema,
                          useragent => $_[0]->useragent,
                          service   => $_[0]->service })},
);

=head2 addresses

Address interactions

=cut

has addresses => (
    is       => 'ro',
    isa      => 'XT::Net::Seaview::Resource::Address',
    init_arg => undef,
    lazy     => 1,
    default  => sub { XT::Net::Seaview::Resource::Address->new(
                        { schema    => $_[0]->schema,
                          useragent => $_[0]->useragent,
                          service   => $_[0]->service })},
);

=head2 accounts

Account interactions

=cut

has accounts => (
    is       => 'ro',
    isa      => 'XT::Net::Seaview::Resource::Account',
    init_arg => undef,
    lazy     => 1,
    default  => sub { XT::Net::Seaview::Resource::Account->new(
                        { schema    => $_[0]->schema,
                          useragent => $_[0]->useragent,
                          service   => $_[0]->service })},
);

=head2 account_card_tokens

Account card token interactions.

=cut

has account_card_tokens => (
    is       => 'ro',
    isa      => 'XT::Net::Seaview::Resource::CardToken',
    init_arg => undef,
    lazy     => 1,
    default  => sub { XT::Net::Seaview::Resource::CardToken->new(
                        { schema    => $_[0]->schema,
                          useragent => $_[0]->useragent,
                          service   => $_[0]->service })},
);


=head2 bosh_store

=cut

has bosh_store => (
    is       => 'ro',
    isa      => 'XT::Net::Seaview::Resource::BOSH',
    init_arg => undef,
    lazy     => 1,
    default  => sub { XT::Net::Seaview::Resource::BOSH->new(
                        { schema    => $_[0]->schema,
                          useragent => $_[0]->useragent,
                          service   => $_[0]->service })
                   },
);

=head1 METHODS

=head2 account

Returns the account identified by parameter as an XT::Data::Customer::Account
object

=cut

sub account {
    my ($self, $account_uri) = @_;

    my $account = undef;
    try {
        $account = $self->accounts->by_uri($account_uri);
        if(defined $account){
            $self->update_local_account($account);
        }
    }
    catch {
        $self->logger->error("[Failed] GET $account_uri: $_");
    };

    return defined $account ? $account : () ;
}

=head2 account_meta

Returns metadata for the account identified by parameter. Currently as an
HTTP::Headers object

=cut

sub account_meta {
    my ($self, $account_urn) = @_;

    return $self->accounts->meta_by_uri($account_urn);
}

=head2 address

Returns the address identified by parameter as an XT::Data::Customer::Address
object

=cut

sub address {
    my ($self, $address_urn) = @_;

    return $self->addresses->by_uri($address_urn);
}

=head2 address_meta

Returns metadata for the address identified by parameter. Currently as an
HTTP::Headers object

=cut

sub address_meta {
    my ($self, $address_urn) = @_;

    return $self->addresses->meta_by_uri($address_urn);
}

=head2 customer

Returns the customer identified by parameter as an XT::Data::Customer object

=cut

sub customer {
    my ($self, $customer_urn) = @_;

    return $self->customers->by_uri($customer_urn);
}

=head2 customer_meta

Returns metadata for the customer identified by parameter. Currently as an
HTTP::Headers object

=cut

sub customer_meta {
    my ($self, $customer_urn) = @_;

    return $self->customers->meta_by_uri($customer_urn);
}

=head2 registered_account

Check the local XT database to see if we have an account urn for this customer

=cut

sub registered_account {
    my ($self, $local_id) = @_;

    return $self->schema
                ->resultset('Public::Customer')
                ->find( { id => $local_id } )
                ->account_urn;
}

=head2 registered_address

Check the local XT database to see if we have a urn for this address

=cut

sub registered_address {
    my ($self, $local_id) = @_;

    my $urn = undef;

    my $address = $self->schema
                       ->resultset('Public::OrderAddress')
                       ->find( { id => $local_id } );

    if(defined $address){
        $urn = $address->urn;
    }

    return $urn;
}

=head2 link_customer

Tie an XT customer to a Seaview account by adding a Seaview
account urn to the customer record in the XT database

=cut

sub link_customer {
    my ($self, $local_id, $urn) = @_;

    my $customer = $self->schema
                        ->resultset('Public::Customer')
                        ->find( { id => $local_id } );

    if(defined $customer){
        $customer->account_urn($urn);
        $customer->update;
    }

    return 1;
}

=head2 find_customer

Fetch and store a customer based on either a customer URN or an account URN

=cut

sub find_customer {
    my ($self, $urn) = @_;

    XT::Net::Seaview::Exception::ParameterError->throw(
      { error => 'URN not supplied' }) unless defined $urn;

    # Determine customer URN from whatever we've been given
    my $customer_urn = $self->discover_customer_urn($urn);

    # Fetch customer and store representation
    my $customer = $self->customer($customer_urn);

    return $customer_urn;
}

=head2 all_addresses

A list of all addresses for a particular customer

=cut

sub all_addresses {
    my ($self, $urn) = @_;

    # Determine customer URN from whatever we've been given
    my $customer_urn = $self->discover_customer_urn($urn);

    # Accounts list
    my $accounts = $self->customer($customer_urn)->accounts;

    # All addresses in the accounts list
    my %addr = ();
    foreach my $account_urn (@$accounts){
        if(defined $self->account($account_urn)->addresses
             && @{$self->account($account_urn)->addresses} > 0){
            foreach my $address_urn (@{$self->account($account_urn)->addresses}){
                $addr{$address_urn} = $self->address($address_urn);
            }
        }
    }

    return \%addr;
}

=head2 clear_caches

Clear all caches

=cut

sub clear_caches {
    my $self = shift;

    # Fetch customer and store representation
    $self->customers->clear_cache;
    $self->accounts->clear_cache;
    $self->addresses->clear_cache;

    return 1;
}

=head2 add_address

Create an address

=cut

sub add_address {
    my ($self, $address) = @_;

    my $address_urn = undef;

    if($self->address_updates){
        $address_urn = $self->addresses->create($address);

        if(defined $address->account_urn){
            delete $self->accounts->cache->{$address->account_urn};
        }
    }

    return $address_urn;
}

=head2 update_address

Update an address

=cut

sub update_address {
    my ($self, $urn, $address) = @_;

    my $address_urn = undef;

    if($self->address_updates){
        $address_urn = $self->addresses->update($urn, $address);
        delete $self->addresses->cache->{$address_urn};
    }

    return $address_urn;
}

=head2 add_account

Register a customer

=cut

sub add_account {
    my ($self, $account) = @_;

    my $account_urn = $self->accounts->create($account);
    my $customer_urn = $self->discover_customer_urn($account_urn);

    delete $self->customers->cache->{$customer_urn};

    return $account_urn;
}

=head2 update_account

Update an account

=cut

sub update_account {
    my ($self, $urn, $data_obj) = @_;

    $urn = $self->accounts->update($urn, $data_obj);
    delete $self->accounts->cache->{$urn};

    return 1;
}

=head2 discover_customer_urn

Access and address via it's URN identifer

=cut

sub discover_customer_urn {
    my ($self, $urn) = @_;
    my $customer_urn = undef;

    # Discover customer URN (from either account or customer)
    if( $urn =~ /^urn:nap:account:/ ){
        # get customer based on account url
        my $account_rep = $self->accounts->fetch($urn);
        $customer_urn = $account_rep->customer_urn;
    }
    else{
        $customer_urn = $urn;
    }

    return $customer_urn;
}

=head1 update_welcome_pack_flag

Set the welcome pack flag on the remote resource

=cut

sub update_welcome_pack_flag {
    my ($self, $account_urn, $new_state, $attempts) = @_;

    my $updated = 0;

    # Update the flag on the remote resource
    try{
        # Create a data object to transfer
        my $data_obj = $self->account($account_urn);

        # Update the data
        $data_obj->welcome_pack_sent($new_state);

        # Transfer the update to Seaview.
        $self->update_account($account_urn, $data_obj);
        $updated = 1;
    }
    catch {
        SMARTMATCH:
        use experimental 'smartmatch';
        if ($_ ~~ match_instance_of('XT::Net::Seaview::Exception::ClientError') and $_->code == 412) {
            # Precondition failed - the request has been rejected
            # Refetch the remote resource and retry the update.
            if($attempts <= $self->retry_limit){
                $self->clear_caches;
                $updated = $self->update_welcome_pack_flag($account_urn,
                                                           $new_state,
                                                           $attempts++);
            }
            else{
                XT::Net::Seaview::Exception::ResourceError->throw(
                    {error => 'Hit Seaview maximium retry limit. Update failed'});
            }
        }
        else {
            # Something else has happened. Who can say what?
            $self->logger->warn($_);
        }
    };

    return $updated;
}

=head1 update_porter_subscriber_flag

Set the 'Porter Subscriber' flag on the remote resource

=cut

sub update_porter_subscriber_flag {
    my ($self, $account_urn, $new_state, $attempts) = @_;

    my $updated = 0;

    # Update the flag on the remote resource
    try{
        # Create a data object to transfer
        my $data_obj = $self->account($account_urn);

        # Update the data
        $data_obj->porter_subscriber($new_state);

        # Transfer the update to Seaview.
        $self->update_account($account_urn, $data_obj);
        $updated = 1;
    }
    catch {
        SMARTMATCH:
        use experimental 'smartmatch';
        if ($_ ~~ match_instance_of('XT::Net::Seaview::Exception::ClientError') and $_->code == 412) {
            # Precondition failed - the request has been rejected
            # Refetch the remote resource and retry the update.
            if($attempts <= $self->retry_limit){
                $self->clear_caches;
                $updated = $self->update_porter_subscriber_flag($account_urn,
                                                                $new_state,
                                                                $attempts++);
            }
            else{
                XT::Net::Seaview::Exception::ResourceError->throw(
                    {error => 'Hit Seaview maximium retry limit. Update failed'});
            }
        }
        else {
            # Something else has happened. Who can say what?
            $self->logger->warn($_);
        }
    };

    return $updated;
}

=head2 get_card_token

Get the card token (returned as a string) attached to an account.

    my $seaview = XT::Net::Seaview::Client->new( {
        schema => $schema,
    } );

    my $card_token = $seaview->get_card_token( $account_urn );

=cut

sub get_card_token {
    my ( $self, $account_urn ) = @_;

    if ( $account_urn =~ /urn:nap:account:([^:]+)/ ) {
    # If it looks like an account urn.

        my $id = $1;

        if ( defined $id && $id ne '' ) {
        # .. and we at least have something to use as an ID.

            # Get the card token by constructing the URN from the
            # account urn plus 'cardToken'.
            return $self
                ->account_card_tokens
                ->fetch( "urn:nap:account:cardToken:$id" );

        }

    }

    return;

}

=head2 update_local_account

=cut

sub update_local_account {
    my ($self, $account) = @_;

    my $retval = undef;

    try {
        # Update local database with Seaview account details
        my $differences = $account->compare_with_storage;

        $account->update_local_storage({ fields => $differences });

        $retval = 1;
    }
    catch {
        # Failed - just log it
        $self->logger->warn("[Account Update Failed] $_");
    };

    return defined $retval ? $retval : ();
}

=head2 replace_card_token

=cut

sub replace_card_token {
    my ( $self, $account_urn, $card_token ) = @_;

    return unless
        defined $card_token && $card_token ne '';

    if ( $account_urn =~ /urn:nap:account:([^:]+)/ ) {

        my $id = $1;

        if ( defined $id && $id ne '' ) {
        # .. and we at least have something to use as an ID.

            # Get the card token by constructing the URN from the
            # account urn plus 'cardToken'.
            return $self
                ->account_card_tokens
                ->replace( "urn:nap:account:cardToken:$id", $card_token );

        }
    }
}

=head2 replace_bosh_value_for_account( $account_urn, $key, $value )

Given an C<$account_urn>, update the BOSH C<$key> to C<$value>.

    my $seaview = XT::Net::Seaview::Client->new( ... );

    $seaview->replace_bosh_value_for_account(
        'urn:nap:account:257f21a2-34c4-11e3-9f14-b4b52f51d098',
        'key_name' => 'key value' );

=cut

sub replace_bosh_value_for_account {
    my ( $self, $account_urn, $key, $value ) = @_;

    XT::Net::Seaview::Exception::ParameterError->throw(
        { error => 'URN not supplied' } )
            unless $account_urn;

    XT::Net::Seaview::Exception::ParameterError->throw(
        { error => 'Key not supplied' } )
            unless $key;

    if ( $account_urn =~ /\Aurn:nap:account:(?<guid>.*)\Z/ ) {

        return $self->bosh_store->replace(
            'urn:nap:account:' . $+{guid} . ':bosh:' . $key,
            ( $value // '' ) );

    } else {

        $self->logger->warn("[replace_bosh_value_for_account] Not an account URN: $account_urn");

    }

    return;

}

=head2 get_bosh_value_for_account( $account_urn, $key )

Given an C<$account_urn>, get the BOSH value for C<$key>.

    my $seaview = XT::Net::Seaview::Client->new( ... );

    my $value = $seaview->get_bosh_value_for_account(
        'urn:nap:account:257f21a2-34c4-11e3-9f14-b4b52f51d098',
        'key_name' );

=cut

sub get_bosh_value_for_account {
    my ( $self, $account_urn, $key ) = @_;

    XT::Net::Seaview::Exception::ParameterError->throw(
        { error => 'URN not supplied' } )
            unless $account_urn;

    XT::Net::Seaview::Exception::ParameterError->throw(
        { error => 'Key not supplied' } )
            unless $key;

    if ( $account_urn =~ /\Aurn:nap:account:(?<guid>.*)\Z/ ) {

        return $self->bosh_store->fetch(
            'urn:nap:account:' . $+{guid} . ':bosh:' . $key );

    } else {

        $self->logger->warn("[get_bosh_value_for_account] Not an account URN: $account_urn");

    }

    return;

}

