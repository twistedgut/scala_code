#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head2 Tests EIP Class in Fraud Checks

This tests that the Customer Class of EIP is used for EIP Customers when applying Fraud rules and NOT individual EIP Categories.

=cut

use Test::XTracker::Data;
use Test::XT::Data;

use Test::XTracker::Hacks::TxnGuardRollback;
use Test::XTracker::Data::Order;

use XTracker::Config::Local;
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :customer_category :customer_class );

use XT::Data::Order;


# the Credit Rating given to EIP's
my $EIP_EXPECTED_RATING = 200;

# re-defing some of the methods used in Fraud checks so
# that we can identify the current 'rating' so as to
# ensure EIP's are being identified correctly
no warnings "redefine";
my $test_rating_value   = 0;
## no critic(ProtectPrivateVars)
*XT::Data::Order::_is_shipping_address_dodgy = \&__is_shipping_address_dodgy;
*XT::Data::Order::_do_hotlist_checks         = \&__do_hotlist_checks;
use warnings "redefine";


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my @channels        = $schema->resultset('Public::Channel')
                                ->enabled_channels
                                    ->all;
my @eip_categories  = $schema->resultset('Public::CustomerCategory')
                                ->search( { customer_class_id => $CUSTOMER_CLASS__EIP } )
                                    ->all;

my $categories      = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::CustomerCategory', {
                                                                                allow   => [
                                                                                        map { $_->id }
                                                                                            @eip_categories
                                                                                    ],
                                                                            } );


$schema->txn_do( sub {
    foreach my $channel ( @channels ) {

        my $data = Test::XT::Data->new_with_traits(
            traits => [
                'Test::XT::Data::Channel',
                'Test::XT::Data::Customer',
            ],
        );

        $data->channel( $channel );     # explicitly set the Sales Channel otherwise it will default to NaP
        my $customer    = $data->customer;

        # just Update it to a Customer Category
        $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );

        my ( $forget, $pids )   = Test::XTracker::Data->grab_products( {
                                            how_many=> 1,
                                            channel => $channel,
                                        } );
        my $product = $pids->[0];

        # Set-up options for the the Order XML file that will be created
        my $order_args  = [
            {
                customer => { id => $customer->is_customer_number },
                order => {
                    channel_prefix => $channel->business->config_section,
                    tender_amount => 110,
                    shipping_price => 10,
                    shipping_tax => 1.50,
                    items => [
                        {
                            sku => $product->{sku},
                            description => $product->{product}
                                                    ->product_attribute
                                                        ->name,
                            unit_price => 100,
                            tax => 10,
                            duty => 0,
                        },
                    ],
                },
            },
        ];

        # Create and Parse Order Files
        my $parsed  = Test::XTracker::Data::Order->create_order_xml_and_parse($order_args);
        my $data_order = $parsed->[0];

        # process the order up to apply credit rating
        # will have to call individual methods
        $data_order->_preprocess;
        my $order   = $data_order->_save;

        # now loop round each Category and for EIP Categories the
        # 'Rating' should be as expected all others should be zero

        note "NON EIP Categories";
        foreach my $category ( @{ $categories->{not_allowed} } ) {
            $test_rating_value  = 0;
            $order->customer->update( { category_id => $category->id } );
            $data_order->_apply_credit_rating( $order, $APPLICATION_OPERATOR_ID );
            cmp_ok( $test_rating_value, '==', 0, "With Category: '" . $category->category . "', Credit Rating has remained at ZERO" );
        }

        note "EIP Categories";
        foreach my $category ( @{ $categories->{allowed} } ) {
            $test_rating_value  = 0;
            $order->customer->update( { category_id => $category->id } );
            $data_order->_apply_credit_rating( $order, $APPLICATION_OPERATOR_ID );
            cmp_ok( $test_rating_value, '==', $EIP_EXPECTED_RATING,
                                "With Category: '" . $category->category . "', Credit Rating has been increased to ${EIP_EXPECTED_RATING}" );
        }
    }

    # rollback work
    $schema->txn_rollback();
} );


# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

done_testing;

#-----------------------------------------------------------------------------

# this re-defines the one in 'XT::Data::Order'
sub __is_shipping_address_dodgy {
    note "====> IN RE-DEFINED '_is_shipping_address_dodgy' METHOD";
    return 0;
}

# this re-defines the one in 'XT::Data::Order'
sub __do_hotlist_checks {
    note "====> IN RE-DEFINED '_do_hotlist_checks' METHOD";
    $test_rating_value  = $_[2];
    return $test_rating_value;
}
