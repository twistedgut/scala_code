#!/usr/bin/env perl

=head1 NAME

t/20-units/database/customer_value.t

=head1 DESCRIPTION

=head2 CANDO-31: Display the 'Customer's Total Value'

This tests the 4 functions invloved in getting the 'Customer Value' which is used by the Customer Care
team on the 'Customer View' page that you get to from the 'Order View' page.

This tests the following functions in 'XTracker::Database::Customer':
  * get_customer_value (using the proxy call C<calculate_customer_value> in
    L<XTracker::Schema::Result::Public::Customer>
  * get_cv_spend
  * get_cv_return_rate
  * get_cv_order_count

The last 3 are all used by the first one (get_customer_value)

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Data::Dump  qw( pp );


use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use DateTime::Duration;

BEGIN {
    use_ok( 'XTracker::Database::Customer', qw(
                                                get_cv_spend
                                                get_cv_return_rate
                                                get_cv_order_count
                                        ) );
    can_ok( 'XTracker::Database::Customer', qw(
                                                get_cv_spend
                                                get_cv_return_rate
                                                get_cv_order_count
                                        ) );
}

use Test::XT::Data;

use XTracker::Config::Local             qw( config_var );
use XTracker::Utilities                 qw( format_currency );
use XTracker::Database::Currency        qw( get_currency_glyph );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw(
                                            :currency
                                            :customer_issue_type
                                            :renumeration_class
                                            :renumeration_status
                                            :renumeration_type
                                            :return_status
                                            :return_item_status
                                            :return_type
                                            :shipment_status
                                            :shipment_class
                                            :shipment_item_status
                                        );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );
my $dbh = $schema->storage->dbh;

# set up the date ranges for use in the tests
my $date    = _setup_dates();
# set up currencies used
my @currency= _setup_currency( $schema );

