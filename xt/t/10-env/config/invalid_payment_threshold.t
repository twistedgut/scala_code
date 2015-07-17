#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 CANDO-132: Invalid Payments - threshold

This will test the setting 'invalid_payments_threshold' in the 'xtracker_extras_XTDC?.conf' file in the 'Invalid_Payments'.


=cut


use Test::Exception;

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            export => [ '$distribution_centre' ];


use_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                ) );
can_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                ) );



note "Test the 'valid_payment_threshold' config option in the 'Valid_Payments' section";

# test the setting in the config file
if ( $distribution_centre eq "DC1" ) {
    is( config_var( 'Valid_Payments', 'valid_payments_threshold' ), '10',
                                            "Setting: 'valid_payments_threshold' in 'Valid_Payments' Section is set to 10" );
} elsif ( $distribution_centre eq "DC2" ) {
    is( config_var( 'Valid_Payments', 'valid_payments_threshold' ), '0',
                                           "Setting: 'valid_payments_threshold' in 'Valid_Payments' Section is set to 0" );
} elsif ( $distribution_centre eq "DC3" ) {
    is( config_var( 'Valid_Payments', 'valid_payments_threshold' ), '10',
                                            "Setting: 'valid_payments_threshold' in 'Valid_Payments' Section is set to 10" );
} else {
    fail( "No Test Written for Distribution Centre: $distribution_centre" );
};

done_testing();
