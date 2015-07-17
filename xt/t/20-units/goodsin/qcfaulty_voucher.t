#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

qcfaulty_voucher.t - Test a faulty voucher at Quality Control

=head1 DESCRIPTION

At Quality Control, mark product as faulty, verify logs are written.

Do that for both a voucher and a normal product.

#TAGS goodsin qualitycontrol voucher rtv duplication shouldbeunit

=cut

use FindBin::libs;

use Test::XTracker::Data;

use XTracker::Constants             qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB     qw(
                                        :delivery_action
                                        :rtv_action
                                        :stock_process_type
                                        :stock_process_status
                                    );


use Test::Exception;
use Data::Dump qw( pp );

use_ok( 'XTracker::Schema::Result::Public::StockProcess' );

my $schema  = Test::XTracker::Data->get_schema();
my $tmp;
# get a user id for later tests
my $op_id   = $schema->resultset('Public::Operator')
                    ->search( { username => { 'ilike' => 'it.god' } } )
                        ->first->id;

# NOTE: default quantity ordered is 10, see Test::XTracker::data::create_stock_order_item()
my $faulty_qty  = 3;        # default faulty qty

# test Voucher Deliveries
$schema->txn_do( sub {
    note "Using Vouchers";

    # create data for tests
    my $voucher     = Test::XTracker::Data->create_voucher();
    my $po          = Test::XTracker::Data->setup_purchase_order($voucher->id);


    my ($delivery)  = Test::XTracker::Data->create_delivery_for_po( $po->id, 'qc' );
    my ($sp)        = Test::XTracker::Data->create_stock_process_for_delivery( $delivery );

    # test splitting a stock process
    my $faulty_sp  = $sp->split_stock_process( $STOCK_PROCESS_TYPE__FAULTY, $faulty_qty, $tmp );
    $sp->discard_changes;
    cmp_ok( $sp->quantity, '==',(10 - $faulty_qty), 'Original SP Qty now less faulty' );
    cmp_ok( $faulty_sp->quantity, '==', $faulty_qty, 'New SP Qty is correct' );
    cmp_ok( $faulty_sp->delivery_item_id, '==', $sp->delivery_item_id, 'New SP Delivery Item Id same as original' );
    cmp_ok( $faulty_sp->type_id, '==', $STOCK_PROCESS_TYPE__FAULTY, 'New SP Type is FAULTY' );
    cmp_ok( $faulty_sp->status_id, '==', $STOCK_PROCESS_STATUS__NEW, 'New SP Status is NEW' );
    ok( defined $faulty_sp->group_id, 'New SP Group Id is defined' );
    # split again testing the group id's remain the same
    $tmp    = $faulty_sp->group_id;
    my $new_sp = $sp->split_stock_process( $STOCK_PROCESS_TYPE__FAULTY, 2, $tmp );
    $sp->discard_changes;
    cmp_ok( $sp->quantity, '==', 5, 'Original SP Qty now even less faulty' );
    cmp_ok( $new_sp->quantity, '==', 2, 'New New SP Qty is correct' );
    cmp_ok( $new_sp->group_id, '==', $faulty_sp->group_id, 'New New SP Group Id same as previous New SP Group Id' );
    cmp_ok( $faulty_sp->quantity, '==', $faulty_qty, "Just Checking New SP Qty hasn't changed" );

    #
    # now test marking a voucher stock process faulty
    # so that the correct logs get created
    #

    my $log_rtv_stock_rs    = $voucher->variant->log_rtv_stocks->search( {}, { order_by => 'id DESC' } );
    my $num_rtv_logs        = $log_rtv_stock_rs->count();

    # OK for Voucher Deliveries

    ok( $faulty_sp->mark_qcfaulty_voucher( $op_id ), "Can run 'mark_qcfaulty_voucher' method" );

    # get the latest logs created by the above call
    $log_rtv_stock_rs->reset();
    my @rtv_logs    = $log_rtv_stock_rs->all();
    cmp_ok( $faulty_sp->status_id, '==', $STOCK_PROCESS_STATUS__DEAD, 'Faulty SP has Status of DEAD' );
    cmp_ok( $faulty_sp->complete, '==', 1, 'Faulty SP Complete Flag is TRUE' );

    cmp_ok( ( $log_rtv_stock_rs->count() - $num_rtv_logs), '==', 3, 'RTV Logs created' );

    # check first created rtv log
    ok( !defined $rtv_logs[2]->variant_id, '1st RTV Log: Variant Id is NULL' );
    cmp_ok( $rtv_logs[2]->voucher_variant_id, '==', $voucher->variant->id, '1st RTV Log: V.Variant Id as expected' );
    cmp_ok( $rtv_logs[2]->quantity, '==', $faulty_qty, '1st RTV Log: Qty as expected' );
    cmp_ok( $rtv_logs[2]->balance, '==', $faulty_qty, '1st RTV Log: Balance as expected' );
    cmp_ok( $rtv_logs[2]->rtv_action_id, '==', $RTV_ACTION__PUTAWAY__DASH__RTV_PROCESS, '1st RTV Log: Action Id as expected (RTV Process)' );
    cmp_ok( $rtv_logs[2]->operator_id, '==', $op_id, '1st RTV Log: Operator Id as expected' );

    # check second created rtv log
    ok( !defined $rtv_logs[1]->variant_id, '2nd RTV Log: Variant Id is NULL' );
    cmp_ok( $rtv_logs[1]->voucher_variant_id, '==', $voucher->variant->id, '2nd RTV Log: V.Variant Id as expected' );
    cmp_ok( $rtv_logs[1]->quantity, '==', $faulty_qty, '2nd RTV Log: Qty as expected' );
    cmp_ok( $rtv_logs[1]->balance, '==', $faulty_qty, '2nd RTV Log: Balance as expected' );
    cmp_ok( $rtv_logs[1]->rtv_action_id, '==', $RTV_ACTION__PUTAWAY__DASH__DEAD, '2nd RTV Log: Action Id as expected (Dead)' );
    cmp_ok( $rtv_logs[1]->operator_id, '==', $op_id, '2nd RTV Log: Operator Id as expected' );

    # check third created rtv log
    ok( !defined $rtv_logs[0]->variant_id, '3rd RTV Log: Variant Id is NULL' );
    cmp_ok( $rtv_logs[0]->voucher_variant_id, '==', $voucher->variant->id, '3rd RTV Log: V.Variant Id as expected' );
    cmp_ok( $rtv_logs[0]->quantity, '==', 0 - $faulty_qty, '3rd RTV Log: Qty as expected' );
    cmp_ok( $rtv_logs[0]->balance, '==', 0, '3rd RTV Log: Balance as expected' );
    cmp_ok( $rtv_logs[0]->rtv_action_id, '==', $RTV_ACTION__MANUAL_ADJUSTMENT, '3rd RTV Log: Action Id as expected (Manual)' );
    cmp_ok( $rtv_logs[0]->operator_id, '==', $APPLICATION_OPERATOR_ID, '3rd RTV Log: Operator Id as expected' );
    is( $rtv_logs[0]->notes, 'Shredded', '3rd RTV Log: Notes as expected' );

    # roll back changes
    $schema->txn_rollback();

} );  # end $schema->txn_do

