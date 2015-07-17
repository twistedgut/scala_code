#!perl

=head1 NAME

order_search.t - Test the order search module

=head1 DESCRIPTION

Verfies that the various searches possible based upon order data return
the expected data.

Note this test only uses Mech/Flow in order to set up data. Could/Should
be doing this without using the web interface.

#TAGS search loops misc

=cut

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XT::Flow;

use XTracker::Database qw(:common);
use XTracker::Constants::FromDB qw(:authorisation_level);
use XTracker::Order::CustomerCare::OrderSearch::Search qw/find_orders/;

use XTracker::DBEncode  qw( encode_it decode_it );

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::Role::DBSamples',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::PrintStation',
    ],
);

my $schema = $framework->schema;
my $dbh = $schema->storage->dbh;

$framework->clear_sticky_pages;

#-------------------------------------------------------------------------------

# Simple Order Searches
# - An initial order with no subsequent operations will do
note "Simple Order Searches";

my ($simple_order) = odata('flow_db__fulfilment__create_order');

my $sample_shipment = $framework->db__samples__create_shipment;

my ( $pre_order, $pre_order_order ) = Test::XTracker::Data::PreOrder->create_part_exported_pre_order();
# Cheat - link the pre_order to the existing order
$pre_order->link_orders__pre_orders->update( { orders_id => $simple_order->{order_object}->id } );

my $simple_order_searches = _build_simple_order_search_tests(
    $simple_order,
    [ $simple_order->{order_object}->discard_changes ],
);

_run_order_search_tests( $simple_order, [
    @$simple_order_searches,
    # Add a sample shipment test - we are testing just one basic case - a todo
    # would be to add tests for all cases that can return sample shipments
    [ 'shipment_id', $sample_shipment->id, 'Found sample shipment', undef, [$sample_shipment->id] ],
]);

#-------------------------------------------------------------------------------

# Dispatched Order Searches
# - Data present and searchable post-dispatch
note "Dispatched Order Searches";

my ($dispatched_order) = odata('flow_db__fulfilment__create_order_picked');
# Now link this order to the pre_order so we can cheat again
$pre_order->link_orders__pre_orders->update( { orders_id => $dispatched_order->{order_object}->id } );

$framework->login_with_permissions({
    dept => 'Distribution Management',
    perms => { $AUTHORISATION_LEVEL__OPERATOR => [
        'Fulfilment/Packing',
        'Fulfilment/Airwaybill',
        'Fulfilment/Dispatch',
        'Customer Care/Order Search',
        'Customer Care/Customer Search',
    ]}
});

$framework
  ->mech__fulfilment__set_packing_station( $dispatched_order->{channel}->id )
  ->flow_mech__fulfilment__packing
  ->flow_mech__fulfilment__packing_submit( $dispatched_order->{shipment_nr} )
  ->flow_mech__fulfilment__packing_checkshipment_submit;

foreach my $sku ( @{ $dispatched_order->{skus} } ) {
    $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $sku );
}

$framework
  ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
      inner => 2,
      outer => 12,
     );

# Make sure we have a printer selected for the awb section
$framework->flow_mech__select_printer_station({
    section    => 'Fulfilment',
    subsection => 'Airwaybill',
    channel_id => $dispatched_order->{channel}->id,
})->flow_mech__select_printer_station_submit;

$framework
  ->flow_mech__fulfilment__airwaybill
  ->flow_mech__fulfilment__airwaybill_shipment_id( { shipment_id => $dispatched_order->{shipment_nr} })
  ->flow_mech__fulfilment__airwaybill_airwaybills( { outward => '23423497234',
                                                     return  => '45345345' });
$framework
  ->flow_mech__fulfilment__dispatch
  ->flow_mech__fulfilment__dispatch_shipment($dispatched_order->{shipment_nr});

my $products = [ map { { sku           => $_,
                         selected      => 1,
                         return_reason => 'Price' }; }
                     @{$dispatched_order->{skus}} ];

$framework
  ->flow_mech__customercare__orderview( $dispatched_order->{id} )
  ->flow_mech__customercare__view_returns()
  ->flow_mech__customercare__view_returns_create_return()
  ->flow_mech__customercare__view_returns_create_return_data( { products => $products } )
  ->flow_mech__customercare__view_returns_create_return_submit( { send_email => 'no' } );

my ($db_order_data) = db_order($dispatched_order->{id});


# get the latest Airway Bills to search for
my $disp_shipment   = $dispatched_order->{shipment_object}->discard_changes;
$dispatched_order->{outward_airwaybill} = $disp_shipment->outward_airway_bill;
$dispatched_order->{return_airwaybill}  = $disp_shipment->return_airway_bill;

# build tests
my $simple_search_tests     = _build_simple_order_search_tests(
    $dispatched_order,
    [ $dispatched_order->{order_object}->discard_changes ],
);
my $dispatched_search_tests = _build_dispatched_order_search_tests(
    $db_order_data,
    [ $db_order_data->{order_object}->discard_changes ],
);

_run_order_search_tests(
    $dispatched_order,
    [ @{ $simple_search_tests }, @{ $dispatched_search_tests } ],
);

