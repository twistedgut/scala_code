package Test::XTracker::Schema::Result::Public::Customer;
use NAP::policy qw/test class/;

=head1 NAME

Test::XTracker::Schema::Result::Public::Customer

=head1 DESCRIPTION

Test the XTracker::Schema::Result::Public::Customer class.

#TAGS cando customer

=head1 TESTS

=cut

BEGIN {
    extends 'NAP::Test::Class';
};

use Test::XT::Data;
use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Data::PreOrder;
use XTracker::Config::Local    qw( config_var );

use Scalar::Util                qw( blessed );

=head2 test_startup

=cut

sub test_startup : Test( startup => no_plan ) {
    my $self = shift;
    use_ok 'XTracker::Schema::Result::Public::Customer';
    use_ok 'XT::Net::Seaview::Client';
    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{seaview} = XT::Net::Seaview::Client->new({schema => $self->{schema}});
    if(ref ($self->{seaview}->useragent) eq 'XT::Net::Seaview::TestUserAgent'){
        $self->{test_ua} = 1;
    }

}

=head2 test_setup

=cut

sub test_setup : Test( setup => no_plan ) {
    my $self = shift;

    $self->{schema}->txn_begin;

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
            origin_region      => config_var('DistributionCentre', 'name'),
            origin_name        => 'XT',
            date_of_birth      => DateTime->now(),
            schema             => $self->{schema},
            category           => 'EIP',
        });

    # Add account to Seaview
    $self->{account_urn} = $self->{seaview}->add_account($self->{account});

    my $data = Test::XT::Data->new_with_traits( {
        traits  => [
            'Test::XT::Data::Order',
        ],
    } );
    $self->{data} = $data;

    $self->{customer} = Test::XTracker::Data->create_dbic_customer( {
        channel_id => Test::XTracker::Data->channel_for_nap->id,
    } );

   # Add global id to XT customer record
    $self->{seaview}->link_customer($self->{customer}->id,
                                    $self->{account_urn});

}

=head2 test_teardown

=cut

sub test_teardown : Test( teardown => no_plan ) {
    my $self = shift;

    $self->{schema}->txn_rollback;

}

=head2 test_update_seaview_account

Tests that when the customer category has been updated, this is reflected in seaview.

=cut

sub test_update_seaview_account : Tests() {
    my $self = shift;

    my $customer = $self->{customer};
    my $category = $self->{schema}->resultset('Public::CustomerCategory')->first;

    # Make the update
    $customer->update_seaview_account(
         $category->id
    );

    # Check the Seaview data
    my $account_urn
      = $self->{seaview}->registered_account($customer->id);

    my $account = $self->{seaview}->account($account_urn);
    isa_ok($account, 'XT::Data::Customer::Account');

    my $expected_category = $self->{test_ua} ? 'EIP'
                                             : $category->category;

    is( $account->category, $expected_category,
        'Seaview account has been updated to ' . $expected_category );
}

=head2 test_shipment_and_invoice_address_methods

Test the following methods:

    get_all_shipment_addresses
    get_all_shipment_addresses_valid_for_preorder
    get_all_invoice_addresses
    get_all_invoice_addresses_valid_for_preorder
    get_all_used_addresses
    get_all_used_addresses_valid_for_preorder

Tho do this we create two Pre-Orders and two Orders, all attached to the same
customer. Each of them has a slightly different shipment and invoice address.
We then test each method to ensure the correct addresses are returned.

=cut