# Now do similar for Product Deliveries
$schema->txn_do( sub {
    note "Using Products";

    # set-up test data first
    my (undef,$p)   = Test::XTracker::Data->grab_products({how_many=>1});
    my $po          = Test::XTracker::Data->setup_purchase_order($p->[0]{pid});
    my ($delivery)  = Test::XTracker::Data->create_delivery_for_po( $po->id, 'qc' );
    my ($sp)        = Test::XTracker::Data->create_stock_process_for_delivery( $delivery );

    # split out process with faulty units & test it works for Product Deliveries as well
    my $faulty_sp  = $sp->split_stock_process( $STOCK_PROCESS_TYPE__FAULTY, $faulty_qty, $tmp );
    $sp->discard_changes;
    cmp_ok( $sp->quantity, '==',(10 - $faulty_qty), 'Original SP Qty now less faulty' );
    cmp_ok( $faulty_sp->quantity, '==', $faulty_qty, 'New SP Qty is correct' );
    cmp_ok( $faulty_sp->delivery_item_id, '==', $sp->delivery_item_id, 'New SP Delivery Item Id same as original' );
    cmp_ok( $faulty_sp->type_id, '==', $STOCK_PROCESS_TYPE__FAULTY, 'New SP Type is FAULTY' );
    cmp_ok( $faulty_sp->status_id, '==', $STOCK_PROCESS_STATUS__NEW, 'New SP Status is NEW' );
    ok( defined $faulty_sp->group_id, 'New SP Group Id is defined' );
    # get data ready for next tests
    my $log_rtv_stock_rs= $p->[0]{variant}->log_rtv_stocks->search( {}, { order_by => 'id DESC', rows => 3 } );
    my $num_rtv_logs    = $log_rtv_stock_rs->count();

    #
    # calling 'mark_qcfaulty_voucher' shouldn't make any difference
    # to product deliveries
    #

    dies_ok( sub { $faulty_sp->mark_qcfaulty_voucher( $op_id ); }, "Can't run 'mark_qcfaulty_voucher' method for product delivery" );
    cmp_ok( $faulty_sp->status_id, '==', $STOCK_PROCESS_STATUS__NEW, 'Faulty SP still has Status of NEW' );
    cmp_ok( $faulty_sp->complete, '==', 0, 'Faulty SP Complete Flag is FALSE' );
    # reset the searches to get latest logs
    $log_rtv_stock_rs->reset();
    cmp_ok( $log_rtv_stock_rs->count() , '==', $num_rtv_logs, 'No RTV Logs created' );

    # roll back changes
    $schema->txn_rollback();

} );  # end $schema->txn_do

done_testing;
