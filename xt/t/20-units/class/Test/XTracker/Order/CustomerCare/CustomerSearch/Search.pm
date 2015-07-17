package Test::XTracker::Order::CustomerCare::CustomerSearch::Search;
use NAP::policy qw/tt test class/;

=head1 NAME

Search.pm

=head1 DESCRIPTION

Tests that the customer search behaves appropriately

#TAGS cando customer

=cut

BEGIN {
    extends 'NAP::Test::Class';
};

use Test::XT::Data;
use Test::XTracker::Data;
use XTracker::Config::Local    qw( config_var );
use Clone       qw( clone );
use XTracker::Database qw ( get_database_handle );

sub test_startup : Test( startup => no_plan ) {
    my $self = shift;
    use_ok 'XTracker::Order::CustomerCare::CustomerSearch::Search';
    $self->{channels} = [ map {
        $_->id . '-' . $_->business->config_section
        } Test::XTracker::Data->get_enabled_channels->fulfilment_only( 0 )
    ];

}

=head1 test_blank_search_terms

Tests that when the query for search results is blank, the search method returns an empty hashref

=cut

sub test_blank_search_terms : Tests {
    my $self = shift;
    my $dbh = Test::XTracker::Data->get_dbh;

    my @channels = @{ $self->{channels} };

    # check that blank search terms don't return results
    my $blank_tests = [
        ['customer_name', '   ', qr/WHERE first_name LIKE \? AND last_name LIKE \?/, [ '%ftest%', '%ltest%' ] ],
        ['customer_number', '  ', qr/WHERE id = \?/, '1' ],
        ['first_name', '  ', qr/WHERE first_name LIKE \?\n/, '%test%' ],
        ['last_name',  '  ', qr/WHERE last_name LIKE \?\n/, '%test%' ],
        ['email', '  ', qr/WHERE email LIKE \?\n/, '%test@net-a-porter.com%' ],
        [ [ 'first_name', 'last_name' ], [ '  ', '   ' ], qr/WHERE first_name LIKE \?.*last_name LIKE \?/, [ '%ftest%', '%ltest%' ] ],
    ];

    foreach my $test_search (@$blank_tests) {
        foreach my $channel_id ( @channels ) {
            my @search_channels = XTracker::Order::CustomerCare::CustomerSearch::Search::_get_channels($dbh, $channel_id);
            foreach my $channel ( @search_channels ) {
                my $results = _search_terms($dbh, $channel, $test_search);
                ok( scalar keys %$results == 0, "Searching with an empty string returns no results");
            }
        }
    }
}

sub _search_terms {
    my ($dbh, $channel, $test_search) = @_;
    my @search_clone = @$test_search;
    my $dbh_web = get_database_handle( { name => 'Web_Live_'.$channel->{config_section},
                                   type => 'transaction' });

    return _search($dbh, $dbh_web, $search_clone[0], $search_clone[1], $channel);
}

sub _search {
    my ($dbh, $dbh_web, $search_type, $search_terms, $channel) = @_;

    return XTracker::Order::CustomerCare::CustomerSearch::Search::_search_customers(
                $dbh, $dbh_web, $search_type, $search_terms, $channel );
}

