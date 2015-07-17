#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 NAME

pre_order_summary.t - Pre-Order Summary Page Tests

=head1 DESCRIPTION

General tests for the Pre-Order Summary page. This is the page that is reached after finding
a Pre-Order and then Clicking on it, it's the Pre-Order version of the Order View page.

#TAGS inventory preorder preorderview cando

=cut

use Test::XTracker::Data;
use Test::XTracker::Mock::PSP;
use Test::XT::Flow;

use XTracker::Utilities                 qw( format_currency_2dp );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw (
                                            :authorisation_level
                                            :pre_order_status
                                            :pre_order_item_status
                                        );
use Test::XTracker::Data::PreOrder;

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Reservations',
        'Test::XT::Data::Channel',      # required for PreOrder
        'Test::XT::Data::Customer',     # required for PreOrder
        'Test::XT::Data::PreOrder',
    ],
);

#---------- run tests ----------
_test_pre_order_summary_page( $framework, 1 );
#-------------------------------

done_testing();

=head1 METHODS

=head2 _test_pre_order_summary_page

    _test_pre_order_summary_page( $framework, $ok_to_do_flag );

General tests for the Pre-Order Summary page:
    * Checks the Total Order Value
    * Checks the Pre-Order Status Log table at the bottom of the page
    * Checks the Total Order Value after an Item has been Cancelled
    * Checks OrderView page can be reached from pre_order_item status.

=cut

sub _test_pre_order_summary_page {
    my ( $framework, $oktodo )  = @_;

    SKIP: {
        skip "_test_pre_order_summary_page", 1      if ( !$oktodo );

        note "TESTING 'Pre-Order Summary' page";

        # 'set_department' should return the Operator Record of the user it's updating
        my $itgod_op    = Test::XTracker::Data->set_department( 'it.god', 'Customer Care' );
        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                    'Customer Care/Order Search',
                    'Stock Control/Reservation',
                ]
            }
        } );
        my $pre_order   = $framework->pre_order;
        my $pre_order_id= $pre_order->id;
        my @pre_order_items = $pre_order->pre_order_items
                                            ->search( undef, { order_by => 'id' } )
                                                ->all;
        my $mech        = $framework->mech;


        note "Check for Status Logs showing on the page";
        # remove all Statuses
        $pre_order->pre_order_status_logs->delete;
        $pre_order->pre_order_items->search_related('pre_order_item_status_logs')->delete;

        $framework->mech__reservation__pre_order_summary( $pre_order_id );
        _check_status_logs_on_page( $mech, $pre_order );
        my $pre_order_value_on_page = $mech->as_data->{pre_order_total};
        my $expected_value_on_page  = format_currency_2dp( $pre_order->total_value );
        is( $pre_order_value_on_page, $expected_value_on_page, "Total Pre-Order Value correct on page: " . $expected_value_on_page );

        note "when there are only Pre-Order Status Logs";
        $pre_order->update_status( $PRE_ORDER_STATUS__COMPLETE );
        $framework->mech__reservation__pre_order_summary( $pre_order_id );
        _check_status_logs_on_page( $mech, $pre_order );

        note "when there are only Pre-Order Item Status Logs";
        $pre_order->pre_order_status_logs->delete;
        $_->update_status( $PRE_ORDER_ITEM_STATUS__COMPLETE )      foreach ( @pre_order_items );
        $framework->mech__reservation__pre_order_summary( $pre_order_id );
        _check_status_logs_on_page( $mech, $pre_order );

        note "when there are both Logs";
        $pre_order->update_status( $PRE_ORDER_STATUS__COMPLETE );
        $framework->mech__reservation__pre_order_summary( $pre_order_id );
        _check_status_logs_on_page( $mech, $pre_order );

        note "when there are multiple Statuses for both Pre-Order & Pre-Order Items";
        _discard_changes( $pre_order, @pre_order_items );
        $pre_order->update_status( $PRE_ORDER_STATUS__PART_EXPORTED );
        $_->update_status( $PRE_ORDER_ITEM_STATUS__EXPORTED )       foreach ( @pre_order_items[3,4] );
        # cancel an Item and also check the Total Value is reduced
        $pre_order_items[1]->update_status( $PRE_ORDER_ITEM_STATUS__CANCELLED );
        $expected_value_on_page = $pre_order->total_value -
                                            ( $pre_order_items[1]->tax +
                                              $pre_order_items[1]->duty +
                                              $pre_order_items[1]->unit_price );
        $expected_value_on_page = format_currency_2dp( $expected_value_on_page );     # format it nicely

        $framework->mech__reservation__pre_order_summary( $pre_order_id );
        _check_status_logs_on_page( $mech, $pre_order );
        $pre_order_value_on_page= $mech->as_data->{pre_order_total};
        is( $pre_order_value_on_page, $expected_value_on_page, "Total Pre-Order Value correct on page less Cancellations: " . $expected_value_on_page );

        # part exported preorder
        my ( $pre_order_part_exported ) = Test::XTracker::Data::PreOrder->create_part_exported_pre_order();
        $framework->mech__reservation__pre_order_summary( $pre_order_part_exported->id );
        _check_pre_order_item_status( $mech, $pre_order );
    };

    return $framework;
}

