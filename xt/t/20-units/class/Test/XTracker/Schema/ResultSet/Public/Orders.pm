package Test::XTracker::Schema::ResultSet::Public::Orders;
use NAP::policy "tt", qw/test class/;
BEGIN {
    extends 'NAP::Test::Class';
    with qw/Test::Role::WithSchema Test::Role::DBSamples/;
};
use FindBin::libs;

sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    require_ok( 'XTracker::Schema::ResultSet::Public::Orders' );

}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();

    $self->schema->txn_begin;
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    $self->schema->txn_rollback;
}


sub _from_text_ok {
    my ($self,  $orders, $expected_invalid, $expected_valid, $message, $pattern ) = @_;

    my $invalid   = [];

    # Call the from_text method.
    my $resultset = $self->schema->resultset('Public::Orders')->from_text( $orders, $invalid, $pattern );

    # Test we have the right invalid orders.
    cmp_ok( @$invalid, '==', scalar @$expected_invalid, "$message: Got the right number of invalid orders" );
    cmp_deeply( $invalid, bag( @{ $expected_invalid } ), "$message: Got the right invalid orders" );

    # Test we have the right number of valid orders.
    cmp_ok( $resultset->count, '==', scalar @$expected_valid, "$message: Got the right number of orders" );

    # Test the valid orders are correct.
    foreach my $order_nr ( @$expected_valid ) {
        ok(
            grep( { $_->order_nr eq $order_nr } $resultset->all ),
            "$message: Order number $order_nr is present in the results"
        );
    }

}

sub test_from_text : Tests {
    my $self = shift;

    # Create orders.
    my $order1 = $self->test_data->new_order( products => 1 )->{order_object};
    my $order2 = $self->test_data->new_order( products => 1 )->{order_object};
    my $order3 = $self->test_data->new_order( products => 1 )->{order_object};

    my $order1_nr = $order1->order_nr;
    my $order2_nr = $order2->order_nr;
    my $order3_nr = $order3->order_nr;

    # Test non-digit characters.
    $self->_from_text_ok(
        "${_}${order1_nr}${_}${order2_nr}${_}",
        [],
        [ $order1_nr, $order2_nr ],
        "Test non-digit characters ($_)"
    ) foreach (
        qw( a ! " £ $ % ^ & * : @ ~ ; ' < > ? . / \ | - + z ),
        ' ',
        '#',
        ','
    );

    # Expected invalid order details.
    my $invalid = {
        order_nr => '9999999999',
        reason => 'Does not exist'
    };

    # One valid and one invalid order.
    $self->_from_text_ok(
        "$order1_nr 9999999999",
        [ $invalid ],
        [ $order1_nr ],
        'One valid and one invalid order'
    );

    # Two valid and one invalid order.
    $self->_from_text_ok(
        "$order1_nr 9999999999 $order2_nr",
        [ $invalid ],
        [ $order1_nr, $order2_nr ],
        'Two valid and one invalid order'
    );

    note "Test passing a Pattern to the 'from_text' method";

    # update a some of the Orders to Alpha Numeric Order
    # Numbers so that the use of a Pattern can be tested
    $order2->update( { order_nr => 'GFDR' . $order2->id } );
    $order3->update( { order_nr => 'FRRE' . $order3->id } );

    $order2_nr = $order2->discard_changes->order_nr;
    $order3_nr = $order3->discard_changes->order_nr;

    # Find Order Numbers which are Alphanumeric
    $self->_from_text_ok(
        "${order2_nr} ${order3_nr} ${order1_nr}",
        [],
        [ $order2_nr, $order3_nr ],
        "Using a Pattern that Only wants Alpha Numeric Order Numbers",
        qr/([A-Z]+\d+)/,
    );

    $invalid = {
        order_nr => 'NOT12124',
        reason => 'Does not exist'
    };

    # back to back Alpha Numeric Order Numbers
    $self->_from_text_ok(
        "${order2_nr}${order3_nr}NOT12124",
        [ $invalid ],
        [ $order2_nr, $order3_nr ],
        "Finding Back to Back Alpha Numeric Order Numbers",
        qr/([A-Z]+\d+)/,
    );

    $invalid = [
        {
            order_nr => 'SDF99909',
            reason => 'Does not exist'
        },
        {
            order_nr => '124214',
            reason => 'Does not exist'
        },
    ];

    # Using a Pattern on a Multi Line find both Alpha Numeric & Numeric Order Numbers
    my $multi_line =<<STR
order number is${order2_nr}
${order3_nr}
${order1_nr} 124214
SDF99909
STR
;
    $self->_from_text_ok(
        $multi_line,
        $invalid,
        [ $order1_nr, $order2_nr, $order3_nr ],
        "On A Multi Line using a Pattern to find both Alpha Numric & Numeric Order Numbers",
        qr/([A-Z]+\d+|\d+)/,
    );
}

=head2 test_from_text_with_jc_alpha_numeric_order_numbers

Tests that Jimmy Choo Specific Order Numbers can be found using 'from_text'.

=cut

sub test_from_text_with_jc_alpha_numeric_order_numbers : Tests {
    my $self = shift;

    my $order1 = $self->test_data->new_order( products => 1 )->{order_object};
    my $order2 = $self->test_data->new_order( products => 1 )->{order_object};
    my $order3 = $self->test_data->new_order( products => 1 )->{order_object};
    my $order4 = $self->test_data->new_order( products => 1 )->{order_object};

    # update some of the Orders to have Jimmy
    # Choo style Alpha Numeric Order Numbers
    $order1->update( { order_nr => 'JCHGB00'  . $order1->id } );
    $order2->update( { order_nr => 'JCHROW00' . $order2->id } );
    $order3->update( { order_nr => 'JCHUS00'  . $order3->id } );

    my $order1_nr = $order1->order_nr;
    my $order2_nr = $order2->order_nr;
    my $order3_nr = $order3->order_nr;
    my $order4_nr = $order4->order_nr;

    # the pattern to find both JC & Normal Orders
    my $pattern = qr/(?:JC[A-Z]+\d+|\d+)/;

    $self->_from_text_ok(
        "${order1_nr} ${order2_nr}${order3_nr} ${order4_nr}",
        [],
        [ $order1_nr, $order2_nr, $order3_nr, $order4_nr ],
        "Finding Jimmy Choo & Normal Order Numbers",
        $pattern,
    );
}