$schema->txn_do( sub {
    my $renum;
    my @orders;
    my @returns;

    my $tmp;
    my $store_spend;
    my $store_retrate;
    my $store_custvalue;

    my $data = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',      # should default to NaP
            'Test::XT::Data::Customer',
        ],
    );

    my $channel = $data->channel;
    my $customer= $data->customer;

    # set-up the the parameters to pass into the functions
    # as they are mainly going to be the same for every call
    my @func_params = ( $dbh, $customer, $date->{start}, $date->{end} );

    note "TEST Functions without any Orders for the Customer";
    $tmp    = get_cv_spend( @func_params );
    isa_ok( $tmp, 'ARRAY', "'get_cv_spend' returns an Array - with no Orders" );
    cmp_ok( @{ $tmp }, '==', 0, "Array has ZERO elements" );
    $store_spend    = $tmp;     # store for later comparison
    $tmp    = get_cv_return_rate( @func_params );
    isa_ok( $tmp, 'HASH', "'get_cv_return_rate' returns a Hash - with no Orders" );
    is_deeply( $tmp, { total_items => 0, items_bought => 0, items_returned => 0, unit_return_rate => '0.00%' },
                            "All Values in the Hash are ZERO" );
    $store_retrate  = $tmp;     # store for later comparison
    cmp_ok( get_cv_order_count( @func_params ), '==', 0, "'get_cv_order_count' returns ZERO - with no Orders" );
    $tmp    = $customer->calculate_customer_value;
    isa_ok( $tmp, 'HASH', "'calculate_customer_value' returns a Hash - with no Orders" );
    is_deeply( $tmp, {
                    $channel->id => {
                        sales_channel   => $channel->name,
                        customer_id     => $customer->id,
                        period  => {
                            fancy => "last 12 months (from ".$date->{start}->dmy('-')." to ".$date->{end}->dmy('-')." inclusive)",
                            start_date => $date->{start}->ymd('-'),
                            end_date => $date->{end}->ymd('-'),
                        },
                        spend           => $store_spend,
                        return_rate     => $store_retrate,
                        number_of_orders=> 0,
                    }
                }, "Hash had no values but did have the basic information in it" );
    $store_custvalue    = $tmp;     # store for later comparision

    note "TEST creating Orders outside the Date Range with no Orders inside the Date Range and check nothing is still returned";
    _create_test_order( $customer, $date->{before}, 1, $currency[0] );  # create an order before the Date Range
    _create_test_order( $customer, $date->{after}, 1, $currency[0] );   # create an order after the Date Range
    $tmp    = get_cv_spend( @func_params );
    is_deeply( $tmp, $store_spend, "'get_cv_spend' returns the same as it did with no orders at all" );
    $tmp    = get_cv_return_rate( @func_params );
    is_deeply( $tmp, $store_retrate, "'get_cv_return_rate' returns the same as it did with no orders at all" );
    cmp_ok( get_cv_order_count( @func_params ), '==', 0, "'get_cv_order_count' is still ZERO" );
    $tmp    = $customer->calculate_customer_value;
    is_deeply( $tmp, $store_custvalue, "'calculate_customer_value' returns the same as it did with no orders at all" );

    note "Create 1st Order in the Date Range";
    $orders[0]  = _create_test_order( $customer, $date->{middle}, 1, $currency[0] );

    $tmp    = get_cv_spend( @func_params );
    _check_get_cv_spend_firsttime( $tmp, $orders[0] );
    $tmp    = get_cv_return_rate( @func_params );
    _check_get_cv_return_rate_firsttime( $tmp, $orders[0] );
    cmp_ok( get_cv_order_count( @func_params ), '==', 1, "'get_cv_order_count' returned '1' order" );

    note "Create 2nd Order with a different Currency";
    $orders[1]  = _create_test_order( $customer, $date->{middle}, 2, $currency[1] );
    $tmp    = get_cv_spend( @func_params );
    cmp_ok( @{ $tmp }, '==', 2, "'get_cv_spend' returns 2 elements now" );
    is( $tmp->[1]{currency}, $currency[1]->currency, "2nd element currency is: ".$currency[1]->currency );
    cmp_ok( $tmp->[1]{gross}{value}, '==', $orders[1]{total}, "2nd element gross is: " . $orders[1]{total} );
    $store_spend    = $tmp;     # keep for later comparison
    $tmp    = get_cv_return_rate( @func_params );
    cmp_ok( $tmp->{total_items}, '==', 3, "'get_cv_return_rate' now shows 3 'total_items'" );
    cmp_ok( $tmp->{items_bought}, '==', 3, "'get_cv_return_rate' now shows 3 'items_bought'" );
    $store_retrate  = $tmp;    # keep for later comparison
    cmp_ok( get_cv_order_count( @func_params ), '==', 2, "'get_cv_order_count' now returns '2' orders" );

    note "Create 3rd Order Outside of the date range - just BEFORE it";
    $orders[2]  = _create_test_order( $customer, $date->{before}, 1, $currency[0] );
    $tmp    = get_cv_spend( @func_params );
    is_deeply( $tmp, $store_spend, "what 'get_cv_spend' remains unchanged - excludes latest order" );
    $tmp    = get_cv_return_rate( @func_params );
    is_deeply( $tmp, $store_retrate, "what 'get_cv_return_rate' remains unchanged - excludes latest order" );
    cmp_ok( get_cv_order_count( @func_params ), '==', 2, "'get_cv_order_count' still returns '2' orders - excludes latest order" );

    note "Create 4th Order Outside of the date range - just AFTER it";
    $orders[2]  = _create_test_order( $customer, $date->{after}, 1, $currency[0] );  # overwrite previous order as we won't need it
    $tmp    = get_cv_spend( @func_params );
    is_deeply( $tmp, $store_spend, "what 'get_cv_spend' remains unchanged - excludes latest order" );
    $tmp    = get_cv_return_rate( @func_params );
    is_deeply( $tmp, $store_retrate, "what 'get_cv_return_rate' remains unchanged - excludes latest order" );
    cmp_ok( get_cv_order_count( @func_params ), '==', 2, "'get_cv_order_count' still returns '2' orders - excludes latest order" );

    note "Create a 5th Order inside the Date range using the 1st Currency";
    $orders[3]  = _create_test_order( $customer, $date->{middle}, 3, $currency[0] );
    $tmp    = get_cv_spend( @func_params );
    cmp_ok( $tmp->[0]{gross}{value}, '==', _fmt_value( $orders[0]{total} + $orders[3]{total} ),
                            "'get_cv_spend' gross has increased for first currency: " . ( $orders[0]{total} + $orders[3]{total} ) );
    $tmp    = get_cv_return_rate( @func_params );
    cmp_ok( $tmp->{total_items}, '==', 6, "'get_cv_return_rate' now shows 6 'total_items'" );
    cmp_ok( $tmp->{items_bought}, '==', 6, "'get_cv_return_rate' now shows 6 'items_bought'" );
    cmp_ok( get_cv_order_count( @func_params ), '==', 3, "'get_cv_order_count' now returns '3' orders" );

    note "Take off Gift Voucher value from last order";
    $orders[3]{total}   = _renum_total( $orders[3]{renum}->update( { gift_voucher => -15 } ) );
    $tmp    = get_cv_spend( @func_params );
    cmp_ok( $tmp->[0]{gross}{value}, '==', _fmt_value( $orders[0]{total} + $orders[3]{total} ),
                            "'get_cv_spend' gross has decreased by Gift Voucher amount: " . ( $orders[0]{total} + $orders[3]{total} ) );

    note "Give Some Store Credit to the last order shouldn't change anything";
    $orders[3]{renum}->update( { store_credit => -35 } );
    $tmp    = get_cv_spend( @func_params );
    cmp_ok( $tmp->[0]{gross}{value}, '==', _fmt_value( $orders[0]{total} + $orders[3]{total} ),
                            "'get_cv_spend' gross has not decreased by Store Credit amount, still: " . ( $orders[0]{total} + $orders[3]{total} ) );

    note "Return the 5th Order to Card";
    $returns[0] = _create_test_return( $schema, $orders[3], "Card", 2 );
    $tmp    = get_cv_spend( @func_params );
    cmp_ok( $tmp->[0]{gross}{value}, '==', _fmt_value( $orders[0]{total} + $orders[3]{total} ),
                            "'get_cv_spend' after return gross is still the same: " . ( $orders[0]{total} + $orders[3]{total} ) );
    cmp_ok( $tmp->[0]{net}{value}, '==', _fmt_value( $tmp->[0]{gross}{value} - $returns[0]{total} ),
                            "'get_cv_spend' net is now gross less return refund amount: " . ( $tmp->[0]{gross}{value} - $returns[0]{total} ) );
    cmp_ok( $tmp->[0]{returns}{value}, '==', $returns[0]{total}, "'get_cv_spend' returns value is the same as the refund amount: " . $returns[0]{total} );
    $store_spend    = $tmp;
    $tmp    = get_cv_return_rate( @func_params );
    cmp_ok( $tmp->{total_items}, '==', 6, "'get_cv_return_rate' still shows 6 'total_items'" );
    cmp_ok( $tmp->{items_bought}, '==', 4, "'get_cv_return_rate' 'items_bought' now shows 4" );
    cmp_ok( $tmp->{items_returned}, '==', 2, "'get_cv_return_rate' 'items_returned' is now 2" );
    is( $tmp->{unit_return_rate}, _pcnt( 2, 6 ), "'get_cv_return_rate' 'unit_return_rate' is as expected: " . _pcnt( 2, 6 ) );

    note "Add '+10' Shipping to 5th Order & its Return and Check it's reflected in Gross & Returns";
    # add 10 to both Shipping values
    $orders[3]{renum}->update( { shipping => \"shipping + 10" } );
    $returns[0]{renum}->update( { shipping => \"shipping + 10" } );
    $tmp    = get_cv_spend( @func_params );
    cmp_ok( $tmp->[0]{gross}{value}, '==', _fmt_value( $store_spend->[0]{gross}{value} + 10 ),
                            "'get_cv_spend' gross is +10 than what it was: " . ( $store_spend->[0]{gross}{value} + 10 ) );
    cmp_ok( $tmp->[0]{returns}{value}, '==', _fmt_value( $store_spend->[0]{returns}{value} + 10 ),
                            "'get_cv_spend' returns is +10 than what it was: " . ( $store_spend->[0]{returns}{value} + 10 ) );
    cmp_ok( $tmp->[0]{net}{value}, '==', $store_spend->[0]{net}{value},
                            "'get_cv_spend' net is still the same as both increases cancel each other out: " . $store_spend->[0]{net}{value} );
    # undo the shipping changes
    $orders[3]{renum}->update( { shipping => \"shipping - 10" } );
    $returns[0]{renum}->update( { shipping => \"shipping - 10" } );


    # now there are a few orders and one return run some tests with different statuses/classes etc. to see what happens
    _test_cv_spend_func_with_statuses( $orders[3], $returns[0], $date );
    _test_cv_funcs_with_statuses( $orders[3], $returns[0], $date );


    note "Return the last item of the 5th Order to Store Credit";
    $returns[1] = _create_test_return( $schema, $orders[3], "Store Credit", 1 );
    $tmp    = get_cv_spend( @func_params );
    cmp_ok( $tmp->[0]{gross}{value}, '==', _fmt_value( $orders[0]{total} + $orders[3]{total} ),
                            "'get_cv_spend' after return gross is still the same: " . ( $orders[0]{total} + $orders[3]{total} ) );
    cmp_ok( $tmp->[0]{net}{value}, '==', _fmt_value( $tmp->[0]{gross}{value} - ( $returns[0]{total} + $returns[1]{total} ) ),
                            "'get_cv_spend' net is now gross less both refund amounts: " . ( $tmp->[0]{gross}{value} - ( $returns[0]{total} + $returns[1]{total} ) ) );
    cmp_ok( $tmp->[0]{returns}{value}, '==', _fmt_value( $returns[0]{total} + $returns[1]{total} ) , "'get_cv_spend' returns value is now includes both refund amounts: " . ( $returns[0]{total} + $returns[1]{total} ) );
    $tmp    = get_cv_return_rate( @func_params );
    cmp_ok( $tmp->{total_items}, '==', 6, "'get_cv_return_rate' still shows 6 'total_items'" );
    cmp_ok( $tmp->{items_bought}, '==', 3, "'get_cv_return_rate' 'items_bought' now shows 3" );
    cmp_ok( $tmp->{items_returned}, '==', 3, "'get_cv_return_rate' 'items_returned' is now 3" );
    is( $tmp->{unit_return_rate}, _pcnt( 3, 6 ), "'get_cv_return_rate' 'unit_return_rate' is as expected: " . _pcnt( 3, 6 ) );

    note "Return the 2nd Order which is for a different Currency, to Store Credit";
    $returns[2] = _create_test_return( $schema, $orders[1], "Store Credit", 1 );
    $tmp    = get_cv_spend( @func_params );
    $store_spend    = $tmp;     # store for later
    cmp_ok( $tmp->[1]{gross}{value}, '==', $orders[1]{total},
                            "'get_cv_spend' after return gross is still the same for the 2nd currency: " . $orders[1]{total} );
    cmp_ok( $tmp->[1]{net}{value}, '==', _fmt_value( $tmp->[1]{gross}{value} - $returns[2]{total} ),
                            "'get_cv_spend' net is now gross less return refund amount for 2nd currency: " . ( $tmp->[1]{gross}{value} - $returns[2]{total} ) );
    cmp_ok( $tmp->[1]{returns}{value}, '==', $returns[2]{total}, "'get_cv_spend' returns value for 2nd currency is the same as the refund amount: " . $returns[2]{total} );
    $tmp    = get_cv_return_rate( @func_params );
    cmp_ok( $tmp->{total_items}, '==', 6, "'get_cv_return_rate' still shows 6 'total_items'" );
    cmp_ok( $tmp->{items_bought}, '==', 2, "'get_cv_return_rate' 'items_bought' now shows 2" );
    cmp_ok( $tmp->{items_returned}, '==', 4, "'get_cv_return_rate' 'items_returned' is now 4" );
    is( $tmp->{unit_return_rate}, _pcnt( 4, 6 ), "'get_cv_return_rate' 'unit_return_rate' is as expected: " . _pcnt( 4, 6 ) );
    $store_retrate  = $tmp;     # store for later


    # now test the 'calculate_customer_value' function it'self
    # to make sure it returns what we think it should
    note "TEST the 'calculate_customer_value' function it'self";
    my %expected    = (
            $channel->id => {
                sales_channel   => $channel->name,
                customer_id     => $customer->id,
                spend           => $store_spend,    # use the stuff we stored before
                return_rate     => $store_retrate,  #
                number_of_orders=> 3,
                period  => {
                    fancy       => "last 12 months (from " . $date->{start}->dmy('-') . " to " . $date->{end}->dmy('-') . " inclusive)",
                    start_date  => $date->{start}->ymd('-'),
                    end_date    => $date->{end}->ymd('-'),
                },
            },
        );
    # call 'calculate_customer_value'
    $tmp    = $customer->calculate_customer_value;
    is_deeply( $tmp, \%expected, "'calculate_customer_value' returned as expected" );

    # rollback changes
    $schema->txn_rollback();
} );


