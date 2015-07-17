#!/usr/bin/env perl

use NAP::policy "tt",     'test';

use Test::XTracker::Data;
use XTracker::Database      ();

use DBD::Mock::Session;

BEGIN { use_ok( 'XTracker::WebContent::StockManagement' ); }
require_ok( 'XTracker::WebContent::StockManagement' );


my $channels = Test::XTracker::Data->get_enabled_channels();
my $schema   = Test::XTracker::Data->get_schema();


# re-define 'db_connection' to return the Web-DBH
# so that we can monitor the activity using DBD::Mock
no warnings     'redefine';
my $mock_web_dbh;
my $original__db_connection         = \&XTracker::Database::db_connection;
*XTracker::Database::db_connection = \&_redefined__db_connection;
use warnings    'redefine';


while ( my $channel = $channels->next ) {
    my $stock_manager = _get_stock_manager( $schema, $channel );

    ok($stock_manager, 'Got something');

    if ( $channel->business->fulfilment_only ) {
        isa_ok($stock_manager,
            'XTracker::WebContent::StockManagement::ThirdParty');
    }
    else {
        isa_ok($stock_manager,
            'XTracker::WebContent::StockManagement::OurChannels');

        note "Test whether or not '_web_dbh' is set before or after use";
        cmp_ok( $stock_manager->_has_web_dbh, '==', 0, "Predicate '_has_web_dbh' returns FALSE before use" );
        my $web_dbh = $stock_manager->_web_dbh;     # this means we've 'USED' the handle to do something
        cmp_ok( $stock_manager->_has_web_dbh, '==', 1, "Predicate '_has_web_dbh' returns TRUE after use" );

        note "Do 'commit/rollback/disconnect' DB operations on a StockManager's Web-DBH handle that HAS been used";

        ok( $stock_manager->commit, "->commit executed and returned TRUE" );
        cmp_ok( _check_for_statement( $mock_web_dbh, 'COMMIT' ), '==', 1,
                                    "and COMMIT statement sent to Web-DBH" );
        ok( $stock_manager->rollback, "->rollback executed and returned TRUE" );
        cmp_ok( _check_for_statement( $mock_web_dbh, 'ROLLBACK' ), '==', 1,
                                    "and ROLLBACK statement sent to Web-DBH" );
        dies_ok {
            $stock_manager->disconnect;
        } "->disconnect died because it has un-finished statements in the session";

        # clean stuff up before the next tests
        _cleanup_mock_web_dbh( $mock_web_dbh );


        note "Do 'commit/rollback/disconnect' DB operations on a StockManager's Web-DBH handle that was NOT used";

        # get a new Stock Manager
        $stock_manager  = _get_stock_manager( $schema, $channel );

        ok( $stock_manager->commit, "->commit executed and returned TRUE" );
        cmp_ok( _check_for_statement( $mock_web_dbh, 'COMMIT' ), '==', 0,
                                    "and COMMIT statement NOT sent to Web-DBH" );
        ok( $stock_manager->rollback, "->rollback executed and returned TRUE" );
        cmp_ok( _check_for_statement( $mock_web_dbh, 'ROLLBACK' ), '==', 0,
                                    "and ROLLBACK statement NOT sent to Web-DBH" );
        lives_ok {
            $stock_manager->disconnect;
        } "->disconnect LIVES because handle wasn't used and so doesn't have un-finished statements in the session";

        # clean stuff up before the next tests
        _cleanup_mock_web_dbh( $mock_web_dbh );
    }
}

done_testing;

#----------------------------------------------------------------------------------------

sub _get_stock_manager {
    my ( $schema, $channel )    = @_;

    return XTracker::WebContent::StockManagement->new_stock_manager( {
        channel_id => $channel->id,
        schema     => $schema,
    } );
}

sub _check_for_statement {
    my ( $mock_dbh, $statement )    = @_;

    my $history = $mock_dbh->{mock_all_history};

    my $retval  = 0;
    if ( @{ $history } && $history->[0]{statement} eq $statement ) {
        $retval = 1;
    }

    $mock_dbh->{mock_clear_history} = 1;

    return $retval;
}

sub _cleanup_mock_web_dbh {
    my $mock_dbh    = shift;

    $mock_dbh->{mock_session}       = undef;
    $mock_dbh->{mock_clear_history} = 1;
}

sub _redefined__db_connection {
    note "================== IN RE-DEFINED 'db_connection' ==================";
    my $dbh = $original__db_connection->( @_ );

    $mock_web_dbh   = $dbh;
    $mock_web_dbh->{mock_clear_history} = 1;
    $mock_web_dbh->{mock_session}   = DBD::Mock::Session->new('my_session' => (
        {
            statement => 'COMMIT',
            results   => [],
        },
        {
            statement => 'ROLLBACK',
            results   => [],
        },
        {
            statement => 'SELECT * FROM something',
            results   => [[ '1' ], [ '2' ]],
        },
    ) );

    return $dbh;
}
