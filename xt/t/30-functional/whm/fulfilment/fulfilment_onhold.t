#!/usr/bin/env perl
# vim: set ts=4 sw=4 sts=4:

=head1 NAME

fulfilment_onhold.t - Test putting a shipment on hold

=head1 DESCRIPTION

This tests the list on the Fulfilment -> OnHold page displays the correct
columns for the 'Incomplete Picks' & 'Stock Discrepancies' tables and also
highlights any Premier Shipments.

This test loops through shipments on hold for different reasons: Held
(specifically due to an incomplete address), incomplete picks and stock
discrepancies.

Create a domestic shipment with a status of I<Selected>, set its customer's
category to I<None>, and put it on hold.

Go to the Fulfilment/On Hold page, and check that the columns match the hold
reason, and that the language is the default one.

Change the language to French, refresh the page and check the language was
updated.

Only continue for tests for shipment that aren't Held (i.e. incomplete picks
and stock discrepancies).

Check that the value for the customer category column is empty (as the category
is I<None>). Check that the order number is displayed, that it is a link, and
that we can see the shipment total. Make sure non-premier shipments aren't
highlighted.

Change the category of the customer to something else, and make the shipment
premier. Check that the category is now displayed and that the shipment is
highlighted.

#TAGS shouldbecando fulfilment holdshipment whm

=head1 SEE ALSO

CANDO-142: Check the Fulfilment -> OnHold page has the new Columns displayed

=cut

use NAP::policy "tt",     'test';

use DateTime::Duration;

use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Database::Currency        qw( get_currency_glyph );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw (
                                            :authorisation_level
                                            :customer_category
                                            :shipment_status
                                            :shipment_type
                                            :shipment_hold_reason
                                        );

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
    ],
);

# create an Order
my $orddetails  = $framework->flow_db__fulfilment__create_order_selected(
    channel  => Test::XTracker::Data->channel_for_nap,
    products => 2,
);
my $order       = $orddetails->{order_object};
my $shipment    = $orddetails->{shipment_object};
my $customer    = $orddetails->{customer_object};

my $currency_glyph  = get_currency_glyph( $schema->storage->dbh, $order->currency->currency );
my $shipment_total  = sprintf("%0.2f",
                                        $shipment->shipping_charge
                                        + $shipment->total_price
                                        + $shipment->total_tax
                                        + $shipment->total_duty
                            );
my $channel_name    = uc( $order->channel->name );
my $cust_category   = $schema->resultset('Public::CustomerCategory')
                                ->search( { id => { '!=' => $CUSTOMER_CATEGORY__NONE } } )
                                    ->first;
my $default_language= $schema->resultset('Public::Language')
                                ->get_default_language_preference
                                    ->description;


# get a release date sometime into the future
my $release_date= $shipment->date + DateTime::Duration->new( days => 4 );
my %release_date_splitup = (
                    releaseYear => $release_date->year,
                    releaseMonth => $release_date->month,
                    releaseDay => $release_date->day,
                    releaseHour => $release_date->hour,
                    releaseMinute => $release_date->minute,
                );


$framework->login_with_permissions( {
    perms => {
        $AUTHORISATION_LEVEL__OPERATOR => [
            'Fulfilment/On Hold',
        ]
    }
} );


# different Hold Reasons to test for
my %tests   = (
        'Held Shipments' => {
            params  => {
                reason  => $SHIPMENT_HOLD_REASON__INCOMPLETE_ADDRESS,
                %release_date_splitup,
            },
            ship_id_column => 'Shipment',
            expected_cols => [
                'Shipment',
                'CPL',
                'Shipment Date',
                'Hold Date',
                'Release Date',
                'Reason',
                'Held By',
            ],
        },
        'Incomplete Picks' => {
            params  => {
                reason  => $SHIPMENT_HOLD_REASON__INCOMPLETE_PICK,
                %release_date_splitup,
            },
            ship_id_column => 'Shipment',
            expected_cols => [
                'Shipment',
                'Order',
                'CPL',
                'Category',
                'Shipment Total',
                'Shipment Date',
                'Hold Date',
                'Selection Date',
            ],
        },
        'Stock Discrepancies' => {
            params  => {
                reason  => $SHIPMENT_HOLD_REASON__STOCK_DISCREPANCY,
                %release_date_splitup,
            },
            ship_id_column => 'Shipment',
            expected_cols => [
                'Shipment',
                'Order',
                'CPL',
                'Category',
                'Shipment Total',
                'Shipment Date',
                'Hold Date',
                'Selection Date',
            ],
        },
    );