done_testing();

#-----------------------------------------------------------------

# this checks the 'get_cv_spend' functions using different statuses, classes
# etc. to see if the correct values are adjusted properly, doesn't really
# fit into '_test_cv_funcs_with_statuses' very easily so is on it's own
sub _test_cv_spend_func_with_statuses {
    my ( $ordinfo, $retinfo, $date )    = @_;

    note "CHECKING 'get_cv_spend' function with various different statuses, classes & types";

    my $schema  = $ordinfo->{order}->result_source->schema;
    my @func_params = (
                    $schema->storage->dbh,
                    $ordinfo->{order}->customer,
                    $date->{start},
                    $date->{end}
                );

    my %initial_values;
    my $order           = $ordinfo->{order};
    my $ordvalue        = $ordinfo->{total};
    my $ordrenum        = $ordinfo->{renum};
    my $return          = $retinfo->{return};
    my $retvalue        = $retinfo->{total};
    my $retrenum        = $retinfo->{renum};

    # get the current customer spend values and deduct current order
    # and return amounts from totals prior to tests
    my $spend   = get_cv_spend( @func_params );
    ( $initial_values{spend} )              = grep { $_->{currency} eq $order->currency->currency } @{ $spend };
    $initial_values{spend}{gross}{value}    -= $ordvalue;
    $initial_values{spend}{returns}{value}  -= $retvalue;
    $initial_values{spend}{net}{value}      = $initial_values{spend}{gross}{value} - $initial_values{spend}{returns}{value};
    $initial_values{currency}               = $order->currency->currency;

    # get different renumeration statuses & classes etc. - '_o' = for Order Renum, '_r' = for Return Renum
    my %r_statuses  = map { $_->id => $_ } ( $schema->resultset('Public::RenumerationStatus')->all );
    my %r_classes_o = map { $_->id => $_ } ( $schema->resultset('Public::RenumerationClass')->all );
    my %r_classes_r = map { $_->id => $_ } ( $schema->resultset('Public::RenumerationClass')->all );
    my %r_types_o   = map { $_->id => $_ } ( $schema->resultset('Public::RenumerationType')->all );
    my %r_types_r   = map { $_->id => $_ } ( $schema->resultset('Public::RenumerationType')->all );

    note "USING different Renumeration Statuses";
    my %renum_statuses  = (
            # specify what needs to be updated and how
            config => {
                label => 'Status',
                test_spend_only => 1,       # tell '_run_cv_funcs_status_tests' to only run 'get_cv_spend' tests
                id_name_column => 'status',
                _update_func => sub {
                        my ( $obj, $value ) = @_;
                        $obj->update( { renumeration_status_id => $value } );
                    },
            },
            Gross => {
                # get the Renumeration Status Id's that we want that will effect the Gross Value
                ids => [ map { delete $r_statuses{$_} } ( $RENUMERATION_STATUS__COMPLETED ) ],
                rec_to_update => $ordrenum,
                gross => +$ordvalue,
            },
            # this tests that items with these statuses are ignored
            # by the function, uses all of the un-used statuses
            Ignored => {
                ids => [ values %r_statuses ],
                gross => +0,
                rec_to_update => $ordrenum,
            },
        );
    note "first test 'Gross'";
    _run_cv_funcs_status_tests( \%renum_statuses, \%initial_values, \@func_params );

    # now do the same but using the Returns Renumeration record
    $renum_statuses{Returns}    = {
                ids => $renum_statuses{Gross}{ids},       # use the same id's as for the Gross
                rec_to_update => $retrenum,
                returns => +$retvalue,
            };
    $renum_statuses{Ignored}{rec_to_update} = $retrenum;
    $renum_statuses{Ignored}{returns}       = +0;
    # get rid of any Gross specific stuff from hash
    delete $renum_statuses{Gross};
    delete $renum_statuses{Ignored}{gross};
    note "now test 'Returns'";
    _run_cv_funcs_status_tests( \%renum_statuses, \%initial_values, \@func_params );


    note "USING different Renumeration Classes";
    # update records so that they will be included
    $ordrenum->update( { renumeration_status_id => $RENUMERATION_STATUS__COMPLETED } );
    $retrenum->update( { renumeration_status_id => $RENUMERATION_STATUS__COMPLETED } );

    my %renum_classes  = (
            config => {
                label => 'Class',
                test_spend_only => 1,
                id_name_column => 'class',
                _update_func => sub {
                        my ( $obj, $value ) = @_;
                        $obj->update( { renumeration_class_id => $value } );
                    },
            },
            Gross => {
                ids => [ map { delete $r_classes_o{$_} } ( $RENUMERATION_CLASS__ORDER ) ],
                rec_to_update => $ordrenum,
                gross => +$ordvalue,
            },
            Ignored => {
                ids => [ values %r_classes_o ],
                gross => +0,
                rec_to_update => $ordrenum,
            },
        );
    note "first test 'Gross'";
    _run_cv_funcs_status_tests( \%renum_classes, \%initial_values, \@func_params );

    # now do the same but using the Returns Renumeration record
    $renum_classes{Returns}    = {
                ids => [ map { delete $r_classes_r{$_} } ( $RENUMERATION_CLASS__RETURN ) ],
                rec_to_update => $retrenum,
                returns => +$retvalue,
            };
    $renum_classes{Ignored}    = {
                ids => [ values %r_classes_r ],
                rec_to_update => $retrenum,
                returns => +0,
            };
    # get rid of any Gross specific stuff from hash
    delete $renum_classes{Gross};
    delete $renum_classes{Ignored}{gross};
    note "now test 'Returns'";
    _run_cv_funcs_status_tests( \%renum_classes, \%initial_values, \@func_params );


    note "USING different Renumeration Types";
    # update records so that they will be included
    $ordrenum->update( { renumeration_class_id => $RENUMERATION_CLASS__ORDER } );
    $retrenum->update( { renumeration_class_id => $RENUMERATION_CLASS__RETURN } );

    my %renum_types  = (
            config => {
                label => 'Type',
                test_spend_only => 1,
                id_name_column => 'type',
                _update_func => sub {
                        my ( $obj, $value ) = @_;
                        $obj->update( { renumeration_type_id => $value } );
                    },
            },
            Gross => {
                ids => [ map { delete $r_types_o{$_} } ( $RENUMERATION_TYPE__CARD_DEBIT ) ],
                rec_to_update => $ordrenum,
                gross => +$ordvalue,
            },
            Ignored => {
                ids => [ values %r_types_o ],
                gross => +0,
                rec_to_update => $ordrenum,
            },
        );
    note "first test 'Gross'";
    _run_cv_funcs_status_tests( \%renum_types, \%initial_values, \@func_params );

    # now do the same but using the Returns Renumeration record
    $renum_types{Returns}    = {
                ids => [ map { delete $r_types_r{$_} } ( $RENUMERATION_TYPE__CARD_REFUND, $RENUMERATION_TYPE__STORE_CREDIT ) ],
                rec_to_update => $retrenum,
                returns => +$retvalue,
            };
    $renum_types{Ignored}    = {
                ids => [ values %r_types_r ],
                rec_to_update => $retrenum,
                returns => +0,
            };
    # get rid of any Gross specific stuff from hash
    delete $renum_types{Gross};
    delete $renum_types{Ignored}{gross};
    note "now test 'Returns'";
    _run_cv_funcs_status_tests( \%renum_types, \%initial_values, \@func_params );

    # reset the data for further tests
    $ordrenum->update( { renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT } );
    $retrenum->update( { renumeration_type_id => $RENUMERATION_TYPE__CARD_REFUND } );
}

