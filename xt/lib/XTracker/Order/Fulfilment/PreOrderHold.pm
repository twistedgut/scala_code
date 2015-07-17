package XTracker::Order::Fulfilment::PreOrderHold;

use strict;
use warnings;
use XTracker::XTemplate;
use XTracker::Database;
use XTracker::Navigation;
use XTracker::EmailFunctions;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw( :shipment_status );
use XTracker::DBEncode qw( decode_db );

sub handler {
    my $handler = XTracker::Handler->new( shift );
    my $operator_id = $handler->operator_id;
    my $auth_level = $handler->auth_level;

    my $dbh_read = read_handle();

    my $data = {
        section       => 'Fulfilment',
        subsection    => 'Pre-Order Hold',
        subsubsection => '',
        mainnav       => build_nav( $operator_id ),
        sidenav       => [],
        auth_level    => $auth_level,
        content       => 'ordertracker/fulfilment/preorderhold.tt',
    };

    $handler->{data} = $data;

    ### get list of shipments on pre-order hold
    $data->{list} = _get_shipment_list( $dbh_read );

    $handler->process_template(undef);
}

sub _get_shipment_list {
    my ( $dbh ) = @_;

    my %list = ();

    my $qry
        = "SELECT s.id, oa.first_name, oa.last_name, oa.country as destination, to_char(s.date, 'DD-MM-YYYY  HH24:MI') as date, o.order_nr, o.id as orders_id
                FROM shipment s, order_address oa, link_orders__shipment los, orders o
                WHERE s.shipment_status_id = ?
                AND s.shipment_address_id = oa.id
                AND s.id = los.shipment_id
                AND los.orders_id = o.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($SHIPMENT_STATUS__PRE_DASH_ORDER_HOLD);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
        ));
        $list{ $row->{id} } = $row;
    }
    return \%list;
}

1;
