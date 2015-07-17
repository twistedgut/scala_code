package XTracker::Stock::Reservation::PreOrderList;
use NAP::policy;

use XTracker::Navigation                qw( build_sidenav );
use XTracker::Constants::FromDB         qw( :department );
use XTracker::Config::Local qw( config_var );

sub handler {
    __PACKAGE__->new(XTracker::Handler->new(shift))->process();
}

sub new {
    my ($class, $handler, $config) = @_;

    my $self = {
        handler => $handler
    };

    $handler->{data}{section}            = 'Reservation';
    $handler->{data}{subsection}         = 'Customer';
    $handler->{data}{subsubsection}      = 'Pre Order List';
    $handler->{data}{content}            = 'stocktracker/reservation/pre_order_operator_summary.tt';
    $handler->{data}{js}                 = '/javascript/preorder.js';
    $handler->{data}{css}                = '/css/preorder.css';

    return bless($self, $class);
}

sub process {
    my $self = shift;

    my $handler                 = $self->{handler};

    $handler->{data}{sidenav} = build_sidenav({
        navtype    => 'reservations',
        res_filter => 'Personal'
    });

    my $alt_operator_id =
        ( $handler->{param_of}{alt_operator_id} // 0) ?
         $handler->{param_of}{alt_operator_id}:
         $handler->{data}{operator_id};

    my $po_obj = $handler->schema->resultset('Public::PreOrder');
    # Get preorder for last 6 months
    my $interval = config_var( 'PreOrder', 'used_summary_interval');
    my $pre_order_list = $po_obj->get_pre_order_list({
        age => $interval,
        operator_id => $alt_operator_id
    });

    foreach my $pre_order ( $pre_order_list->all ) {
        my $operator_id = $pre_order->operator->id;
        my $operator_name = $pre_order->operator->name;
        my $customer_id = $pre_order->customer_id;

        $handler->{data}{list}{$operator_id}{$customer_id}{$pre_order->id} = $pre_order;

        #operators lookup hash
        $handler->{data}{operator}{$operator_id} = $operator_name;

        #customer lookup hash
        $handler->{data}{customer}{$customer_id} ={
            name => join(
                q{ },
                (
                    $pre_order->customer->first_name,
                    $pre_order->customer->last_name
                )
            ),
            number => $pre_order->customer->is_customer_number,
       };

    }



    # Get a list of all operators in PS and FA departments
    my @operators = $handler->{schema}->resultset('Public::Operator')
        ->in_department( [
            $DEPARTMENT__PERSONAL_SHOPPING,
            $DEPARTMENT__FASHION_ADVISOR
        ] )->all;

    $handler->{data}{all_operators} = [ ];

    foreach my $op (@operators) {
        push @{ $handler->{data}{all_operators} }, {
            id => $op->id,
            name => $op->name
        };
    }

    $handler->{data}{current_operator} = ($alt_operator_id)
        ? $alt_operator_id
        : $handler->{data}{operator_id};

    return $handler->process_template;

}

1;