# this checks that the 'get_cv_return_rate' & 'get_cv_order_count' functions
# return the correct numbers with all the different statuses that can occur, this needs
# a completed return with the return item & shipment items set properly
# otherwise it won't be-able to work out properly the numbers when doing the tests
sub _test_cv_funcs_with_statuses {
    my ( $ordinfo, $retinfo, $date )    = @_;

    note "CHECKING 'get_cv_return_rate' & 'get_cv_order_count' funcs with various different statuses, classes & types";

    my $schema  = $ordinfo->{order}->result_source->schema;
    my @func_params = (
                    $schema->storage->dbh,
                    $ordinfo->{order}->customer,
                    $date->{start},
                    $date->{end}
                );

    my %initial_values;
    my $order           = $ordinfo->{order};
    my $return          = $retinfo->{return};
    my $shipment        = $return->shipment;
    my $retitems        = $retinfo->{items};
    my $retitem_count   = @{ $retitems };
    my $totshipitems    = $shipment->shipment_items->count;
    # need this figure to allow for other shipment items being excluded
    # in some tests which mean the entire shipment is ignored
    my $othrshipitem_count = $totshipitems - $retitem_count;

    # get the current return rate values and set them up prior to tests
    # to check everything is correct after a status has been changed
    $initial_values{ret_rate}                   = get_cv_return_rate( @func_params );
    $initial_values{ret_rate}->{total_items}    -= $retitem_count;
    $initial_values{ret_rate}->{items_returned} -= $retitem_count;

    # get the current order count and then deduct the current order
    $initial_values{order_count}    = get_cv_order_count( @func_params );
    $initial_values{order_count}--;

    # get different statuses & classes
    my %si_statuses = map { $_->id => $_ } ( $schema->resultset('Public::ShipmentItemStatus')->all );
    my %s_statuses  = map { $_->id => $_ } ( $schema->resultset('Public::ShipmentStatus')->all );
    my %s_classes   = map { $_->id => $_ } ( $schema->resultset('Public::ShipmentClass')->all );

    note "USING different Shipment Item Statuses";
    my %ship_item_statuses  = (
            # specify what needs to be updated and how
            config => {
                label => 'Status',
                id_name_column => 'status',
                _update_func => sub {
                        my $value   = shift;
                        map { $_->shipment_item->update( { shipment_item_status_id => $value } ) } @{ $retitems };
                    },
            },
            Bought => {
                # get the Shipment Item Status Id's that we want that will effect the Bought value
                ids => [ map { delete $si_statuses{$_} } ( $SHIPMENT_ITEM_STATUS__PACKED, $SHIPMENT_ITEM_STATUS__DISPATCHED, $SHIPMENT_ITEM_STATUS__RETURN_PENDING ) ],
                total_items => +$retitem_count,
                items_bought => +$retitem_count,
                items_returned => +0,
                order_count => 1,
            },
            Return => {
                # get the Shipment Item Status Id's that we want that will effect the Returned value
                ids => [ map { delete $si_statuses{$_} } ( $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED, $SHIPMENT_ITEM_STATUS__RETURNED ) ],
                total_items => +$retitem_count,
                items_bought => +0,
                items_returned => +$retitem_count,
                order_count => 1,
            },
            # this tests that items with these statuses are ignored
            # by the function, uses all of the un-used statuses
            Ignored => {
                ids => [ values %si_statuses ],
                total_items => +0,
                items_bought => +0,
                items_returned => +0,
                order_count => 1,       # this will prove that the other non-return items which
                                        # are set to Dispatched should still cause the Order to count
            },
        );
    _run_cv_funcs_status_tests( \%ship_item_statuses, \%initial_values, \@func_params );


    note "USING different Shipment Statuses";

    # tested the different Shipment Item Statuses on the Bought & Returned values so
    # now just keep effecting the Returned values by updating the shipment item to be
    # 'Return Received' and making sure records aren't ignored when set to other statuses
    map { $_->shipment_item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED } ) } @{ $retitems };

    my %shipment_statuses   = (
            # specify what needs to be updated and how
            config => {
                label => 'Status',
                id_name_column => 'status',
                _update_func => sub {
                        my $value   = shift;
                        $shipment->update( { shipment_status_id => $value } );
                    },
            },
            Returned => {
                ids => [ map { delete $s_statuses{$_} } ( $SHIPMENT_STATUS__PROCESSING, $SHIPMENT_STATUS__DISPATCHED ) ],
                total_items => +$retitem_count,
                items_bought => +0,
                items_returned => +$retitem_count,
                order_count => +1,
            },
            Ignored => {
                ids => [ values %s_statuses ],
                total_items => -$othrshipitem_count,
                items_bought => -$othrshipitem_count,
                items_returned => +0,
                order_count => +0,
            },
        );
    _run_cv_funcs_status_tests( \%shipment_statuses, \%initial_values, \@func_params );


    note "USING different Shipment Classes";

    # update the shipment to being a status that will always be included
    $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED } );

    my %shipment_classes    = (
            # specify what needs to be updated and how
            config => {
                label => 'Class',
                id_name_column => 'class',
                _update_func => sub {
                        my $value   = shift;
                        $shipment->update( { shipment_class_id => $value } );
                    },
            },
            Returned => {
                ids => [ map { delete $s_classes{$_} } ( $SHIPMENT_CLASS__STANDARD, $SHIPMENT_CLASS__RE_DASH_SHIPMENT, $SHIPMENT_CLASS__REPLACEMENT ) ],
                total_items => +$retitem_count,
                items_bought => +0,
                items_returned => +$retitem_count,
                order_count => +1,
            },
            Ignored => {
                ids => [ values %s_classes ],
                total_items => -$othrshipitem_count,
                items_bought => -$othrshipitem_count,
                items_returned => +0,
                order_count => +0,
            },
        );
    _run_cv_funcs_status_tests( \%shipment_classes, \%initial_values, \@func_params );


    note "USING different Shipment Item Statuses for ALL Shipment Items, primarily testing 'get_cv_order_count' function";
    # this tests that when all shipment items are updated to be the same status
    # that the order is counted by the 'get_cv_order_count' function for some
    # statuses and not for others

    my %all_ship_item_statuses  = (
            config => {
                label => 'Status',
                id_name_column => 'status',
                _update_func => sub {
                        my $value   = shift;
                        $shipment->discard_changes->shipment_items->update( { shipment_item_status_id => $value } );
                    },
            },
            Bought => {
                ids => $ship_item_statuses{Bought}{ids},      # use the previous ship item ids as they are the same
                total_items => +$retitem_count,
                items_bought => +$retitem_count,
                items_returned => +0,
                order_count => 1,
            },
            Return => {
                ids => $ship_item_statuses{Return}{ids},
                total_items => +$retitem_count,
                items_bought => -$othrshipitem_count,
                items_returned => +( $retitem_count + $othrshipitem_count ),
                order_count => 1,
            },
            Ignored => {
                ids => $ship_item_statuses{Ignored}{ids},
                total_items => -$othrshipitem_count,    # any other Shipment Items which aren't Returns won't be counted either
                items_bought => -$othrshipitem_count,
                items_returned => +0,
                order_count => 0,
            },
        );
    _run_cv_funcs_status_tests( \%all_ship_item_statuses, \%initial_values, \@func_params );


    note "TEST Return Items as Type 'Exchange' don't count as Returns";
    # this test re-tests the Shipment Item Statuses but with each return
    # item as an 'Exhange' type it now means that all statuses result
    # in an increase in the 'Bought' value and not in the 'Returned' value

    # update the shipment class to be 'Standard'
    $shipment->update( { shipment_class_id => $SHIPMENT_CLASS__STANDARD } );
    # update all shipment items to be 'Dispatched'
    $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );
    # update all the Return Items to be Exchanges
    $return->return_items->update( { return_type_id => $RETURN_TYPE__EXCHANGE } );
    # set shipment items that are returns to 'Return Received'
    map { $_->discard_changes->shipment_item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED } ) } @{ $retitems };

    # just change the expected results in the Bought and
    # Return part of the previous shipment item tests
    $ship_item_statuses{Bought}{items_bought}   = +$retitem_count;
    $ship_item_statuses{Bought}{items_returned} = +0;
    $ship_item_statuses{Return}{items_bought}   = +$retitem_count;
    $ship_item_statuses{Return}{items_returned} = +0;

    # re-reun the shipment item status tests with new expectations
    _run_cv_funcs_status_tests( \%ship_item_statuses, \%initial_values, \@func_params );


    note "TEST with one Return Item as type 'Return' and the others as 'Exchange'";
    # this tests when a return as return items of different types,
    # the Returned value should only increase by 1 if the status is
    # a return status (Return Received & Returned) all other items
    # as they are Exchanges should increase the Bought value

    # update one Return Item as a Type 'Return'
    $retitems->[0]->discard_changes->update( { return_type_id => $RETURN_TYPE__RETURN } );

    # change expectations
    $ship_item_statuses{Bought}{items_bought}   = +$retitem_count;
    $ship_item_statuses{Bought}{items_returned} = +0;
    $ship_item_statuses{Return}{items_bought}   = +( $retitem_count - 1 );
    $ship_item_statuses{Return}{items_returned} = +1;

    # re-reun the shipment item status tests with new expectations
    _run_cv_funcs_status_tests( \%ship_item_statuses, \%initial_values, \@func_params );

    # reset the data for more tests that follow
    $return->discard_changes->return_items->update( { return_type_id => $RETURN_TYPE__RETURN } );
    map { $_->discard_changes->shipment_item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__RETURNED } ) } @{ $retitems };

    note "TEST having more that one Shipment per Order still only increases the order count by 1";

    # create a Re-Shipment, get existing data
    my %ship_data       = $shipment->discard_changes->get_columns;
    my %ship_item_data  = $shipment->shipment_items->first->get_columns;

    # get rid of id's
    delete $ship_data{id};
    delete $ship_item_data{id};
    delete $ship_item_data{shipment_id};
    # change some stuff
    $ship_data{shipment_class_id}           = $SHIPMENT_CLASS__RE_DASH_SHIPMENT;
    $ship_item_data{shipment_item_status_id}= $SHIPMENT_ITEM_STATUS__DISPATCHED;

    # create the new records
    my $new_ship    = $schema->resultset('Public::Shipment')->create( \%ship_data );
    $new_ship->create_related( 'shipment_items', \%ship_item_data );
    $new_ship->create_related( 'link_orders__shipment', { orders_id => $order->id } );

    # now check that the order count is still only 1 bigger
    cmp_ok( get_cv_order_count( @func_params ), '==', ( $initial_values{order_count} + 1 ),
                                    "even with 2 Shipments for an Order, Order Count Still only increases by one: ".( $initial_values{order_count} + 1 ) );

    # cancel the new shipment, so it shouldn't figure any more in any further tests
    $new_ship->update( { shipment_status_id => $SHIPMENT_STATUS__CANCELLED } );
    $new_ship->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED } );

    return;
}