=head2 _check_pre_order_item_status

    _check_pre_order_item_status( $mech_object, $dbic_pre_order );

Checks that PreOrder Items status is linked to Order View page if it has exported status on the summary page.

=cut

sub _check_pre_order_item_status {
    my ( $mech, $pre_order )    = @_;

    my $pg_data = $mech->as_data();
    my $data    = $mech->as_data()->{pre_order_item_list};

    foreach my $item ( @{$data} ) {
        my $status = $item->{Status};
        if(ref($status) eq "HASH" ) {
           cmp_ok( $status->{value}, 'eq',"Exported" ,"SKU: ". $item->{SKU}. " has Correct Status");
           like( $status->{url},
                 qr/\/CustomerCare\/OrderSearch\/OrderView\?order_id=/,
                 "SKU:" . $item->{SKU}. "has the link to order view page"
           );
        } else {
           cmp_ok( $status, 'eq',"Complete" ,"SKU: ". $item->{SKU}. " has Correct Status");
        }
    }

}

=head2 _check_status_logs_on_page

    _check_status_logs_on_page( $mech_object, $dbic_pre_order );

Checks that Status Logs appear on the summary page when they should.

=cut

sub _check_status_logs_on_page {
    my ( $mech, $pre_order )    = @_;

    my $pg_data             = $mech->as_data();
    my $pre_order_log       = $pg_data->{log_pre_order_status};
    my $pre_order_item_log  = $pg_data->{log_pre_order_item_status};

    if ( $pre_order->pre_order_status_logs->count ) {
        my $expected_list   = $pre_order->pre_order_status_logs->status_log_for_summary_page;
        foreach my $idx ( 0..$#{ $expected_list } ) {
            my $on_page = $pre_order_log->[ $idx ];
            my $expected= $expected_list->[ $idx ];

            my $prefix  = "Pre-Order Status Log Id: " . $expected->{log_id};
            is( $on_page->{Date}, $expected->{status_date}, "${prefix}, Date as Expected: " . $expected->{status_date} );
            is( $on_page->{Status}, $expected->{status}, "${prefix}, Status as Expected: " . $expected->{status} );
        }
    }
    else {
        ok( !$pre_order_log, "When there are NO Pre-Order Status logs, 'Pre-Order Status Log' isn't shown" );
    }

    if ( $pre_order->pre_order_items->search_related('pre_order_item_status_logs')->count ) {
        my $expected_list   = $pre_order->pre_order_items->status_log_for_summary_page;
        foreach my $idx ( 0..$#{ $expected_list } ) {
            my $on_page = $pre_order_item_log->[ $idx ];
            my $expected= $expected_list->[ $idx ];

            my $prefix  = "Pre-Order Item Status Log Id: " . $expected->{log_id} . ", Item Id: " . $expected->{item_obj}->id;
            is( $on_page->{Date}, $expected->{status_date}, "${prefix}, Date as Expected: " . $expected->{status_date} );
            is( $on_page->{Status}, $expected->{status}, "${prefix}, Status as Expected: " . $expected->{status} );
            is( $on_page->{SKU}, $expected->{item_obj}->variant->sku, "${prefix}, SKU as Expected: " . $expected->{item_obj}->variant->sku );
        }
    }
    else {
        ok( !$pre_order_item_log, "When there are NO Pre-Order Item Status logs, 'Pre-Order Item Status Log' isn't shown" );
    }

    return;
}

=head2 _discard_changes

    _discard_changes( @dbic_records );

Discard changes for an array of records

=cut

sub _discard_changes {
    my @recs    = @_;

    foreach my $rec ( @recs ) {
        $rec->discard_changes;
    }

    return;
}
