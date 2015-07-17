package Test::XTracker::Navigation;

use NAP::policy     qw( test );
use parent 'NAP::Test::Class';

=head1 NAME

Test::XTracker::Navigation

=head1 DESCRIPTION

Testing the 'XTracker::Navigation' Module.

=cut

use Test::XTracker::Data;
use Test::XTracker::Mock::Handler;

use XTracker::Order::Functions::Order::OrderView    qw();

use XTracker::Constants::FromDB qw(
    :department
    :order_status
    :shipment_status
);

use Storable        qw( dclone );


sub start_up : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    use_ok( 'XTracker::Navigation', qw(
        build_orderview_sidenav
    ) );
    can_ok( 'XTracker::Navigation', qw(
        build_orderview_sidenav
    ) );
}

sub setup: Test( setup => no_plan ) {
    my $self =  shift;
    $self->SUPER::setup;
}

sub teardown : Test( teardown ) {
    my $self = shift;
    $self->SUPER::teardown;
}

=head1 TESTS

=head2 test_build_orderview_sidenav

=cut

sub test_build_orderview_sidenav : Tests() {
    my $self = shift;

    my %expected_options = (
        $DEPARTMENT__FINANCE => {
            'None' => bag(
                'Back',
                'View Access Log',
                'View Status Log',
            ),
            'Order' => bag(
                'Credit Hold',
                'Credit Check',
                'Accept Order',
                'Edit Order',
                'Edit Billing Address',
                'Cancel Order',
                'Pre-Authorise Order',
                'Remove Watch',
                'Add Watch',
                'Send Email',
                'Add Note',
            ),
            'Customer' => bag(
                'Contact History',
            ),
            'Shipment' => bag(
                'Edit Shipment',
                'Edit Shipping Address',
                'Hold Shipment',
                'Check Pricing',
                'Create Credit/Debit',
                'Add Note',
            ),
            'Fraud Rules' => bag(
                'Show Outcome',
                'Test Using Live',
                'Test Using Staging',
            ),
        },
        $DEPARTMENT__CUSTOMER_CARE => {
            'None' => bag(
                'Back',
                'View Access Log',
                'View Status Log',
            ),
            'Order' => bag(
                'Credit Hold',
                'Credit Check',
                'Accept Order',
                'Edit Order',
                'Edit Billing Address',
                'Cancel Order',
                'Send Email',
                'Add Note',
            ),
            'Customer' => bag(
                'Add Watch',
                'Remove Watch',
                'Contact History',
            ),
            'Shipment' => bag(
                'Edit Shipment',
                'Edit Shipping Address',
                'Hold Shipment',
                'Check Pricing',
                'Dispatch/Return',
                'Lost Shipment',
                'Add Note',
                'Cancel Re-Shipment',
            ),
            'Shipment Item' => bag(
                'Cancel Shipment Item',
                'Size Change',
                'Returns',
            ),
            'Fraud Rules' => bag(
                'Show Outcome',
                'Test Using Live',
                'Test Using Staging',
            ),
        },
        $DEPARTMENT__CUSTOMER_CARE_MANAGER => {
            'None' => bag(
                'Back',
                'View Access Log',
                'View Status Log',
            ),
            'Order' => bag(
                'Credit Hold',
                'Credit Check',
                'Accept Order',
                'Edit Order',
                'Edit Billing Address',
                'Cancel Order',
                'Send Email',
                'Add Note',
            ),
            'Customer' => bag(
                'Add Watch',
                'Remove Watch',
                'Contact History',
            ),
            'Shipment' => bag(
                'Edit Shipment',
                'Edit Shipping Address',
                'Hold Shipment',
                'Amend Pricing',
                'Check Pricing',
                'Create Credit/Debit',
                'Dispatch/Return',
                'Lost Shipment',
                'Add Note',
                'Cancel Re-Shipment',
            ),
            'Shipment Item' => bag(
                'Cancel Shipment Item',
                'Size Change',
                'Returns',
            ),
            'Fraud Rules' => bag(
                'Show Outcome',
                'Test Using Live',
                'Test Using Staging',
            ),
        },
        $DEPARTMENT__SHIPPING => {
            'None' => bag(
                'Back',
                'View Access Log',
                'View Status Log',
            ),
            'Order' => bag(
                'Credit Hold',
                'Credit Check',
                'Accept Order',
                'Edit Order',
                'Edit Billing Address',
                'Cancel Order',
                'Send Email',
                'Add Note',
            ),
            'Customer' => bag(
                'Contact History',
            ),
            'Shipment' => bag(
                'Edit Shipment',
                'Edit Shipping Address',
                'Hold Shipment',
                'Check Pricing',
                'Dispatch/Return',
                'Lost Shipment',
                'Add Note',
                'Cancel Re-Shipment',
            ),
            'Shipment Item' => bag(
                'Cancel Shipment Item',
                'Size Change',
                'Returns',
            ),
            'Fraud Rules' => bag(
                'Show Outcome',
                'Test Using Live',
                'Test Using Staging',
            ),
        },
        $DEPARTMENT__SHIPPING_MANAGER => {
            'None' => bag(
                'Back',
                'View Access Log',
                'View Status Log',
            ),
            'Order' => bag(
                'Credit Hold',
                'Credit Check',
                'Accept Order',
                'Edit Order',
                'Edit Billing Address',
                'Cancel Order',
                'Send Email',
                'Add Note',
            ),
            'Customer' => bag(
                'Contact History',
            ),
            'Shipment' => bag(
                'Edit Shipment',
                'Edit Shipping Address',
                'Hold Shipment',
                'Check Pricing',
                'Create Credit/Debit',
                'Dispatch/Return',
                'Lost Shipment',
                'Add Note',
                'Cancel Re-Shipment',
            ),
            'Shipment Item' => bag(
                'Cancel Shipment Item',
                'Size Change',
                'Returns',
            ),
            'Fraud Rules' => bag(
                'Show Outcome',
                'Test Using Live',
                'Test Using Staging',
            ),
        },
        $DEPARTMENT__DISTRIBUTION_MANAGEMENT => {
            'None' => bag(
                'Back',
                'View Access Log',
                'View Status Log',
            ),
            'Order' => bag(
                'Credit Hold',
                'Credit Check',
                'Accept Order',
                'Edit Order',
                'Edit Billing Address',
                'Cancel Order',
                'Send Email',
                'Add Note',
            ),
            'Customer' => bag(
                'Contact History',
            ),
            'Shipment' => bag(
                'Edit Shipment',
                'Edit Shipping Address',
                'Hold Shipment',
                'Check Pricing',
                'Dispatch/Return',
                'Create Shipment',
                'Add Note',
                'Cancel Re-Shipment',
            ),
            'Shipment Item' => bag(
                'Cancel Shipment Item',
                'Size Change',
                'Returns',
            ),
            'Fraud Rules' => bag(
                'Show Outcome',
                'Test Using Live',
                'Test Using Staging',
            ),
        },
        $DEPARTMENT__STOCK_CONTROL => {
            'None' => bag(
                'Back',
                'View Access Log',
                'View Status Log',
            ),
            'Order' => bag(
                'Credit Hold',
                'Credit Check',
                'Accept Order',
                'Edit Order',
                'Edit Billing Address',
                'Cancel Order',
                'Send Email',
                'Add Note',
            ),
            'Customer' => bag(
                'Contact History',
            ),
            'Shipment' => bag(
                'Edit Shipment',
                'Edit Shipping Address',
                'Hold Shipment',
                'Check Pricing',
                'Dispatch/Return',
                'Add Note',
                'Cancel Re-Shipment',
            ),
            'Shipment Item' => bag(
                'Cancel Shipment Item',
                'Size Change',
            ),
            'Fraud Rules' => bag(
                'Show Outcome',
                'Test Using Live',
                'Test Using Staging',
            ),
        },
        $DEPARTMENT__PERSONAL_SHOPPING => {
            'None' => bag(
                'Back',
                'View Access Log',
                'View Status Log',
            ),
            'Order' => bag(
                'Credit Hold',
                'Credit Check',
                'Accept Order',
                'Edit Order',
                'Cancel Order',
                'Add Note',
            ),
            'Customer' => bag(
                'Contact History',
            ),
            'Shipment' => bag(
                'Edit Shipment',
                'Edit Shipping Address',
                'Hold Shipment',
                'Check Pricing',
                'Add Note',
            ),
            'Shipment Item' => bag(
                'Cancel Shipment Item',
                'Size Change',
                'Returns',
            ),
            'Fraud Rules' => bag(
                'Show Outcome',
                'Test Using Live',
                'Test Using Staging',
            ),
        },
        $DEPARTMENT__FASHION_ADVISOR => {
            same_as => $DEPARTMENT__PERSONAL_SHOPPING,
        },
        # what all other Departments should get
        'DEFAULT' => {
            'None' => bag(
                'Back',
                'View Access Log',
                'View Status Log',
            ),
            'Order' => bag(
                'Credit Hold',
                'Credit Check',
                'Accept Order',
                'Add Note',
            ),
            'Customer' => bag(
                'Contact History',
            ),
            'Shipment' => bag(
                'Add Note',
            ),
            'Shipment Item' => bag(
                'Returns',
            ),
            'Fraud Rules' => bag(
                'Show Outcome',
                'Test Using Live',
                'Test Using Staging',
            ),
        }
    );

    # specify the bits of data required by the function
    my $data = {
        orders_id           => 7654321,
        short_url           => '/Section/SubSection',
        num_shipments       => 1,
        master_shipment_id  => 1234567,
        orders => {
            customer_id => 9101112
        },
        customer => {
            email       => 'test@example.com',
        },
    };

    my @departments = $self->rs('Public::Department')->all;

    foreach my $department ( @departments ) {
        note "Testing Department: " . $department->department;

        $data->{department_id}  = $department->id;

        my $sidenav = build_orderview_sidenav( $data );

        my %got     = map {
            $_ => [ keys %{ $sidenav->{ $_ } } ],
        } keys %{ $sidenav };

        my $expect  = $expected_options{ $department->id } // $expected_options{'DEFAULT'};
        $expect     = $expected_options{ $expect->{same_as} }   if ( exists( $expect->{same_as} ) );

        cmp_deeply( \%got, $expect, "Sidenav Options are as Expected for the Department" );
    }
}