# run the different type of status tests for '_test_cv_funcs_with_statuses' & '_test_cv_spend_func_with_statuses'
# this updates a record with each status passed to it and then compares values to see if what was expected is
# what was returned
sub _run_cv_funcs_status_tests {
    my ( $tests, $initial_values, $func_params ) = @_;

    my $config          = delete $tests->{config};
    my $label           = $config->{label};
    my $id_name_column  = $config->{id_name_column};
    my $update_func     = $config->{_update_func};

    foreach my $test_label ( sort keys %{ $tests } ) {
        note "testing different '$label' for '$test_label' items";
        my $test    = $tests->{ $test_label };
        my $ids     = delete $test->{ids};
        my $record;
        if ( exists( $config->{test_spend_only} ) ) {
            $record  = $test->{rec_to_update},
        }

        # see if a 'get_cv_order_count' test is required
        my $test_ordcnt = ( exists( $test->{order_count} ) ? delete $test->{order_count} : undef );

        foreach my $obj ( @{ $ids } ) {
            if ( exists( $config->{test_spend_only} ) ) {
                # if we are only testing 'get_cv_spend' only

                # get the inital values used to compare with later
                my $initial_spend   = $initial_values->{spend};

                # update the id's
                $update_func->( $record, $obj->id );

                # work out if it's gross or returns to test against, then add
                # it too the appropriate value to compare against
                my $spend_type  = ( exists( $test->{gross} ) ? 'gross' : 'returns' );
                my $cmp_value   = $initial_spend->{ $spend_type }{value} + $test->{ $spend_type };

                my ( $tmp ) = grep { $_->{currency} eq $initial_values->{currency} } @{ get_cv_spend( @{ $func_params } ) };
                cmp_ok( $tmp->{ $spend_type }{value}, '==', _fmt_value( $cmp_value ),
                            "$label Id: ".$obj->id." - ".$obj->$id_name_column.", '$spend_type' value is as expected: $cmp_value" );

                # compare the net value
                my $net_value   = (
                                    $spend_type eq 'gross'
                                    ? ( $cmp_value - $tmp->{returns}{value} )
                                    : ( $tmp->{gross}{value} - $cmp_value )
                                  );
                cmp_ok( $tmp->{net}{value}, '==', _fmt_value( $net_value ),
                                            "'net' value is as expected: $net_value" );
            }
            else {
                # get the inital values used to compare with later
                my $initial_rates   = $initial_values->{ret_rate};
                my $initial_ordcnt  = $initial_values->{order_count};

                # update the id's
                $update_func->( $obj->id );

                # copy the initial values and add the differences that should have happened so it can be compared
                my %cmp_rate    = map { $_ => $initial_rates->{$_} + $test->{$_} } keys %{ $test };
                $cmp_rate{unit_return_rate} = _pcnt( $cmp_rate{items_returned}, $cmp_rate{total_items} );

                # check return_rate
                my $tmp = get_cv_return_rate( @{ $func_params } );
                is_deeply( $tmp, \%cmp_rate, "$label Id: ".$obj->id." - ".$obj->$id_name_column.", values are as expected for '$label'" );

                if ( defined $test_ordcnt ) {
                    # check order count
                    $tmp    = get_cv_order_count( @{ $func_params } );
                    cmp_ok( $tmp, '==', ( $initial_ordcnt + $test_ordcnt ), "Order Count is as expected for '$label'" );
                }
            }
        }
        # put back the ids & order count
        $test->{ids}        = $ids;
        $test->{order_count}= $test_ordcnt      if ( defined $test_ordcnt );
        if ( exists( $config->{test_spend_only} ) ) {
            $test->{rec_to_update}  = $record;
        }
    }

    # put the config back
    $tests->{config}    = $config;

    return;
}

