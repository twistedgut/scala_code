#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 Configs for fraud check rating adjustment

This is a place to test for general configs for Fraud check rules

Currently tests:
    * Correct rating adjustment value for credit_check_rating is set


#CANDO 491

=cut



use Data::Dump qw( pp );
use Test::XTracker::ParamCheck;

use Test::XTracker::Data;

my $schema  = Test::XTracker::Data->get_schema;
my $dbh = $schema->storage->dbh;
isa_ok( $schema, "XTracker::Schema" );

BEGIN {
    use_ok('XTracker::Database', qw( :common ));
    use_ok("XTracker::Config::Local", qw(
                            get_fraud_check_rating_adjustment
                        ) );

    can_ok("XTracker::Config::Local", qw(
                            get_fraud_check_rating_adjustment
                        ) );
}


#------------------------


my $sys_config  = $schema->resultset('SystemConfig::ConfigGroupSetting');
# get a list of channels in a hash
# keyed by their config section
my %channels    = map { $_->business->config_section => $_ } $schema->resultset('Public::Channel')->search( {}, { order_by => 'id' } )->all;

# set-up expected result per channel
my %expected    = (
        'NAP'   => {
                    card_check_rating => 150,
                   },
        'OUTNET'=> {
                    card_check_rating => 150,
                   },
        'MRP'   => {
                    card_check_rating => 0,
                   },
        'JC'    => {
                    card_check_rating => 150,
                   },
    );


###### TEST ############
_test_reqd_params( $dbh, $schema, 1 );
_test_get_fraud_check_rating_adjustment( $dbh, $schema, 1 );
_test_config_values();
#-------------------------------

sub _test_config_values {

    while ( my ( $key, $methods )   = each %expected ) {
        my $channel     = $channels{ $key };

        note "Sales Channel: " . $channel->id . " - " . $channel->name;

        # check out the 'card_check_rating' system config setting first
        my $expected_val= delete $methods->{card_check_rating};
        my $conf_val    = $sys_config->config_var( 'FraudCheckRatingAdjustment', 'card_check_rating', $channel->id );
        ok( defined $conf_val, "'card_check_rating' value IS defined" );
        cmp_ok( $conf_val, '==', $expected_val, "'card_check_rating' value as expected: $expected_val" );

}

}


sub _test_reqd_params {
    my $dbh     = shift;
    my $schema  = shift;

    my $param_check = Test::XTracker::ParamCheck->new();

    SKIP: {
        skip "_test_reqd_params",1           if (!shift);

        note "Testing for Required Parameters";

        $param_check->check_for_params(  \&get_fraud_check_rating_adjustment,
                            'get_fraud_check_rating_adjustment',
                            [ $schema, 1],
                            [ "No Schema Connection Passed", "No Sales Channel Id Passed" ],
                            [ undef, 0 ],
                            [ undef, "No Sales Channel Id Passed" ]
                        );

    }
}

sub _test_get_fraud_check_rating_adjustment {
    my $dbh    = shift;
    my $schema = shift;
    my $test   = shift;

    SKIP: {
        skip "_test_get_fraud_check_rating_adjustment",1 if (!$test);

        note "Testing Fraud Check Rating Adjustment Function";

        while( my ( $key, $methods )   = each %expected ) {
            my $channel     = $channels{ $key };

            note "Sales Channel: " . $channel->id . " - " . $channel->name;

            my $rating    = get_fraud_check_rating_adjustment( $schema, $channel->id );
            isa_ok($rating,"HASH","Got Rating adjustment for card_check_rating on Channel ". $channel->id);
        }
    }

}

done_testing;

#-------------------------------------------------------------------------------