sub test_shipment_and_invoice_address_methods : Tests {
    my $self = shift;

    # Set the required fields to contain just the Postcode.
    local $XTracker::Config::Local::config{PreOrderAddress}
        ->{field_required} = ['postcode'];

    # Get a single channel and customer.
    my $channel         = Test::XTracker::Data->get_local_channel;
    my $customer        = Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );

    # Some useful aliases.
    my @shipment_args   = ( $channel, { shipping_charge_from_address => 1 } );
    my %customer_id     = ( customer_id => $customer->id    );
    my %pre_order_1     = ( first_name  => 'Pre-Order 1'    );
    my %pre_order_2     = ( first_name  => 'Pre-Order 2'    );
    my %order_1         = ( first_name  => 'Order 1'        );
    my %order_2         = ( first_name  => 'Order 2'        );
    my %shipment        = ( last_name   => 'Shipment'       );
    my %invoice         = ( last_name   => 'Invoice'        );
    my %valid           = ( postcode    => 'VALID'          );
    my %invalid         = ( postcode    => ''               );

    # Create two Pre-Orders and two Orders (via shipments).
    my @preorders       = map { Test::XTracker::Data::PreOrder->create_complete_pre_order       } 1..2;
    my @shipments       = map { Test::XTracker::Data::Order->create_shipment( @shipment_args )  } 1..2;

    # Update the first Pre-Order to have the same customer id and different
    # shipment/invoice addresses.
    $preorders[0]->update( {
        %customer_id,
        shipment_address_id => $self->_address( %pre_order_1, %shipment, %valid )->id,
        invoice_address_id  => $self->_address( %pre_order_1, %invoice, %valid )->id,
    } );

    # Update the second Pre-Order to have the same customer id and different
    # shipment/invoice addresses.
    $preorders[1]->update( {
        %customer_id,
        shipment_address_id => $self->_address( %pre_order_2, %shipment, %invalid )->id,
        invoice_address_id  => $self->_address( %pre_order_2, %invoice, %invalid )->id,
    } );

    # Update the first Order to have the same customer id and different
    # shipment/invoice addresses.
    $shipments[0]->update       ( { shipment_address_id => $self->_address( %order_1, %shipment, %valid )->id } );
    $shipments[0]->order->update( { %customer_id, invoice_address_id  => $self->_address( %order_1, %invoice, %valid )->id } );

    # Update the second Order to have the same customer id and different
    # shipment/invoice addresses.
    $shipments[1]->update       ( { shipment_address_id => $self->_address( %order_2, %shipment, %invalid )->id } );
    $shipments[1]->order->update( { %customer_id, invoice_address_id  => $self->_address( %order_2, %invoice, %invalid )->id } );

    # So we end up with a structure like this, all attached to the same
    # customer:
    #
    # Pre-Order 1
    #   Shipment Address    : valid
    #   Invoice Address     : valid
    # Pre-Order 2
    #   Shipment Address    : invalid
    #   Invoice Address     : invalid
    # Order 1
    #   Shipment Address    : valid
    #   Invoice Address     : valid
    # Order 2
    #   Shipment Address    : invalid
    #   Invoice Address     : invalid

    my %tests = (
        get_all_shipment_addresses => {
            is_hash     => 1,
            expected    => [
                superhashof( { %pre_order_1, %shipment, %valid } ),
                superhashof( { %pre_order_2, %shipment, %invalid } ),
                superhashof( { %order_1, %shipment, %valid } ),
                superhashof( { %order_2, %shipment, %invalid } ),
            ],
        },
        get_all_shipment_addresses_valid_for_preorder => {
            is_hash     => 0,
            expected    => [
                superhashof( { %pre_order_1, %shipment, %valid } ),
                superhashof( { %order_1, %shipment, %valid } ),
            ]
        },
        get_all_invoice_addresses => {
            is_hash     => 1,
            expected    => [
                superhashof( { %pre_order_1, %invoice, %valid } ),
                superhashof( { %pre_order_2, %invoice, %invalid } ),
                superhashof( { %order_1, %invoice, %valid } ),
                superhashof( { %order_2, %invoice, %invalid } ),
            ],
        },
        get_all_invoice_addresses_valid_for_preorder => {
            is_hash     => 0,
            expected    => [
                superhashof( { %pre_order_1, %invoice, %valid } ),
                superhashof( { %order_1, %invoice, %valid } ),
            ],
        },
        get_all_used_addresses => {
            is_hash     => 1,
            expected    => [
                superhashof( { %pre_order_1, %shipment, %valid } ),
                superhashof( { %pre_order_1, %invoice, %valid } ),
                superhashof( { %pre_order_2, %shipment, %invalid } ),
                superhashof( { %pre_order_2, %invoice, %invalid } ),
                superhashof( { %order_1, %shipment, %valid } ),
                superhashof( { %order_1, %invoice, %valid } ),
                superhashof( { %order_2, %shipment, %invalid } ),
                superhashof( { %order_2, %invoice, %invalid } ),
            ],
        },
        get_all_used_addresses_valid_for_preorder => {
            is_hash     => 0,
            expected    => [
                superhashof( { %pre_order_1, %shipment, %valid } ),
                superhashof( { %pre_order_1, %invoice, %valid } ),
                superhashof( { %order_1, %shipment, %valid } ),
                superhashof( { %order_1, %invoice, %valid } ),
            ],
        }
    );

    while ( my ( $method, $test ) = each %tests ) {

        my $is_hash  = $test->{is_hash};
        my @expected = @{ $test->{expected} };

        my @got = $is_hash
            ? values %{ { $customer->$method } }
            : @{ $customer->$method };

        cmp_ok( scalar @got, '==', scalar @expected,
            "$method count is as expected" );

        cmp_deeply( [ map { { $_->get_columns } } @got ], bag( @expected ),
            "$method has the correct response" );

    }

}

sub _address {
    my ($self,  %overrides ) = @_;

    my %address = (
        title           => 'Title',
        first_name      => 'Another',
        last_name       => 'Customer',
        address_line_1  => 'Line 1',
        address_line_2  => 'Line 2',
        address_line_3  => 'Line 3',
        towncity        => 'Town',
        county          => 'County',
        country         => 'Country',
        address_hash    => 'HASH',
        %overrides,
    );

    return Test::XTracker::Data->create_order_address( \%address )

}

=head2 test_get_seaview_or_local_addresses

Tests the method 'get_seaview_or_local_addresses' returns the
expected Addresses from either Seaview or the local 'order_address'
table.

=cut

