#!perl

=head1 NAME

quick_search.t - Test the QuickSearch module

=head1 DESCRIPTION

Verifies that access to QuickSearch is limited to those with the appropriate
permissions and that the _decode_quick_search function is able to determine
the correct search type based upon input to it.

#TAGS movetounit search todo misc loops

=cut

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::RunCondition    export => [ '$distribution_centre' ];

use Test::XT::Flow;
use Test::XTracker::Mock::WebServerLayer;

use XTracker::Handler;
use XTracker::Database qw( :common );
use XTracker::Constants::FromDB qw(:authorisation_level);
use XTracker::QuickSearch;

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::CustomerCare',
    ],
);

$framework->clear_sticky_pages;

#-------------------------------------------------------------------------------
# Test Authentication

$XTracker::Session::SESSION = {
    operator_id => $framework->schema->resultset('Public::Operator')->find( {
        username => 'it.god',
    } )->id,
    acl => { operator_roles => [] },
};
my $handler = XTracker::Handler->new(
    Test::XTracker::Mock::WebServerLayer->setup_mock
);

throws_ok(sub { XTracker::QuickSearch::_sub_section_auth(undef, 'Stock Control', 'Reservation') },
    qr/No handler passed/,
    'Fails sub section auth without handler data');
throws_ok(sub { XTracker::QuickSearch::_sub_section_auth($handler) },
    qr/No section/,
    'Fails without section name');
throws_ok(sub { XTracker::QuickSearch::_sub_section_auth($handler, 'Stock Control') },
    qr/No sub section/,
    'Fails without sub section name');
ok(! XTracker::QuickSearch::_sub_section_auth($handler, 'World', 'Domination'),
    'Fails when talking about world domination');

#-------------------------------------------------------------------------------

=head2 Quick Search Input Decoding

Test that quick search string input is decoded and dispatched to the correct
search handler

=cut

my @test_data = (
    ['c', '12345',                 '1 two 3 four 5',     'customer_number'],
    ['e', 'test@net-a-porter.com', 'a@example.com@a.com','email'],
    ['p', '12345',                 '1 two 3 four 5',     'product_id'],
    ['p', '12345-12345',           '1 2 3 four 5 - 123', 'product_id'],
    ['ok', '12345-12345',          '1 2 3 four 5 - 123', 'sku'],
    ['op', '12345-12345',          '1 2 3 four 5 - 123', 'sku'],
    ['x', '12345',                 '1 two 3 four 5',     'box_id'],
    ['o', '12345',                 '1 two 3 four 5',     'order_number'],
    ['pr', 'P12345',               '1 two 3 four 5',     'pre_order_number'],
    ['o', 'P12345',                '1 two 3 four 5',     'pre_order_number'],
    ['pr', '12345',                '1 two 3 four 5',     'pre_order_number'],
    ['s', '12345',                 '1 two 3 four 5',     'shipment_id'],
    ['t', '+12345',                '12325-six',          'telephone_number'],
    ['r', 'u12345-12345-a',        '12325',              'rma_number'],
    ['r', 'r238-8',                '12325',              'rma_number'],
    ['w', '12345abcde',            '',                   'airwaybill'],
    ['z', 'A test addr w1 234',    '',                   'postcode'],
    ['b', 'A test addr w1 234',    '',                   'billing_address'],
    ['a', 'A test addr w1 234',    '',                   'shipping_address'],
    ['',  'P12345',                '',                   'pre_order_number'],
    ['',  'test test',             '',                   'customer_name' ],
    ['f', 'test',                  '',                   'first_name' ],
    ['l', 'test',                  '',                   'last_name' ]
);

# only DC1 & DC2 currently Support Jimmy Choo Order Numbers
# and only DC1 & DC2 have Pre 2008 Hyphernated Order Numbers
if ( $distribution_centre =~ /^DC[12]$/ ) {
    push @test_data, [ 'o', 'JCHGB000123120', 'JC Order Number',    'order_number' ];
    push @test_data, [ 'o', '12345-6',        '1 2 3 four 5 hyp 6', 'order_number' ];
}
else {
    # when QS can't find the proper term it defaults to 'customer_name'
    # the 5th element in the following Arrays is what the Search Term
    # shouldn't be when doing the tests for a 'known-bad' search term
    push @test_data, [ 'o', 'JCHGB000123120', 'JC Order Number',    'customer_name', 'order_number' ];
    push @test_data, [ 'o', '12345-6',        '1 2 3 four 5 hyp 6', 'customer_name', 'order_number' ];
}


foreach my $td (@test_data){

    subtest "Prefix - '" . $td->[0] . "', Term - '" . $td->[1] . "'" => sub {
        # Test search is decoded correctly using single letter search key
        # and know-good search term
        my $search_string_ok = sprintf '%s %s ', $td->[0], $td->[1];
        my $decoded_ok = XTracker::QuickSearch::_decode_quick_search($search_string_ok);
        is($decoded_ok->{search_type}, $td->[3], 'Search type matched for '.$td->[3]);

        # Test search is not decoded using single letter search key
        # and know-bad search term
        my $search_string_fail = sprintf '%s %s ', $td->[0], $td->[2];
        my $decoded_fail = XTracker::QuickSearch::_decode_quick_search($search_string_fail);
        isnt($decoded_fail->{search_type}, ( $td->[4] // $td->[3] ), 'Search type match failed with bad terms for '.$td->[3]);
    };
}
#-------------------------------------------------------------------------------

note "Just test that Quick Search can take the basic search arguments";
$framework->login_with_permissions( {
    perms => {
        $AUTHORISATION_LEVEL__OPERATOR => [
            'Customer Care/Order Search',
            'Customer Care/Customer Search',
            'Stock Control/Inventory',
            'Stock Control/Reservation',
        ]
    },
    dept => 'Customer Care',
} );

# Make sure we have a page open
$framework->mech->get_ok('/Home');

# just do the basic searches, don't need to find anything just try
note "search for a Product";
$framework->flow_mech__customercare__quick_search( 'p 12345' );
note "search for an Order";
$framework->flow_mech__customercare__quick_search( 'o 12345' );
note "search for a Customer by name";
$framework->flow_mech__customercare__quick_search( 'c name' );
note "search for a Customer by Number";
$framework->flow_mech__customercare__quick_search( 'c 12345' );
note "search for a Pre-Order";
$framework->flow_mech__customercare__quick_search( 'pr 12345' );
note "search for a telephone number with a + prefix";
$framework->flow_mech__customercare__quick_search( 't +12345' );


#-------------------------------------------------------------------------------

done_testing;

#-------------------------------------------------------------------------------

