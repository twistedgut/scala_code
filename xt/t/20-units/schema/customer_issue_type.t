#!/usr/bin/env perl
use NAP::policy "tt",         'test';


use Test::XTracker::Data;
use XTracker::Constants::FromDB     qw(
                                        :customer_issue_type
                                        :customer_issue_type_group
                                    );

# get a schema, sanity check
my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

my $cust_issue_type = $schema->resultset('Public::CustomerIssueType');
isa_ok( $cust_issue_type, "XTracker::Schema::ResultSet::Public::CustomerIssueType" );

_test_return_reason_from_pws_code( $cust_issue_type );
_test_return_reasons( $cust_issue_type );

done_testing;


# CANDO-182:
# this tests that the method 'return_reason_from_pws_code' which is a resultset
# doesn't return back a customer issue type of 'Dispatch/Return' regardless of
# which PWS Customer Reason passed to it
sub _test_return_reason_from_pws_code {
    my $cust_issue_type     = shift;

    my $schema  = $cust_issue_type->result_source->schema;

    note "Testing 'return_reason_from_pws_code' method";

    # get all the 'PWS Reasons' in the table
    my @pws_reasons = $cust_issue_type->search( { pws_reason => { 'IS NOT' => undef } } )->all;

    # loop round all the PWS Reasons and call 'return_reason_from_pws_code'
    foreach my $pws_reason ( @pws_reasons ) {
        my $xt_reason   = $cust_issue_type->return_reason_from_pws_code( $pws_reason->pws_reason );
        cmp_ok( $xt_reason->id, '!=', $CUSTOMER_ISSUE_TYPE__7__DISPATCH_FSLASH_RETURN,
                                    "PWS Reason: " . $pws_reason->pws_reason . ", XT Reason is not 'Dispatch/Return': " . $xt_reason->description );
        cmp_ok( $xt_reason->id, '!=', $CUSTOMER_ISSUE_TYPE__7__ITEM_RETURNED__DASH__NO_RMA,
                                    "PWS Reason: " . $pws_reason->pws_reason . ", XT Reason is not 'Item Returned - No RMA': " . $xt_reason->description );

    }

    # now force the 'Dispatch/Return' PWS Reason to be something that
    # can be found so 'return_reason_from_pws_code' can be tested to
    # bring back nothing, do it in a transaction to not ruin future tests
    $schema->txn_do( sub {
            $cust_issue_type->find( $CUSTOMER_ISSUE_TYPE__7__DISPATCH_FSLASH_RETURN )
                                ->update( { pws_reason => 'TEST_DR_PWS_REASON' } );

            my $xt_reason   = $cust_issue_type->return_reason_from_pws_code('TEST_DR_PWS_REASON');
            ok( !defined $xt_reason, "Couldn't Find 'Dispatch/Return' XT reason when specifically looking for it" )
                                        || diag "POSSIBLE NON-REFUNDING OF TAX BUG";

            # rollback changes
            $schema->txn_rollback;
        } );

    return;
}

# CANDO-791
# this tests that the correct return reasons are returned
sub _test_return_reasons {
    my $cust_issue_type     = shift;

    note "Testing Getting Return Reasons methods";

    my %all_reasons = map { $_->id => $_->description }
                                        $cust_issue_type->search( { group_id => $CUSTOMER_ISSUE_TYPE_GROUP__RETURN_REASONS } )
                                            ->all;

    note "testing 'return_reasons' method";
    my $rs  = $cust_issue_type->return_reasons;
    isa_ok( $rs, 'XTracker::Schema::ResultSet::Public::CustomerIssueType', "method returned as expected" );
    my %got = map { $_->id => $_->description } $rs->all;
    is_deeply( \%got, \%all_reasons, "and got all expected Reasons" );

    note "testing 'return_reasons_for_rma_pages'";
    # 'Dispatch/Return' should not be Returned from this Method as
    # it is an Internal reason and shouldn't be used on the RMA pages
    delete $all_reasons{ $CUSTOMER_ISSUE_TYPE__7__DISPATCH_FSLASH_RETURN };
    my $hash    = $cust_issue_type->return_reasons_for_rma_pages;
    isa_ok( $hash, 'HASH', "method returned as expected" );
    is_deeply( $hash, \%all_reasons, "and got all expected Reasons and didn't get 'Dispatch/Return'" );


    return;
}
