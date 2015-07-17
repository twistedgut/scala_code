#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 Test 'Public::Country' methods

Tests any methods for the 'Public::Country' class, currently tests:

* can_refund_for_return
* no_charge_for_exchange
Also tests the above for 'Public::SubRegion' because of their similarity.

=cut


use Test::Exception;
use Test::XTracker::Data;
use Test::XTracker::ParamCheck;
use XTracker::Constants::FromDB     qw(
                                        :refund_charge_type
                                    );

use Data::Dump      qw( pp );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

note "TESTING 'can_refund_for_return' & 'no_charge_for_exchange' methods";
$schema->txn_do( sub {
        _test_refund_charge_methods( $schema );

        # rollback changes
        $schema->txn_rollback;
    } );

done_testing;

#------------------------------------------------------------------------

# tests the 'can_refund_for_return' & 'no_charge_for_exchange' methods
# on both the 'Public::Country' class and the 'Public::SubRegion' class
sub _test_refund_charge_methods {
    my $schema  = shift;

    # set-up up ResultSets
    my $country_rs          = $schema->resultset('Public::Country');
    # tables used by the methods
    my $country_ref_chg_rs  = $schema->resultset('Public::ReturnCountryRefundCharge');
    my $subregion_ref_chg_rs= $schema->resultset('Public::ReturnSubRegionRefundCharge');

    # clear out existing data
    $country_ref_chg_rs->search->delete;
    $subregion_ref_chg_rs->search->delete;

    # use any Country and get it's Sub-Region
    my $country     = $country_rs->search->first;
    my $subregion   = $country->sub_region;

    _check_required_params( $country );

    note "TEST calling the methods with no Refund Charge records for either the Country or the Sub-Region";
    my $tmp = $country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX, $REFUND_CHARGE_TYPE__DUTY );
    ok( defined $tmp && $tmp == 0, "calling 'can_refund_for_return' on the Country returns FALSE and is not 'undef'" );
    $tmp    = $country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__TAX, $REFUND_CHARGE_TYPE__DUTY );
    ok( defined $tmp && $tmp == 0, "calling 'no_charge_for_exchange' on the Country returns FALSE and is not 'undef'" );
    $tmp    = $subregion->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX, $REFUND_CHARGE_TYPE__DUTY );
    ok( defined $tmp && $tmp == 0, "calling 'can_refund_for_return' on the Sub-Region returns FALSE and is not 'undef'" );
    $tmp    = $subregion->no_charge_for_exchange( $REFUND_CHARGE_TYPE__TAX, $REFUND_CHARGE_TYPE__DUTY );
    ok( defined $tmp && $tmp == 0, "calling 'no_charge_for_exchange' on the Sub-Region returns FALSE and is not 'undef'" );

    # set-up the tests to run
    my %tests   = (
            'Taxes only for Refunds & Charges' => {
                Tax => $REFUND_CHARGE_TYPE__TAX,
            },
            'Duties only for Refunds & Charges' => {
                Duty => $REFUND_CHARGE_TYPE__DUTY,
            },
            'Both Taxes & Duties for Refunds & Charges' => {
                Tax => $REFUND_CHARGE_TYPE__TAX,
                Duty => $REFUND_CHARGE_TYPE__DUTY,
            },
        );

    foreach my $test_label ( sort keys %tests ) {
        note "TEST: $test_label";
        my $test    = $tests{ $test_label };

        my @params  = map { $test->{ $_ } } sort keys %{ $test };   # params to pass in to the methods
        my @perms   = _get_permutations( scalar @params );          # number of permutations for the tests

        note "test on Country: " . $country->country;
        my @recs    = _create_related_records( $country, 'return_country_refund_charges', @params );
        _run_through_perms( $country, \@params, \@recs, \@perms );
        $country->return_country_refund_charges->delete;            # delete records so next tests can be done

        note "test on Sub-Region: " . $subregion->sub_region;
        @recs       = _create_related_records( $subregion, 'return_sub_region_refund_charges', @params );
        _run_through_perms( $subregion, \@params, \@recs, \@perms );
        $subregion->return_sub_region_refund_charges->delete;       # delete records so next tests can be done
    }


    # this will test whether a Countries Sub-Region records are
    # overriding when calling the methods on a Country, they
    # should only do so when there are no records for the Type
    # for the Country and not when the Country's records are FALSE
    note "TEST where a Country's Sub-Region has Refund Charge records";

    note "create records for the Country which are FALSE and then for Sub-Region where they are all TRUE";
    my @recs    = _create_related_records( $subregion, 'return_sub_region_refund_charges', $REFUND_CHARGE_TYPE__TAX, $REFUND_CHARGE_TYPE__DUTY );
    foreach my $rec ( @recs ) {
        $rec->update( {
                        can_refund_for_return => 1,
                        no_charge_for_exchange => 1,
                    } );
    }

    note "have a Tax record for the Country set to FALSE but no Duty";
    _create_related_records( $country, 'return_country_refund_charges', $REFUND_CHARGE_TYPE__TAX );
    cmp_ok( $country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX ), '==', 0,
                        "calling 'can_refund_for_return' for Tax on the Country returns FALSE and isn't overridden by the Sub-Region" );
    cmp_ok( $country->can_refund_for_return( $REFUND_CHARGE_TYPE__DUTY ), '==', 1,
                        "calling 'can_refund_for_return' for Duty on the Country returns TRUE as it uses the Sub-Region record" );
    cmp_ok( $country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__TAX ), '==', 0,
                        "calling 'no_charge_for_exchange' for Tax on the Country returns FALSE and isn't overridden by the Sub-Region" );
    cmp_ok( $country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__DUTY ), '==', 1,
                        "calling 'no_charge_for_exchange' for Duty on the Country returns TRUE as it uses the Sub-Region record" );
    cmp_ok( $country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX, $REFUND_CHARGE_TYPE__DUTY ), '==', 0,
                        "calling 'can_refund_for_return' for Tax & Duty on the Country returns FALSE and isn't overridden by the Sub-Region" );
    cmp_ok( $country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__TAX, $REFUND_CHARGE_TYPE__DUTY ), '==', 0,
                        "calling 'no_charge_for_exchange' for Tax & Duty on the Country returns FALSE and isn't overridden by the Sub-Region" );

    note "have a Tax record for the Country set to TRUE but no Duty, should now return TRUE when called with both Tax & Duty";
    $country->return_country_refund_charges->delete;
    @recs   = _create_related_records( $country, 'return_country_refund_charges', $REFUND_CHARGE_TYPE__TAX );
    $recs[0]->update( {
                    can_refund_for_return => 1,
                    no_charge_for_exchange => 1,
                } );
    cmp_ok( $country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX, $REFUND_CHARGE_TYPE__DUTY ), '==', 1,
                        "calling 'can_refund_for_return' for Tax & Duty on the Country returns TURE using the Sub-Region's Duty record" );
    cmp_ok( $country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__TAX, $REFUND_CHARGE_TYPE__DUTY ), '==', 1,
                        "calling 'no_charge_for_exchange' for Tax & Duty on the Country returns TRUE using the Sub-Region's Duty record" );

    note "delete the Country's records and now the Sub-Region's (both TRUE) should be used";
    $country->return_country_refund_charges->delete;
    cmp_ok( $country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX, $REFUND_CHARGE_TYPE__DUTY ), '==', 1,
                        "calling 'can_refund_for_return' for Tax & Duty on the Country returns TRUE as it is using the Sub-Region records" );
    cmp_ok( $country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__TAX, $REFUND_CHARGE_TYPE__DUTY ), '==', 1,
                        "calling 'no_charge_for_exchange' for Tax & Duty on the Country returns TRUE as it is using the Sub-Region records" );


    return;
}

