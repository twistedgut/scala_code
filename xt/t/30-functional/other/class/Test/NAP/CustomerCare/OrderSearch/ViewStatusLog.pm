package Test::NAP::CustomerCare::OrderSearch::ViewStatusLog;

use NAP::policy 'tt', 'test';
use parent 'NAP::Test::Class';

=head1 NAME

Test::NAP::CustomerCare::OrderSearch::ViewStatusLog

=head1 DESCRIPTION

Tests the 'View Status Log' option on the Left Hand Menu on the Order View page.

=cut

use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB     qw( :shipment_status :shipment_item_status );


sub startup : Test( startup => no_plan ) {
    my $self    = shift;

    $self->SUPER::startup;

    $self->{framework}  = Test::XT::Flow->new_with_traits( {
        traits  => [
            'Test::XT::Data::Order',
            'Test::XT::Flow::CustomerCare',
        ],
    } );

    $self->framework->login_with_roles( {
        main_nav => [
            'Customer Care/Customer Search',
            'Customer Care/Order Search',
        ],
        #setup_fallback_perms => 1,
    } );
    $self->{operator} = $self->mech->logged_in_as_object;
}

sub shutdown : Test( shutdown ) {
    my $self    = shift;

    $self->SUPER::shutdown;
}

sub setup : Test( setup => no_plan ) {
    my $self    = shift;

    $self->SUPER::setup;

    my $order_details   = $self->framework->new_order(
        products    => 3,
        channel     => Test::XTracker::Data->any_channel,
    );
    $self->{order}      = $order_details->{order_object};
    $self->{shipment}   = $order_details->{shipment_object};
}

sub teardown : Test( teardown ) {
    my $self    = shift;

    $self->SUPER::teardown;
}


=head1 TESTS

=head2 test_shipment_logs

Tests that the Shipment & Shipment Item Logs are shown correctly, especially
checks to make sure that Logs that occur in the same minute as one another
are all shown and not just one of them.

=cut

sub test_shipment_logs : Tests {
    my $self    = shift;

    my $framework = $self->framework;

    my $order          = $self->{order};
    my $shipment       = $self->{shipment};
    my @shipment_items = $shipment->shipment_items->all;

    # clear existing logs
    $shipment->shipment_status_logs->delete;
    $shipment->shipment_items->search_related('shipment_item_status_logs')->delete;

    #
    # set-up the log entries for the Shipment
    # and Shipment Items and make sure they
    # all occur in the same minute
    #

    my $log_date = $self->schema->db_now()->truncate( to => 'minute' );

    # populate %expect with what Logs should be on the page
    my %expect;

    # Shipment Log
    foreach my $status_id (
        $SHIPMENT_STATUS__FINANCE_HOLD,
        $SHIPMENT_STATUS__HOLD,
        $SHIPMENT_STATUS__PROCESSING,
    ) {
        $log_date->add( seconds => 1 );
        $shipment->create_related( 'shipment_status_logs', {
            shipment_status_id => $status_id,
            operator_id        => $self->{operator}->id,
            date               => $log_date->clone,
        } );
        # the Logs on the page should be in same sequence
        push @{ $expect{shipment_logs} }, {
            status => $self->rs('Public::ShipmentStatus')->find( $status_id ),
        };
    }

    # Shipment Item Log
    foreach my $status_id (
        $SHIPMENT_ITEM_STATUS__NEW,
        $SHIPMENT_ITEM_STATUS__SELECTED,
        $SHIPMENT_ITEM_STATUS__PICKED,
    ) {
        foreach my $shipment_item ( @shipment_items ) {
            $log_date->add( seconds => 1 );
            $shipment_item->create_related( 'shipment_item_status_logs', {
                shipment_item_status_id => $status_id,
                operator_id             => $self->{operator}->id,
                date                    => $log_date->clone,
            } );
            # the Logs on the page should be in same sequence
            push @{ $expect{shipment_item_logs} }, {
                shipment_item   => $shipment_item,
                status          => $self->rs('Public::ShipmentItemStatus')->find( $status_id ),
                sku             => $shipment_item->get_sku,
            };
        }
    }

    # go to the Status Log page
    $framework->flow_mech__customercare__orderview( $order->id )
                ->flow_mech__customercare__view_status_log;
    my $pg_data = $self->pg_data()->{page_data}{ $shipment->id };

    note "check Shipment Status Logs";
    cmp_ok(
        scalar( @{ $pg_data->{shipment_status_log} } ),
        '==',
        scalar( @{ $expect{shipment_logs} } ),
        "got Expected number of Shipment Status Logs"
    );
    is_deeply(
        [ map { { Status => $_->{Status} } } @{ $pg_data->{shipment_status_log} } ],
        [ map { { Status => $_->{status}->status } } @{ $expect{shipment_logs} } ],
        "and Shipment Status Logs as Expected"
    );

    note "check Shipment Item Status Logs";
    cmp_ok(
        scalar( @{ $pg_data->{shipment_item_status_log} } ),
        '==',
        scalar( @{ $expect{shipment_item_logs} } ),
        "got Expected number of Shipment Item Status Logs"
    );
    is_deeply(
        [ map { { Item => $_->{Item}, Status => $_->{Status} } } @{ $pg_data->{shipment_item_status_log} } ],
        [ map { { Item => $_->{sku},  Status => $_->{status}->status } } @{ $expect{shipment_item_logs} } ],
        "and Shipment Item Status Logs as Expected"
    );
}

#----------------------------------------------------------------------------------

sub framework {
    my $self    = shift;
    return $self->{framework};
}

sub mech {
    my $self    = shift;
    return $self->framework->mech;
}

sub pg_data {
    my $self    = shift;
    return $self->mech->as_data;
}