foreach my $test_label ( sort keys %tests ) {
    note "testing '$test_label' table";
    my $test    = $tests{ $test_label };

    # clear the Customer's Language Preference
    $customer->customer_attribute->delete       if ( $customer->discard_changes->customer_attribute );

    # set the Customer's Category to be 'None'
    $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );

    # update the Shipment Type to be Non-Premier
    $shipment->update( { shipment_type_id => $SHIPMENT_TYPE__DOMESTIC } );

    # put the shipment on hold with the correct reason
    $shipment->put_on_hold( {
                        status_id   => $SHIPMENT_STATUS__HOLD,
                        operator_id => $APPLICATION_OPERATOR_ID,
                        norelease   => 0,
                        %{ $test->{params} },
                    } );

    # goto the 'Fulfilment->On Hold' page
    $framework->flow_mech__fulfilment__on_hold;

    # get the Table on the page for the Sales Channel
    # of the Shipment that we want to look at
    my $page_data   = $framework->mech->as_data;
    my $list        = $page_data->{shipments}{ $channel_name }{ $test_label };

    my $row = _find_shipment_in_list( $list, $shipment->id, $test->{ship_id_column} );
    ok( defined $row, "found a row with the Shipment in '$test_label' table" );
    is_deeply( [ sort keys %{ $row } ], [ sort @{ $test->{expected_cols} } ], "found all expected columns in the row for the Shipment" );

    # checking for the Default Langauge
    is( $row->{CPL}, $default_language, "Default Language Preference is shown in the table: '${default_language}'" );

    # now set the Language to be 'French'
    $customer->set_language_preference('FR');

    # goto the 'Fulfilment->On Hold' page again
    $framework->flow_mech__fulfilment__on_hold;
    $page_data  = $framework->mech->as_data;
    $list       = $page_data->{shipments}{ $channel_name }{ $test_label };
    $row        = _find_shipment_in_list( $list, $shipment->id, $test->{ship_id_column} );
    is( $row->{CPL}, 'French', "Having set the Language Preference it is now shown in the table: 'French'" );

    # if we're looking at any other table than 'Held Shipments'
    # then test that Customer Categories are shown and Premier
    # Shipments are highlighted amongst other things
    if ( $test_label ne 'Held Shipments' ) {

        # get this for the RegEx late on
        my $order_id    = $order->id;

        # as Customer Category is 'None' the
        # corresponding column should be empty
        is( $row->{'Category'}, "", "no Customer Category shown for 'None' category" );

        is( $row->{'Order'}{value}, $order->order_nr, "Order Number is displayed: ".$order->order_nr );
        like( $row->{'Order'}{url}, qr{/OrderView\?order_id=$order_id}, "Order Number is also a link: ".$row->{'Order'}{url} );
        # make it a like because the currency symbol will be in front
        like( $row->{'Shipment Total'}, qr{$shipment_total$}, "shipment total is displayed: ".$shipment_total );

        # make sure Non-Premier Shipments are not Highlighted
        my $highlight   = $framework->mech->find_xpath( "//tr/td[a='".$shipment->id."']" )->get_node;
        ok( !defined $highlight->attr('class') || $highlight->attr('class') ne "highlight",
                                "Non-Premier Shipment is not Highlighted" );

        # update the Customer to being a different Category
        $customer->update( { category_id => $cust_category->id } );
        # update the Shipment to being Premier
        $shipment->update( { shipment_type_id => $SHIPMENT_TYPE__PREMIER } );
        # get the page again
        $framework->flow_mech__fulfilment__on_hold;

        $page_data  = $framework->mech->as_data;
        $list       = $page_data->{shipments}{ $channel_name }{ $test_label };
        $row        = _find_shipment_in_list( $list, $shipment->id, $test->{ship_id_column} );
        ok( defined $row, "still found a row with the Shipment in '$test_label' table" );

        # as Customer Category is now something other than 'None'
        # the corresponding column should now show the category
        is( $row->{'Category'}, $cust_category->category, "Customer Category is now displayed: ". $cust_category->category );

        # check Premier Shipments are now Highlighted
        $highlight  = $framework->mech->find_xpath( "//tr/td[a='".$shipment->id."']" )->get_node;
        is( $highlight->attr('class'), "highlight", "Premier Shipment ".$shipment->id." is now Highlighted" );
    }
}

done_testing();

#-----------------------------------------------------------------

# find a shipment in the list on the page
sub _find_shipment_in_list {
    my ( $list, $ship_id, $ship_id_column ) = @_;

    my $found;

    foreach my $row ( @{ $list } ) {
        if ( $row->{ $ship_id_column }{value} == $ship_id ) {
            $found  = $row;
            last;
        }
    }

    return $found;
}