=head2 test_OrderView__build_left_navigation

=cut

sub test_OrderView__build_left_navigation : Tests() {
    my $self = shift;

    my $master_ship_id = 1234567;

    my $data = {
        orders_id           => 7654321,
        short_url           => '/Section/SubSection',
        num_shipments       => 1,
        master_shipment_id  => $master_ship_id,
        dispatched_shipments => 1,
        active_shipments    => 1,
        packed              => 1,
        re_shipments        => 0,
        orders => {
            customer_id     => 9101112,
            order_status_id => 1,
            watchFlags => {
                FinanceWatch  => 0,
                CustomerWatch => 0,
            },
        },
        customer => {
            email       => 'test@example.com',
        },
        shipments => {
            $master_ship_id => {
                shipment_status_id => 4,
            },
        },
        order_payment => {
            fulfilled => 0,
        },
    };

    my $shipment_statuses = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::ShipmentStatus', {
        not_allow => [ $SHIPMENT_STATUS__CANCELLED, $SHIPMENT_STATUS__LOST, $SHIPMENT_STATUS__DISPATCHED ],
    } );

    my %tests = (
        'Order/Accept Order' => {
            shown => [
                { orders => { order_status_id => $ORDER_STATUS__CREDIT_HOLD } },
                { orders => { order_status_id => $ORDER_STATUS__CREDIT_CHECK } },
            ],
            not_shown => [
                { orders => { order_status_id => $ORDER_STATUS__ACCEPTED } },
                { orders => { order_status_id => $ORDER_STATUS__CANCELLED } },
            ],
        },
        'Order/Credit Check' => {
            shown => [
                { orders => { order_status_id => $ORDER_STATUS__CREDIT_HOLD } },
            ],
            not_shown => [
                { orders => { order_status_id => $ORDER_STATUS__CREDIT_CHECK } },
                { orders => { order_status_id => $ORDER_STATUS__ACCEPTED } },
                { orders => { order_status_id => $ORDER_STATUS__CANCELLED } },
            ],
        },
        'Order/Credit Hold' => {
            shown => [
                { orders => { order_status_id => $ORDER_STATUS__ACCEPTED } },
            ],
            not_shown => [
                { orders => { order_status_id => $ORDER_STATUS__CREDIT_HOLD } },
                { orders => { order_status_id => $ORDER_STATUS__CREDIT_CHECK } },
                { orders => { order_status_id => $ORDER_STATUS__CANCELLED } },
            ],
        },
        'Order/Pre-Authorise Order' => {
            shown     => [ { order_payment => { fulfilled => 0 } } ],
            not_shown => [ { order_payment => { fulfilled => 1 } } ],
        },
        'Order/Remove Watch'        => {
            shown     => [ { orders => { watchFlags => { FinanceWatch => 1 } } } ],
            not_shown => [ { orders => { watchFlags => { FinanceWatch => 0 } } } ],
        },
        'Order/Add Watch'           => {
            shown     => [ { orders => { watchFlags => { FinanceWatch => 0 } } } ],
            not_shown => [ { orders => { watchFlags => { FinanceWatch => 1 } } } ],
        },
        'Customer/Remove Watch'     => {
            shown     => [ { orders => { watchFlags => { CustomerWatch => 1 } } } ],
            not_shown => [ { orders => { watchFlags => { CustomerWatch => 0 } } } ],
        },
        'Customer/Add Watch'        => {
            shown     => [ { orders => { watchFlags => { CustomerWatch => 0 } } } ],
            not_shown => [ { orders => { watchFlags => { CustomerWatch => 1 } } } ],
        },
        'Order/Cancel Order'        => {
            always_shown_for_department => $DEPARTMENT__FINANCE,
            shown     => [
                { orders => { order_status_id => $ORDER_STATUS__ACCEPTED },
                  dispatched_shipments => 0 },
                { orders => { order_status_id => $ORDER_STATUS__CREDIT_HOLD },
                  dispatched_shipments => 0 },
                { orders => { order_status_id => $ORDER_STATUS__CREDIT_CHECK },
                  dispatched_shipments => 0 },
            ],
            not_shown => [
                { orders => { order_status_id => $ORDER_STATUS__CANCELLED } },
                { orders => { order_status_id => $ORDER_STATUS__ACCEPTED },
                  dispatched_shipments => 1 },
                { orders => { order_status_id => $ORDER_STATUS__CREDIT_HOLD },
                  dispatched_shipments => 1 },
                { orders => { order_status_id => $ORDER_STATUS__CREDIT_CHECK },
                  dispatched_shipments => 1 },
            ],
        },
        'Shipment Item/Cancel Shipment Item' => {
            shown     => [
                map {
                    { shipments => { $master_ship_id => { shipment_status_id => $_->id } } }
                } @{ $shipment_statuses->{allowed} }
            ],
            not_shown => [
                map {
                    { shipments => { $master_ship_id => { shipment_status_id => $_->id } } }
                } @{ $shipment_statuses->{not_allowed} }
            ],
        },
        'Shipment/Hold Shipment'    => {
            always_shown_for_department => $DEPARTMENT__FINANCE,
            shown     => [ { active_shipments => 1 } ],
            not_shown => [ { active_shipments => 0 } ],
        },
        'Shipment Item/Returns'     => {
            shown     => [ { dispatched_shipments => 1 } ],
            not_shown => [ { dispatched_shipments => 0 } ],
        },
        'Shipment/Lost Shipment'    => {
            shown     => [ { dispatched_shipments => 1 } ],
            not_shown => [ { dispatched_shipments => 0 } ],
        },
        'Shipment/Amend Pricing'    => {
            shown     => [ { order_payment => { fulfilled => 0 } } ],
            not_shown => [ { order_payment => { fulfilled => 1 } } ],
        },
        'Shipment/Check Pricing'    => {
            always_shown_for_department => $DEPARTMENT__FINANCE,
            shown     => [ { order_payment => { fulfilled => 0 } } ],
            not_shown => [ { order_payment => { fulfilled => 1 } } ],
        },
        'Shipment/Dispatch/Return'  => {
            shown     => [ { packed => 1, active_shipments => 1 } ],
            not_shown => [ { packed => 0, active_shipments => 1 }, { packed => 1, active_shipments => 0 } ],
        },
        'Shipment/Create Shipment'  => {
            shown     => [ { dispatched_shipments => 1 } ],
            not_shown => [ { dispatched_shipments => 0 } ],
        },
        'Shipment/Create Credit/Debit' => {
            always_shown_for_department => $DEPARTMENT__FINANCE,
            shown     => [ { dispatched_shipments => 1 } ],
            not_shown => [ { dispatched_shipments => 0 } ],
        },
        'Shipment/Cancel Re-Shipment'  => {
            shown     => [ { re_shipments => 1 } ],
            not_shown => [ { re_shipments => 0 } ],
        },
    );

    my @departments = $self->rs('Public::Department')->all;

    foreach my $option ( keys %tests ) {
        my $test = $tests{ $option };

        subtest "Testing Option: '${option}'" => sub {
            foreach my $department ( @departments ) {
                my $test_suffix = ", Department - '(" . $department->id . ") " . $department->department . "'";

                my $test_clone = dclone( $test );

                my $raw_sidenav = $self->_flatten_raw_sidenav_for_department( $department, $data );
                #diag p( $raw_sidenav );

                if ( !exists( $raw_sidenav->{ $option } ) ) {
                    push @{ $test_clone->{not_shown} }, @{ delete $test_clone->{shown} }
                }
                else {
                    if ( ( $test_clone->{always_shown_for_department} // 0 ) == $department->id ) {
                        shift @{ $test_clone->{not_shown} }     if ( $option eq 'Order/Cancel Order' );
                        push @{ $test_clone->{shown} }, @{ delete $test_clone->{not_shown} }
                    }
                }

                my $counter = 0;
                foreach my $scenario ( @{ $test_clone->{shown} } ) {
                    $counter++;
                    my $flattened_sidenav = $self->_get_flattened_orderview_sidenav_for_department( $department, $data, $scenario );
                    ok( exists( $flattened_sidenav->{ $option } ), "Option found in Menu for Scenario ${counter}${test_suffix}" )
                                        or diag "Dump of Scenario Data: " . p( $scenario );
                }

                $counter = 0;
                foreach my $scenario ( @{ $test_clone->{not_shown} } ) {
                    $counter++;
                    my $flattened_sidenav = $self->_get_flattened_orderview_sidenav_for_department( $department, $data, $scenario );
                    ok( !exists( $flattened_sidenav->{ $option } ), "Option not found in Menu for Scenario ${counter}${test_suffix}" )
                                        or diag "Dump of Scenario Data: " . p( $scenario );
                }
            }
        };
    }
}