#-------------------------------------------------------------------------------

# Customer Name Order Searches
# - Searching both Order Address & Customer tables
note "Customer Name Order Searches";

$simple_order->{order_object}->discard_changes;
$dispatched_order->{order_object}->discard_changes;

# fix the Data so that Customer & Order Address name fields are different on each Order
$simple_order->{order_object}->customer->update(            { first_name => 'fname_one', last_name => 'lname_one' } );
$simple_order->{order_object}->invoice_address->update(     { first_name => 'fname_two', last_name => 'lname_two' } );
$dispatched_order->{order_object}->customer->update(        { first_name => 'fname_two', last_name => 'lname_two' } );
$dispatched_order->{order_object}->invoice_address->update( { first_name => 'fname_one', last_name => 'lname_one' } );

my $customer_searches_one = _build_customer_search_tests(
    { fname => 'fname_one', lname => 'lname_one' },
    [ $simple_order->{order_object}, $dispatched_order->{order_object} ],
);
my $customer_searches_two = _build_customer_search_tests(
    { fname => 'fname_two', lname => 'lname_two' },
    [ $simple_order->{order_object}, $dispatched_order->{order_object} ],
);

_run_order_search_tests(
    { channel => $simple_order->{channel} },
    [
        @{ $customer_searches_one },
        @{ $customer_searches_two },
    ],
);

#-------------------------------------------------------------------------------

done_testing;

#-------------------------------------------------------------------------------

sub odata {

    my $flow_method = shift;
    my $order_data  = {};

    my ($channel, $pids) = Test::XTracker::Data->grab_products({ how_many => 1 });

    # force the Order to be Created using New Customer & Order Address records, make sure address has a postcode
    my $new_address = Test::XTracker::Data->create_order_address_in( 'current_dc', { postcode => 'TE5 1ST' } );
    my $new_customer= Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );

    my $order = $framework->$flow_method(
        channel  => $channel,
        products => $pids,
        customer => $new_customer,
        address  => $new_address,
    );
    $order_data->{order_object} = $order->{order_object};

    # order data for comparison
    $order_data->{channel}   = $channel;
    $order_data->{pids}      = $pids;
    $order_data->{id}        = $order->{'order_object'}->id;
    $order_data->{order_nr}  = $order->{'order_object'}->order_nr;
    $order_data->{basket_nr} = $order->{'order_object'}->basket_nr;
    $order_data->{odate}     = $order->{'order_object'}->date->ymd;

    my $shipment               = $order->{'order_object'}->shipments->first;

    $order_data->{shipment_object} = $shipment;

    $order_data->{skus}        = [ map { $_->sku } $shipment->variants->all ];
    $order_data->{shipment_nr} = $shipment->id;
    $order_data->{pcode}       = $shipment->shipment_address->postcode;
    $order_data->{sadd_ln1}    = $shipment->shipment_address->address_line_1;

    $order_data->{outward_airwaybill} = $shipment->outward_airway_bill;
    $order_data->{return_airwaybill}  = $shipment->return_airway_bill;

    $order_data->{email}    = $order->{'order_object'}->email;
    $order_data->{cust_nr}  = $order->{'order_object'}->customer->is_customer_number;
    $order_data->{fname}    = $order->{'order_object'}->customer->first_name;
    $order_data->{lname}    = $order->{'order_object'}->customer->last_name;
    $order_data->{telno}    = $order->{'order_object'}->telephone;
    $order_data->{badd_ln1} = $order->{'order_object'}->invoice_address->address_line_1;

    note "shipment $order->{'shipment_id'} created";

    return ($order_data);
}

sub _order_search_test {

    my ( $dbh, $args )  = @_;

    my $search_type       = $args->{search_type};
    my $search_terms      = $args->{search_terms};
    my $test_name         = $args->{test_name};
    my $orders_to_find    = $args->{orders_to_find};
    my $shipments_to_find = $args->{shipments_to_find};
    my $channel           = $args->{channel};

    return sub {
        my $args = { search_type   => $search_type,
                     search_terms  => $search_terms,
                     sales_channel => $channel->name,
                   };

        if ( ref $search_terms eq 'HASH' && exists $search_terms->{date} ) {
            $args->{date_type} = $search_terms->{date_type};
            $args->{date} = $search_terms->{date};
        }

        my $results = find_orders( $dbh, $args);

        cmp_ok( @$results, '>=', 1, $test_name );

        # This is a bit of a hack, considering the name of this 'test' is
        # _order_search_test, but it allows me to use the existing
        # infrastructure without rewriting it
        if ( $shipments_to_find && @$shipments_to_find ) {
            my %got_shipment_ids = map { $_->{id} => 1 } @$results;
            ok($got_shipment_ids{$_}, "found shipment $_ for type '$search_type' and term '$search_terms'")
                for sort { $a <=> $b } @$shipments_to_find;
        }

        if ( $orders_to_find ) {
            my @got_order_ids   = map { $_->{order_id} } @$results;
            my @expect_order_ids= map { $_->id } @{ $orders_to_find };
            cmp_deeply(
                \@got_order_ids,
                superbagof( @expect_order_ids ),
                "and Expected Orders were amongst those found",
            ) or diag "Search failed using: Search Type: '${search_type}' and Terms: " . encode_it( p( $search_terms ) ) . "\n"
                                        . "     Got Order Ids: " . p( @got_order_ids ) . "\n"
                                        . "Expected Order Ids: " . p( @expect_order_ids ) . "\n"
                                        . "       Got Results: " . p( $results );
        }
    }
}