# check the make-up of what is returned by 'get_cv_return_rate'
sub _check_get_cv_return_rate_firsttime {
    my ( $retval, $order )  = @_;

    note "checking what was returned by 'get_cv_return_rate' as we've called it for the first time";

    my $shipment    = $order->{order}->get_standard_class_shipment;

    my %expected    = (
            total_items => $shipment->shipment_items->count,
            items_bought => $shipment->shipment_items->count,
            items_returned => 0,
            unit_return_rate => '0.00%',
        );

    isa_ok( $retval, 'HASH', "'get_cv_return_rate' returned a Hash" );
    is_deeply( $retval, \%expected, "contents of HASH as expected" );

    return;
}

# check the make-up of what is returned by 'get_cv_spend'
sub _check_get_cv_spend_firsttime {
    my ( $retval, $order )  = @_;

    note "checking what was returned by 'get_cv_spend' as we've called it for the first time";

    my $currency    = $order->{order}->currency;
    my $curr_glyph  = get_currency_glyph( $currency->result_source->schema->storage->dbh, $currency->currency );
    my $renum       = $order->{order}->payment_renumerations->first;
    my $total       = $order->{total};

    my %expected    = (
            gross => {
                value => sprintf( "%0.3f", $total, ),
                formatted => format_currency( $total, 2, 1 ),
            },
            returns => {
                value => '0.000',
                formatted => '0.00',
            },
            net => {
                value => sprintf( "%0.3f", $total, ),
                formatted => format_currency( $total, 2, 1 ),
            },
            currency => $currency->currency,
            html_entity => $curr_glyph,
        );

    isa_ok( $retval, 'ARRAY', "'get_cv_spend' returned an Array" );
    cmp_ok( @{ $retval }, '==', 1, "there is only 1 element in the array" );
    isa_ok( my $tmp = $retval->[0], 'HASH', "1st element" );
    is_deeply( $tmp, \%expected, "1st element HASH is as expected" );

    return;
}

