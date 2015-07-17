#!perl

=head1 NAME

customer_search.t - Test the customer search module

=head1 DESCRIPTION

Verifies that customer search functions operate as expected
but does NOT connect to the MySQL database to carry out tests.

#TAGS search shouldbeunit sql misc

=cut

use NAP::policy "tt", 'test';
use Test::XTracker::Data;

use XTracker::Database qw ( get_database_handle );
use XTracker::Order::CustomerCare::CustomerSearch::Search qw/ find_customers /;

use Clone       qw( clone );


my $dbh = Test::XTracker::Data->get_dbh;

throws_ok( sub { find_customers() }, qr/No DB handle/, 'Fails if no $dbh passed');

throws_ok( sub { find_customers(1) }, qr/(?:Can't call method "can"|dbh is not a real dbh)/, 'Fails if $dbh is not a real dbh object');

throws_ok( sub {find_customers($dbh, {search_terms => 'test'})},
         qr/No search type/,
         'Search without search type fails' );

throws_ok( sub {find_customers($dbh, {search_type => 'test'})},
         qr/No search terms/,
         'Search without search terms fails' );

throws_ok( sub{ find_customers($dbh, {
        search_type => 'email',
        search_terms => 'test',
        sales_channel => '0-NOTANAP',
    }) },
    qr/Unable to determine channel ID/,
    'Fail if passed invalid channel' );

ok(! find_customers($dbh, {
        search_type => 'test',
        search_terms => 'test',
        sales_channel => 'WHO-CARES',
    }), "Returns undef if invalid search_type is passed");

# make up Channel Id's that are found in the Customer
# Search page which are in the form 'id-confsection'
my @channels     = map {
    $_->id . '-' . $_->business->config_section
} Test::XTracker::Data->get_enabled_channels->fulfilment_only( 0 );

my $tests = [
    ['customer_name', 'ftest ltest',   qr/WHERE first_name LIKE \? AND last_name LIKE \?/, [ '%ftest%', '%ltest%' ] ],
    ['customer_number', '1',        qr/WHERE id = \?/, '1' ],
    ['first_name', 'test', qr/WHERE first_name LIKE \?\n/, '%test%' ],
    ['last_name',  'test', qr/WHERE last_name LIKE \?\n/, '%test%' ],
    ['email', 'test@net-a-porter.com', qr/WHERE email LIKE \?\n/, '%test@net-a-porter.com%' ],
    [ [ 'first_name', 'last_name' ], [ 'ftest', 'ltest' ], qr/WHERE first_name LIKE \?.*last_name LIKE \?/, [ '%ftest%', '%ltest%' ] ],

    # check search terms are trimmed
    ['customer_name', ' ftest ltest ',   qr/WHERE first_name LIKE \? AND last_name LIKE \?/, [ '%ftest%', '%ltest%' ] ],
    ['customer_number', ' 1 ',        qr/WHERE id = \?/, '1' ],
    ['first_name', ' test ', qr/WHERE first_name LIKE \?\n/, '%test%' ],
    ['last_name',  ' test ', qr/WHERE last_name LIKE \?\n/, '%test%' ],
    ['email', ' test@net-a-porter.com ', qr/WHERE email LIKE \?\n/, '%test@net-a-porter.com%' ],
    [ [ 'first_name', 'last_name' ], [ ' ftest ', ' ltest ' ], qr/WHERE first_name LIKE \?.*last_name LIKE \?/, [ '%ftest%', '%ltest%' ] ],
];

foreach my $test_search (@$tests) {
    foreach my $channel_id ( @channels ) {
        run_search_tests($dbh, $channel_id, $test_search);
    }
}

sub run_search_tests {
    my ($dbh, $channel_id, $test_search) = @_;

    my @search_clone    = @{ clone( $test_search ) };

    my $type_string = ref $search_clone[0] eq 'ARRAY'
        ? join( "','", @{ $search_clone[0] } )
        : "$search_clone[0]";

    my $term_string = ref $search_clone[1] eq 'ARRAY'
        ? "ARRAY: ['" . join( "','", @{ $search_clone[1] } ) . "']"
        : "'$search_clone[1]'";

    foreach my $channel (
        XTracker::Order::CustomerCare::CustomerSearch::Search::_get_channels($dbh, $channel_id) ) {

        my $dbh_web =
            get_database_handle( { name => 'Web_Live_'.$channel->{config_section},
                                   type => 'transaction' });

        my $results = search($dbh, $dbh_web,
                             $search_clone[0], $search_clone[1], $channel);

        like($dbh_web->{mock_all_history}->[0]->statement,
             $search_clone[2],
             "SQL match for channel_id $channel->{id} "
                . "search on '$type_string' [$term_string]");

        my @expect_params   = ( ref( $search_clone[3] ) ? @{ $search_clone[3] } : ( $search_clone[3] ) );
        my $got_params      = $dbh_web->{mock_all_history}->[0]->bound_params;

        ok( 0 + @{ $got_params } == scalar( @expect_params ),
            "Correct number of bound parameters for channel_id $channel->{id} "
                . "search on '$type_string' [$term_string]" );

        is_deeply( $got_params, \@expect_params, "and bound parameters as Expected" );
    }
}

sub search {
    my ($dbh, $dbh_web, $search_type, $search_terms, $channel) = @_;

    return XTracker::Order::CustomerCare::CustomerSearch::Search::_search_customers(
                $dbh, $dbh_web, $search_type, $search_terms, $channel );
}

done_testing;

#-----------------------------------------------------------------------

