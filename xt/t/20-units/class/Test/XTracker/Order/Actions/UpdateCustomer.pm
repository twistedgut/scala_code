package Test::XTracker::Order::Actions::UpdateCustomer;

use NAP::policy "tt", 'test', 'class';

use Test::XTracker::Data;
use Test::XTracker::Mock::Handler;
use XT::Net::Seaview::Client;
use XT::Net::Seaview::Utils;

use XTracker::Order::Actions::UpdateCustomer;

BEGIN {
    extends "NAP::Test::Class";
};

sub init : Test(startup) {
    my $self = shift;
    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{dbh} = $self->{schema}->storage->dbh;
    $self->{seaview} = XT::Net::Seaview::Client->new({schema => $self->{schema}});

    if(ref $self->{seaview}->useragent
         eq 'XT::Net::Seaview::TestUserAgent'){
        $self->{test_ua} = 1;
    }

    $self->{customer}
      = Test::XTracker::Data->find_or_create_customer(
          {channel_id => Test::XTracker::Data->channel_for_nap->id});

    # Create a Seaview Account
    $self->{account}
      = XT::Data::Customer::Account->new(
          { email              => 'cv-test-' . int(rand(1000)) . '@net-a-porter.com',
            encrypted_password => 'my new password',
            title              => 'Miss',
            first_name         => 'Test First Name ' . int(rand(1000)),
            last_name          => 'Test Last Name ' . int(rand(1000)),
            country_code       => 'GB',
            origin_id          => 666, # Magic client id - unvalidated
            origin_region      => 'DC1',
            origin_name        => 'XT',
            date_of_birth      => DateTime->now(),
            schema             => $self->{schema},
            category           => 'EIP',
        });

    # Add account to Seaview
    $self->{account_urn} = $self->{seaview}->add_account($self->{account});

    # Add global id to XT customer record
    $self->{seaview}->link_customer($self->{customer}->id,
                                    $self->{account_urn});

    # Pull out a random category
    @{$self->{categories}}
      = $self->{schema}->resultset('Public::CustomerCategory')->search;

    $self->{category} = $self->{categories}->[rand @{$self->{categories}}];
    $self->{category_urn} = XT::Net::Seaview::Utils->category_urn($self->{category}->category);

    note 'Customer ID is: ' . $self->{customer}->id;
    note 'Account URN is: ' . $self->{account_urn};
    note 'Category is: ' . $self->{category}->category;
    note 'Category URN is: ' . $self->{category_urn};
}

sub test_update_local_customer_category : Test() {
    my $self = shift;

    my $mock_handler
      = Test::XTracker::Mock::Handler->new({ param_of => {} });

    # Make the update
    XTracker::Order::Actions::UpdateCustomer::update_local_customer_category(
        $mock_handler, $self->{customer}->id, $self->{category}->id
    );

    # Check the local database
    my $customer = $self->{schema}->resultset('Public::Customer')->find($self->{customer}->id);

    is($customer->category->id, $self->{category}->id,
       'Local XT DB has been updated to ' .$customer->category->category );
}
