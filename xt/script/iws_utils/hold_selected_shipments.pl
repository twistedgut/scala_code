#!perl

=pod

Cancel all the orders that look like they might be making pending picks in IWS

=cut

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :shipment_status
    :shipment_item_status
    :order_status
);
use XTracker::Database qw(:common);

use WWW::Mechanize;

# Start-up gubbins here. Test plan follows later in the code...
my ( $schema, $dbh ) = get_schema_and_ro_dbh('xtracker_schema');
my $mech    = WWW::Mechanize->new;

# TODO # Test::XTracker::Data->set_department('it.god', 'Customer Care');
# TODO # Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
# TODO # Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Customer Search', 2);

my $username = 'it.god';
my $password = 'it.god';
my $department = 'Customer Care';

my $operator = $schema->resultset('Public::Operator')->find({
    username => $username,
},{
    key => 'username',
});
my $dept = $schema->resultset('Public::Department')->find({
    department => $department,
}, {
    key => 'department',
});
$operator->update({
    department_id => $dept->id,
    auto_login => 1,
    disabled => 0,
});

# just let it.god do everything
my $sth = $dbh->prepare("
    delete from operator_authorisation where operator_id=?
");
$sth->execute($operator->id);
$sth = $dbh->prepare("
    insert into operator_authorisation
        (operator_id,authorisation_sub_section_id,authorisation_level_id)
    select ?, id, (select id from authorisation_level where description='Manager')
        from authorisation_sub_section
");
$sth->execute($operator->id);

my $base = 'http://localhost:8529';
$mech->get($base.'/Login');
$mech->submit_form(
    with_fields => {
        pass     => $password,
        username => $username,
    },
);

my $shipments_to_cancel = find_selected_shipments();

my %orders_seen;

foreach my $shipment (@$shipments_to_cancel) {
    next unless ($shipment->link_orders__shipments->first);
    my $order_id = $shipment->link_orders__shipments->first->orders_id;
    next if ($orders_seen{$order_id});
    $orders_seen{$order_id} = 1;
    next unless ($shipment->link_orders__shipments->first->orders->order_status_id == $ORDER_STATUS__ACCEPTED);
    warn "Putting order ".$order_id." on hold\n";
    $mech->get($base.'/CustomerCare/OrderSearch/ChangeShipmentStatus?action=Hold&order_id='.$order_id.'&shipment_id='.$shipment->id.'&reason=9&comment=clearing+IWS+picks&norelease=1&submit=submit');
    #$mech->get($base.'/CustomerCare/OrderSearch/ChangeOrderStatus?order_id='.$order_id.'&cancel_reason_id=30&submit=submit&refund_type_id=0&send_email=no&action=Cancel');
}

sub find_selected_shipments {
    my @shipments = $schema->resultset('Public::Shipment')->search({
        'shipment_items.shipment_item_status_id' => $SHIPMENT_ITEM_STATUS__SELECTED,
        'me.shipment_status_id' => $SHIPMENT_STATUS__PROCESSING,
    },
    {
        join => 'shipment_items',
        order => 'me.id',
    })->all;
    warn "Shipment (items) to do: ".scalar @shipments."\n";
    return \@shipments;
}
