#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
use XTracker::Config::Local;
use DateTime;

use XTracker::Constants     qw( :application );




# evil globals
our ($schema);

BEGIN {
    use_ok('XTracker::Schema');
    use_ok('XTracker::Database',':common');
    use_ok('XTracker::Schema::Result::Public::Currency');
    use_ok('XTracker::Schema::Result::Public::SalesConversionRate');
}

# get a schema to query
$schema = get_database_handle(
    {
        name    => 'xtracker_schema',
    }
);
isa_ok($schema, 'XTracker::Schema',"Schema Created");

$schema->txn_do( sub {
        my $currency_rs = $schema->resultset('Public::Currency');
        my $local_curr  = $currency_rs->search( { currency => config_var('Currency', 'local_currency_code') } )->first;
        my $dest_curr   = $currency_rs->search( { currency => { 'NOT IN' => [ $local_curr->currency, 'UNK', 'AUD' ] } } )->first;

        my $conv_rate;
        my $rate;

        # clear out existing rates
        $local_curr->search_related( 'sales_conversion_rate_source_currencies' )->delete;

        # add our own
        $conv_rate  = $local_curr->create_related( 'sales_conversion_rate_source_currencies', {
                                        source_currency     => $local_curr->id,
                                        destination_currency=> $dest_curr->id,
                                        conversion_rate     => 2,
                                        date_start          => DateTime->now()->subtract( years => 1 ),
                                    } );

        # get the rate and check
        $rate   = $local_curr->conversion_rate_to( $dest_curr->currency );
        cmp_ok( $rate, '==', 2, "Original Conversion Rate for ".$local_curr->currency." to ".$dest_curr->currency." is 2" );

        # expire create conv rate & create a new one which should get picked up
        $conv_rate->update( { date_finish => DateTime->now()->subtract( days => 2 ) } );
        $conv_rate  = $local_curr->create_related( 'sales_conversion_rate_source_currencies', {
                                        source_currency     => $local_curr->id,
                                        destination_currency=> $dest_curr->id,
                                        conversion_rate     => 2.5,
                                        date_start          => DateTime->now()->subtract( days => 2 ),
                                    } );

        # get the rate and check
        $rate   = $local_curr->conversion_rate_to( $dest_curr->currency );
        cmp_ok( $rate, '==', 2.5, "New Conversion Rate for ".$local_curr->currency." to ".$dest_curr->currency." is 2.5" );

        $schema->txn_rollback();
    } );


done_testing();