sub test_get_seaview_or_local_addresses : Tests() {
    my $self = shift;

    # set an Address Line that will be in XT only
    my $xt_addr_line_1 = 'Not In Seaview';

    # create an Address for the Customer in the DB
    my $address = Test::XTracker::Data->create_order_address( {
        address_line_1 => $xt_addr_line_1,
        last_modified  => \'now()',
    } )->discard_changes;

    my $customer = $self->{customer}->discard_changes;

    # create an Order for the Customer and the Address
    my $order = $self->{data}->new_order(
        channel  => $customer->channel,
        customer => $customer,
        address  => $address,
    );


    #
    # Test when the Customer has a Seaview account
    # and then all the Addresses come from Seaview
    # and none from XT's 'order_address' table
    #
    note "Test when Customer has a Seaview Account";

    # make sure the Customer has a URN
    $customer->update( { account_urn => $self->{account_urn} } );

    my $got = $customer->get_seaview_or_local_addresses();
    isa_ok( $got, 'HASH', "'get_seaview_or_local_addresses' returned a HASH Ref." );
    cmp_ok( scalar( keys %{ $got } ), '>=', 1, "and has at least one Address in it" );
    my $xt_address_count = scalar(
        grep { $_->{address_line_1} eq $xt_addr_line_1 }
            values %{ $got }
    );
    cmp_ok( $xt_address_count, '==', 0, "and can't find XT DB Address" )
                    or diag "ERROR - and CAN'T find XT DB Address: " . p( $got );
    # get one address and look at the 'addr_key'
    my ( $address_hash ) = values %{ $got };
    like( $address_hash->{addr_key}, qr/urn/i, "'addr_key' in Hash looks like a URN" );
    my @blessed_keys = grep {
        blessed( $address_hash->{ $_ } )
    } keys %{ $address_hash };
    cmp_deeply( \@blessed_keys, bag( qw( urn addr_key last_modified ) ),
                    "and has blessed Objects in the expected keys" )
                        or diag "ERROR - has blessed Objects: " . p( @blessed_keys );
    note "calling 'get_seaview_or_local_addresses' with 'stringify_objects' option";
    $got = $customer->get_seaview_or_local_addresses( { stringify_objects => 1 } );
    ( $address_hash ) = values %{ $got };
    isa_ok( $address_hash, 'HASH', "returned a HASH Ref." );
    @blessed_keys = grep {
        blessed( $address_hash->{ $_ } )
    } keys %{ $address_hash };
    cmp_ok( scalar( @blessed_keys ), '==', 0, "and no blessed Objects found in Address" );


    #
    # Test when the Customer doesn't have a Seaview
    # account and then all the Customer's Addresses
    # will come from XT's 'order_address' table
    #
    note "Test when Customer doesn't have a Seaview Account and has Local Addresses";

    # clear the Customer's URN
    $customer->discard_changes->update( { account_urn => undef } );

    $got = $customer->get_seaview_or_local_addresses();
    isa_ok( $got, 'HASH', "'get_seaview_or_local_addresses' returned a HASH Ref." );
    cmp_ok( scalar( keys %{ $got } ), '>=', 1, "and has at least one Address in it" );
    $xt_address_count = scalar(
        grep { $_->{address_line_1} eq $xt_addr_line_1 }
            values %{ $got }
    );
    cmp_ok( $xt_address_count, '==', 1, "and CAN find XT DB Address" )
                    or diag "ERROR - and CAN find XT DB Address: " . p( $got );
    # get one address and look at the 'addr_key'
    ( $address_hash ) = values %{ $got };
    unlike( $address_hash->{addr_key}, qr/urn/i, "'addr_key' in Hash DOESN'T look like a URN" );
    @blessed_keys = grep {
        blessed( $address_hash->{ $_ } )
    } keys %{ $address_hash };
    cmp_deeply( \@blessed_keys, bag( qw( last_modified ) ),
                    "and has blessed Objects in the expected keys" )
                        or diag "ERROR - has blessed Objects: " . p( @blessed_keys );
    note "calling 'get_seaview_or_local_addresses' with 'stringify_objects' option";
    $got = $customer->get_seaview_or_local_addresses( { stringify_objects => 1 } );
    ( $address_hash ) = values %{ $got };
    isa_ok( $address_hash, 'HASH', "returned a HASH Ref." );
    @blessed_keys = grep {
        blessed( $address_hash->{ $_ } )
    } keys %{ $address_hash };
    cmp_ok( scalar( @blessed_keys ), '==', 0, "and no blessed Objects found in Address" );


    #
    # Test for a brand new Customer with no Seaview
    # Account that the method returns nothing
    #
    note "Create a New Customer that doesn't have a Seaview Account or any Addresses";

    my $new_customer = Test::XTracker::Data->create_dbic_customer( {
        channel_id => $customer->channel_id,
    } );
    $new_customer->discard_changes->update( { account_urn => undef } );
    $got = $new_customer->get_seaview_or_local_addresses();
    ok( !defined $got, "'get_seaview_or_local_addresses' returned 'undef'")
                or diag "ERROR - 'get_seaview_or_local_addresses' returned 'undef': " . p( $got );
}