# set-up currencies used in the tests
sub _setup_currency {
    my $schema      = shift;

    my @currency    = $schema->resultset('Public::Currency')->search(
                                                            {
                                                                'me.id' => { 'IN' => [ $CURRENCY__GBP, $CURRENCY__EUR ] },
                                                            },
                                                            {
                                                                order_by => 'me.currency',
                                                            }
                                                        )->all;

    return @currency;
}

# set-up date ranges for tests
sub _setup_dates {
    my %dates;

    # date range should be '23:59:59' yesterday to '00:00:00' one year back from yestrday
    my $now         = $schema->db_now;
    my $yesterday   = $now - DateTime::Duration->new( days => 1 );

    # one year back plus one day forward
    my $period      = DateTime::Duration->new( years => 1 ) - DateTime::Duration->new( days => 1 );

    # start at the beginning of the day and end at the end of the day
    my $start       = ( $yesterday - $period )->set( hour => 0, minute => 0, second => 0 );
    my $end         = $yesterday->set( hour => 23, minute => 59, second => 59 );

    my $middle      = $start + DateTime::Duration->new( days => 147 );       # date used somewhere in the middle
    # set dates just outside the range
    my $before      = $start - DateTime::Duration->new( seconds => 1 );      # date just outside before the range
    my $after       = $end + DateTime::Duration->new( seconds => 1 );        # date just outside after the range

    %dates  = (
            now     => $now,
            start   => $start,
            end     => $end,
            middle  => $middle,
            before  => $before,
            after   => $after,
        );
    note "Dates Setup:";
    foreach my $date ( sort keys %dates ) {
        note sprintf( "%-6s - %s", $date, $dates{$date} );
    }

    return \%dates;
}

