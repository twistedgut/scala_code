#!perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Data::Operator;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Mock::Handler;
use Test::XTracker::Mock::PSP;

use XTracker::Handler;
use XTracker::Stock::Reservation::PreOrderSummary;
use XTracker::Constants::PreOrder qw( :pre_order_operator_control );
use XTracker::Constants::FromDB   qw( :department
                                      :authorisation_level );

use base 'Test::Class';

=head1 Pre-Order Summary

Test the data collection for the pre-order summary page

=cut

sub start_tests :Test(startup) {
    my ($self) = @_;

    $self->{schema} = Test::XTracker::Data->get_schema();

    $self->{customer_care_manager_operator} = Test::XTracker::Data::Operator->get_all_operators_for_section_and_authority({
        section    => $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SECTION,
        subsection => $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SUBSECTION,
        level      => $AUTHORISATION_LEVEL__MANAGER,
        department => $DEPARTMENT__PERSONAL_SHOPPING,
    })->first;

    $self->{non_customer_care_operator}
        = $self->{schema}->resultset('Public::Operator')->search({department_id => $DEPARTMENT__DISTRIBUTION})->first;

    # Result-set to return the Expected List of Operators that
    # can be used when transfering ownership of a Pre-Order
    my $operator_rs
        = $self->{schema}->resultset('Public::Operator')
            ->by_authorisation($PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SECTION, $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SUBSECTION)
            ->search( {
                        department_id   => { 'IN' => [ $DEPARTMENT__PERSONAL_SHOPPING, $DEPARTMENT__FASHION_ADVISOR ] },
                        disabled        => 0,
                    }, {});

    # get an Operator for Pre-Orders
    $self->{pre_order_operator} = $operator_rs->first;

    # expected list won't include the Pre-Order's Operator
    $self->{expected_list_of_operators} = $operator_rs->search( {
        'me.id' => { '!=' => $self->{pre_order_operator}->id },
    } );
}

sub start_test :Test(setup) {
    my ($self) = @_;

    $self->{complete_pre_order} = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
        operator => $self->{pre_order_operator},
    } );
}

sub test_payment_using_correct_finance_related_roles :Tests() {
    my ($self) = @_;

    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            pre_order_id  => $self->{complete_pre_order}->id,
        },
        mock_methods => {
            process_template => sub {}
        },
        session => {
            acl => {
                operator_roles => ['app_canViewOrderPaymentDetails']
            }
        },
    });

    my $summary_page = new_ok('XTracker::Stock::Reservation::PreOrderSummary' => [$mock_handler]);

    # Check data collection subs
    is($summary_page->_item_count($self->{complete_pre_order}), 5, 'Pre-order item count');

    ok(defined $summary_page->_payment_details($self->{complete_pre_order}),
       'Payment details available to Finance role');

    my $items = $summary_page->_variants($self->{complete_pre_order});
    ok(defined $items->{(keys %{$items})[rand keys %{$items}]}
                     ->{data},
       'Pre-order contains at least one product');
}

sub test_payment_for_incorrect_role_to_view_payment_details :Tests() {
    my ($self) = @_;

    # Set up request handler with incorrect role
    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            pre_order_id  => $self->{complete_pre_order}->id,
        },
        mock_methods => {
            department_id => sub { return $DEPARTMENT__CUSTOMER_CARE },
            process_template => sub {}
        },
        session => {
            acl => {
                operator_roles => ['app_canViewOrderSearch']
            }
        },

    });

    my $summary_page = new_ok('XTracker::Stock::Reservation::PreOrderSummary' => [$mock_handler]);

    # Ensure no card data for non-finance bods
    is($summary_page->_payment_details($self->{complete_pre_order}),
       undef,
       'Payment details not available for incorrect role');
}

=head2 test_operator_transfer_for_owner

=cut

sub test_show_operator_list_for_owner :Tests() {
    my ($self) = @_;

    # Set up Customer Care request handler
    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            pre_order_id  => $self->{complete_pre_order}->id,
        },
        mock_methods => {
            department_id => sub { return $DEPARTMENT__CUSTOMER_CARE },
            operator_id   => sub { return $self->{complete_pre_order}->operator_id },
            process_template => sub {}
        }
    });

    my $summary_page = new_ok('XTracker::Stock::Reservation::PreOrderSummary' => [$mock_handler]);
    $summary_page->process();

    ok(exists($mock_handler->{data}{new_operator_list}), 'Operator list exists');
    cmp_ok(@{$mock_handler->{data}{new_operator_list}}, '==', $self->{expected_list_of_operators}, 'Operator list has values');
}

=head2 test_operator_transfer_for_manager

=cut

sub test_show_operator_list_for_manager :Tests() {
    my ($self) = @_;

    # Set up Customer Care request handler
    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            pre_order_id  => $self->{complete_pre_order}->id,
        },
        mock_methods => {
            department_id => sub { return $DEPARTMENT__CUSTOMER_CARE },
            operator_id   => sub { return $self->{customer_care_manager_operator}->id },
            process_template => sub {}
        }
    });

    my $summary_page = new_ok('XTracker::Stock::Reservation::PreOrderSummary' => [$mock_handler]);
    $summary_page->process();

    ok(exists($mock_handler->{data}{new_operator_list}), 'Operator list exists');
    cmp_ok(@{$mock_handler->{data}{new_operator_list}}, '==', $self->{expected_list_of_operators}, 'Operator list has values');
}

=head2 test_operator_transfer_for_non_owner

=cut

sub test_show_operator_list_for_non_owner :Tests() {
    my ($self) = @_;

    # Set up Customer Care request handler
    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            pre_order_id  => $self->{complete_pre_order}->id,
        },
        mock_methods => {
            department_id => sub { return $DEPARTMENT__CUSTOMER_CARE },
            operator_id   => sub { return $self->{non_customer_care_operator}->id },
            process_template => sub {}
        }
    });

    my $summary_page = new_ok('XTracker::Stock::Reservation::PreOrderSummary' => [$mock_handler]);
    $summary_page->process();

    ok(exists($mock_handler->{data}{new_operator_list}), 'Operator list exists');
    cmp_ok(@{$mock_handler->{data}{new_operator_list}}, '==', 0, 'Operator list is empty');

}

Test::Class->runtests;

1;