#------------------------------------------------------------------------

# work out the number of permutations to TRUE & FALSE
# depending on the number of Types given to Test For
sub _get_permutations {
    my $number  = shift;

    my @perms;
    for my $i (0 .. ($number * 2)-1) {
        my $frmt_str    = '%0.' . $number . 'b';        # set-up the format string to have correct leading zeros
        my $permutation = sprintf( $frmt_str, $i );     # get the Binary version of the number
        push @perms, [ split( //, $permutation ) ];     # split up each element of the Binary number to give TRUE & FALSE values
    }

    return @perms;
}

# create the related records required for the different types used
sub _create_related_records {
    my ( $object, $table, @types )  = @_;

    my @recs;
    foreach my $type ( @types ) {
        push @recs, $object->create_related( $table, {
                                refund_charge_type_id   => $type,
                                can_refund_for_return => 0,
                                no_charge_for_exchange => 0,
                            } );
    }

    return @recs;
}

# actually run through all the permutations and call
# the methods and test their results
sub _run_through_perms {
    my ( $object, $params, $recs, $perms )  = @_;

    note "test permutations setting the 'can_refund_for_return' & 'no_charge_for_exchange' flags appropriately";
    foreach my $perm ( @{ $perms } ) {
        # update 'can_refund_for_return' & 'no_charge_for_exchange' fields
        # for each record then call the methods to check for the result

        my $refund_expected = 1;
        my $refund_note     = '';

        my $charge_expected = 1;
        my $charge_note     = '';

        foreach my $i ( 0..$#{ $perm } ) {
            my $charged_perm    = 1 ^ $perm->[ $i ];        # flip the exhange flag so that both flags aren't the same
            $recs->[ $i ]->update( {
                                    can_refund_for_return => $perm->[ $i ],
                                    no_charge_for_exchange => $charged_perm,
                                } );

            $refund_expected    = $refund_expected & $perm->[ $i ];     # work out the expected result using a bitwise AND
            $refund_note        .= ' & '    if ( $refund_note );
            $refund_note        .= ( $perm->[ $i ] ? 'TRUE' : 'FALSE' );

            $charge_expected    = $charge_expected & $charged_perm;     # work out the expected result using a bitwise AND
            $charge_note        .= ' & '    if ( $charge_note );
            $charge_note        .= ( $charged_perm ? 'TRUE' : 'FALSE' );
        }

        # call the methods passing all params into it
        my $result  = $object->can_refund_for_return( @{ $params } );
        ok( defined $result, "calling 'can_refund_for_return' didn't return 'undef'" );
        cmp_ok( $result, '==', $refund_expected, "got expected result: $refund_expected, with flag(s) set to: $refund_note" );

        $result = $object->no_charge_for_exchange( @{ $params } );
        ok( defined $result, "calling 'no_charge_for_exchange' didn't return 'undef'" );
        cmp_ok( $result, '==', $charge_expected, "got expected result: $charge_expected, with flag(s) set to: $charge_note" );
    }

    return;
}

# check for required params passed into different methods
sub _check_required_params {
    my $country     = shift;

    note "TEST required params for methods & functions";

    my $schema      = $country->result_source->schema;
    my $sub_region  = $country->sub_region;

    dies_ok( sub {
            $country->can_refund_for_return;
        }, "'country->can_refund_for_return' dies when no Refund Charge Types passed in" );
    dies_ok( sub {
            $country->no_charge_for_exchange;
        }, "'country->no_charge_for_exchange' dies when no Refund Charge Types passed in" );
    dies_ok( sub {
            $sub_region->can_refund_for_return;
        }, "'sub_region->can_refund_for_return' dies when no Refund Charge Types passed in" );
    dies_ok( sub {
            $sub_region->no_charge_for_exchange;
        }, "'sub_region->no_charge_for_exchange' dies when no Refund Charge Types passed in" );

    my $param_check = Test::XTracker::ParamCheck->new();

    return;
}