sub _run_order_search_tests {
    my ( $order, $test_list ) = @_;

    foreach my $test ( @{ $test_list } ) {
        _order_search_test( $dbh, {
            search_type       => $test->[0],
            search_terms      => $test->[1],
            test_name         => $test->[2],
            orders_to_find    => $test->[3],
            shipments_to_find => $test->[4],
            channel           => $order->{channel},
        } )->();
    }
}

sub db_order {
    my $order_id   = shift;
    my %order_data = ();

    my $db_order
      = $schema->resultset('Public::Orders')->find( $order_id );

    $order_data{order_object}  = $db_order;
    $order_data{shipment}      = $db_order->shipments->first;
    $order_data{invoice_nr}    = $order_data{shipment}->get_invoices->first->invoice_nr;
    $order_data{rma_nr}        = $order_data{shipment}->returns->first->rma_number;
    $order_data{dispatch_date} = $order_data{shipment}->dispatched_date->ymd;
    $order_data{shipment_box}  = $order_data{shipment}->shipment_boxes->first->id;
    $order_data{pre_order_id}  = $pre_order->id;

    return \%order_data;
}


sub _build_simple_order_search_tests {
    my ( $order, $must_find_orders ) = @_;

    return [
        [ 'email',            $order->{email},                   'At least one order by email',                         $must_find_orders ],
        [ 'customer_name',    { first_name => $order->{fname} }, 'At least one order by first name',                    $must_find_orders ],
        [ 'customer_name',    { last_name  => $order->{lname} }, 'At least one order by last name',                     $must_find_orders ],
        [ 'customer_name',    { first_name => $order->{fname},
                                last_name  => $order->{lname} }, 'At least one order by first and last name',           $must_find_orders ],
        [ 'customer_number',  $order->{cust_nr},                 'At least one order matching customer number',         $must_find_orders ],
        [ 'order_number',     $order->{order_nr},                'At least one order matching order number',            $must_find_orders ],
        [ 'basket_number',    $order->{basket_nr},               'At least one order matching basket number',           $must_find_orders ],
        [ 'shipment_id',      $order->{shipment_nr},             'At least one order matching shipment number',         $must_find_orders ],
        [ 'sku',              $order->{skus}->[0],               'At least one order matching sku',                     $must_find_orders ],
        [ 'telephone_number', $order->{telno},                   'At least one order matching telephone number',        $must_find_orders ],
        [ 'postcode',         $order->{pcode},                   'At least one order matching postcode',                $must_find_orders ],
        [ 'billing_address',  $order->{badd_ln1},                'At least one order matching billing address line 1',  $must_find_orders ],
        [ 'shipping_address', $order->{sadd_ln1},                'At least one order matching shipping address line 1', $must_find_orders ],
        [ 'by_date',          { date      => $order->{odate},
                                date_type => 'order' },          'At least one order matching date',                    $must_find_orders ],
        [ 'airwaybill',       $order->{outward_airwaybill},      'At least one order by outward airwaybill',            $must_find_orders ],
        [ 'airwaybill',       $order->{return_airwaybill},       'At least one order by return airwaybill',             $must_find_orders ],
        [ 'pre_order_number', $pre_order->id,                    'At least one order by pre-order number',              $must_find_orders ],
     ];
};

sub _build_dispatched_order_search_tests {
    my ( $db_order_data, $must_find_orders ) = @_;

    return [
        [ 'by_date',        { date      => $db_order_data->{dispatch_date},
                              date_type => 'dispatch' },    'At least one order matching date',       $must_find_orders ],
        [ 'box_id',         $db_order_data->{shipment_box}, 'At least one order matching box id',     $must_find_orders ],
        [ 'invoice_number', $db_order_data->{invoice_nr},   'At least one order matching invoice_nr', $must_find_orders ],
        [ 'rma_number',     $db_order_data->{rma_nr},       'At least one order matching rma number', $must_find_orders ],
    ];
};

sub _build_customer_search_tests {
    my ( $order, $must_find_orders ) = @_;

    return [
        [ 'customer_name', { customer_name => $order->{lname} }, "At least one order found using 'customer_name'",   $must_find_orders ],
        [ 'customer_name', { first_name => $order->{fname} },    "At least one order found using First Name",        $must_find_orders ],
        [ 'customer_name', { last_name => $order->{lname} },     "At least one order found using Last Name",         $must_find_orders ],
        [ 'customer_name', { first_name => $order->{fname},
                             last_name => $order->{lname} },     "At least one order found using First & Last Name", $must_find_orders ],
    ];
}