# create a test order, returns a hash containing the order, renumeration, shipment & order total
sub _create_test_order {
    my ( $customer, $order_date, $num_pids, $currency ) = @_;

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
            how_many    => $num_pids,
            channel     => $customer->channel,
            dont_ensure_stock => 1,
    } );

    my $base    = {
            customer_id => $customer->id,
            date => $order_date,
            shipping_charge => 10,
            create_renumerations => 1,
            currency_id => $currency->id,
        };

    my ( $order, $order_hash )  = Test::XTracker::Data->create_db_order( {
            pids => $pids,
            base => $base,
            attrs => [ map { price => $_ * 100, tax => 5.20, duty => 15.15 }, ( 1..$num_pids ) ],
        } );

    ok($order, 'created order Id/Nr: '.$order->id.'/'.$order->order_nr.', Date: '.$order->date );

    # create renumeration items
    my $shipment    = $order->get_standard_class_shipment;
    my $renumeration= $shipment->renumerations->first;
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'me.id' } )->all;
    foreach my $si ( @ship_items ) {
        $si->create_related( 'renumeration_items', {
                                        unit_price  => $si->unit_price,
                                        tax         => $si->tax,
                                        duty        => $si->duty,
                                        renumeration_id => $renumeration->id,
                                } );
    }
    # update the tenders with the grand total for the renumeration
    $order->tenders->first->update( { value => $renumeration->grand_total } );

    return {
            order   => $order,
            renum   => $renumeration,
            shipment=> $shipment,
            items   => \@ship_items,
            total   => _renum_total( $renumeration ),
        };
}

# create a return for an order
sub _create_test_return {
    my ( $schema, $order, $type, $num_items )   = @_;

    my $return;

    my $domain = Test::XTracker::Data->returns_domain_using_dump_dir();

    my $items   = $order->{items};
    my $retitems;
    my $count   = 0;

    foreach my $idx ( 0..$#{ $items } ) {
        if ( $items->[$idx]->discard_changes->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__DISPATCHED ) {
            # can't return it if it isn't 'Dispatched'
            next;
        }
        # populate Return Item hash used in returning items
        $retitems->{ $items->[$idx]->id } = {
                        type    => 'Return',
                        reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                        full_refund => 1,
                    };
        # have we got enough
        last        if ( ++$count >= $num_items );
    }

    $return = $domain->create( {
                    operator_id => $APPLICATION_OPERATOR_ID,
                    shipment_id => $order->{shipment}->id,
                    pickup => 0,
                    refund_type_id => ( $type eq 'Card' ? $RENUMERATION_TYPE__CARD_REFUND : $RENUMERATION_TYPE__STORE_CREDIT ),
                    return_items => $retitems,
                } );
    ok($return, 'created return Id/RMA: '.$return->id.'/'.$return->rma_number." - returned $num_items items");

    # update the renumeration to be completed
    my $renum   = $return->renumerations->first;
    $renum->update_status( $RENUMERATION_STATUS__COMPLETED, $APPLICATION_OPERATOR_ID );
    $return->update( { return_status_id => $RETURN_STATUS__COMPLETE } );

    # update the return items and their shipment items statuses accordingly
    my @items   = $return->return_items->search( {}, { order_by => 'me.id' } )->all;
    foreach my $item ( @items ) {
        $item->update( { return_item_status_id => $RETURN_ITEM_STATUS__PASSED_QC,  } );
        $item->shipment_item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__RETURNED } );
    }

    return {
            return  => $return,
            renum   => $renum,
            items   => \@items,
            total   => _renum_total( $renum ),
        };
}

# work out the total of a renumeration as used by Customer Value
# this is the total as far as this Customer Value is concerned
# and not the usual Grand Total where Store Credit is taken off
sub _renum_total {
    my $obj     = shift;

    my $renum;

    # work out what type of object has been passed
    if ( ref( $obj ) =~ m/Public::Orders$/ ) {
        $renum  = $obj->payment_renumerations->first;
    }
    elsif ( ref( $obj ) =~ m/Public::Renumeration$/ ) {
        $renum  = $obj;
    }
    else {
        warn( '$obj is not an Order or Renumeration: '.ref( $obj ) );
        return 0;
    }

    my $total   =  $renum->total_value + $renum->shipping + $renum->gift_voucher;       # gift_voucher will be negative
                                                                                        # and so will come off the total

    return _fmt_value( $total );      # because these seems to work when comparing numbers later on
}

# work out the percentage the first agurment is of the second
sub _pcnt {
    my ( $item, $total )    = @_;

    my $pcnt    = sprintf( "%0.2f%%", ( ( $item / $total ) * 100 ) );
    return $pcnt;
}

# format a value to be 3 decimal points because that
# work in later comparisons with database values
sub _fmt_value {
    return sprintf( "%0.3f", shift );      # because these seems to work when comparing numbers later on
}

