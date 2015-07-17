#!/usr/bin/perl
use NAP::policy "tt",     'test';

=head1 refund_to_psp

This tests the function 'refund_to_psp' which is in 'XTracker::Database::OrderPayment'.

It will use 'Test::XTracker::Mock::PSP' to mock responses to test both Succesfull Refunds
and Un-Successful.

=cut


use Test::XTracker::Data;
use Test::XTracker::Mock::PSP;

use XTracker::Config::Local             qw( config_var );

use_ok( 'XTracker::Database::OrderPayment', qw( refund_to_psp ) );
can_ok( 'XTracker::Database::OrderPayment', qw( refund_to_psp ) );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );


my @channels    = $schema->resultset('Public::Channel')->all;
my $settle_ref  = '5432156789';

my %tests   = (
        'Successfully make a Refund - Whole Amount'     => {
                success     => 1,
                mock_action => 'PASS',
                func_args   => {
                    amount          => 125,
                    settlement_ref  => $settle_ref,
                    id_for_err_msg  => '23000304032',
                    label_for_id    => 'Order Nr',
                },
                mock_action => 'PASS',
            },
        'Successfully make a Refund - Decimal Amount'   => {
                success     => 1,
                mock_action => 'PASS',
                func_args   => {
                    amount          => 523.37,
                    settlement_ref  => $settle_ref,
                    id_for_err_msg  => '456',
                    label_for_id    => 'Pre Order Id',
                },
            },
        'Fail to Refund with Rejected by Bank Reason in Error Message'   => {
                success         => 0,
                mock_action     => 'FAIL-2',
                expected_err_msg=> qr/rejected by the issuing bank/i,
                func_args       => {
                    amount          => 3.40,
                    settlement_ref  => $settle_ref,
                    id_for_err_msg  => '7896543',
                    label_for_id    => 'Order Nr',
                }
            },
        'Fail to Refund with Manadatory Information Missing Reason in Error Message'   => {
                success         => 0,
                mock_action     => 'FAIL-3',
                expected_err_msg=> qr/Mandatory information missing/i,
                func_args       => {
                    amount          => 3.40,
                    settlement_ref  => $settle_ref,
                    id_for_err_msg  => '123',
                    label_for_id    => 'Pre Order Id',
                }
            },
        'Fail to Refund with Extra Reason in Error Message'   => {
                success         => 0,
                mock_action     => 'FAIL-4',
                extra_reason    => 'Should see this message',
                func_args       => {
                    amount          => 3.4,
                    settlement_ref  => $settle_ref,
                    id_for_err_msg  => '123',
                    label_for_id    => 'Pre Order Id',
                }
            },
        'Fail to Refund with Could Not Find Order Reason in Error Message'   => {
                success         => 0,
                mock_action     => 'FAIL-3',
                expected_err_msg=> qr/Could not find order via PSP/i,
                func_args       => {
                    amount          => 13.02,
                    settlement_ref  => $settle_ref,
                    id_for_err_msg  => 'D456EF790',
                    label_for_id    => 'Some Id',
                }
            },
    );

# loop round each Sales Channel and do the above tests
foreach my $channel ( @channels ) {
    note "Sales Channel: " . $channel->name;

    my $psp_channel = config_var( 'PaymentService_' . $channel->business->config_section, 'dc_channel' );

    foreach my $label ( keys %tests ) {
        note "test: $label";
        my $test        = $tests{ $label };

        # get the arguments for the function and add in the Sales Channel
        my $func_args   = $test->{func_args};
        $func_args->{channel}   = $channel;

        # set-up the Mocking First
        Test::XTracker::Mock::PSP->refund_extra( $test->{extra_reason} // '' );
        Test::XTracker::Mock::PSP->refund_action( $test->{mock_action} );

        # work out what data should look like being passed to the PSP
        my $expected_amt    = sprintf( "%.2f", $func_args->{amount} );
        $expected_amt       =~ s/\.//;      # remove deicmal place
        my $passed_to_psp   = {
                    channel             => $psp_channel,
                    coinAmount          => $expected_amt,
                    settlementReference => $func_args->{settlement_ref},
                };

        # call the function to be tested
        my $result  = refund_to_psp( $func_args );
        ok( defined $result, "'refund_to_psp' returned a 'defined' value" );

        is_deeply( Test::XTracker::Mock::PSP->get_refund_data_in, $passed_to_psp,
                                    "PSP was Passed the Expected Data" );

        if ( $test->{success} ) {
            is_deeply( $result, { success => 1 }, "Returned Expected Successful result" );
        }
        else {
            cmp_ok( $result->{success}, '==', 0, "'success' flag is FALSE when Refund Failed" );
            # make up an expected Error Message to check for
            $test->{expected_err_msg}   //= $test->{extra_reason};
            my $id_label_in_msg = "$func_args->{label_for_id}: $func_args->{id_for_err_msg},";
            like( $result->{error_msg}, qr/Unable to refund for $id_label_in_msg.*$test->{expected_err_msg}/i, "'error_msg' is as Expected" );
        }
    }
}


done_testing();