#-----------------------------------------------------------------------------

sub _get_flattened_orderview_sidenav_for_department {
    my ( $self, $department, $base_data, $scenario_data ) = @_;

    my $data_clone = dclone( $base_data );
    $data_clone->{department_id} = $department->id;

    my $merged_data = Catalyst::Utils::merge_hashes( $data_clone, $scenario_data );
    my $mock_handler = Test::XTracker::Mock::Handler->new( {
        data => $merged_data,
        mock_methods => {
            operator_authorised => sub { return 1 },
        },
    } );

    my $sidenav = XTracker::Order::Functions::Order::OrderView::_build_left_navigation( $mock_handler );
    return $self->_flatten_built_sidenav( $sidenav );
}

sub _flatten_built_sidenav {
    my ( $self, $sidenav ) = @_;

    my %retval;

    GROUP:
    foreach my $group ( @{ $sidenav } ) {
        next GROUP           if ( !$group );

        my ( $heading_name ) = keys %{ $group };        # there is only ever one heading per group
        my $options          = $group->{ $heading_name };
        %retval = (
            %retval,
            map { "${heading_name}/" . $_->{title} => 1 } @{ $options }
        );
    }

    return \%retval;
}

sub _flatten_raw_sidenav_for_department {
    my ( $self, $department, $data ) = @_;

    my $data_clone = dclone( $data );
    $data_clone->{department_id} = $department->id;

    my $sidenav = build_orderview_sidenav( $data_clone );

    my %retval;
    foreach my $heading_name ( keys %{ $sidenav } ) {
        %retval = (
            %retval,
            map { "${heading_name}/" . $_ => 1 } keys %{ $sidenav->{ $heading_name } }
        );
    }

    return \%retval;
}

