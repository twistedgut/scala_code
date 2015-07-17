#!/opt/xt/xt-perl/bin/perl
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use NAP::policy "tt";
use XTracker::Database;
use XTracker::Constants::FromDB qw(
                                      :shipment_status
                                      :shipment_item_status
                                      :stock_process_status
                                      :return_status
                                      :return_item_status
                                      :channel_transfer_status
);

sub display_shipments {
    my ($heading,$srs) = @_;

    say "Shipments $heading";
    $srs->reset;
    while (my $s = $srs->next) {
        my $shipment = sprintf 'Shipment %d (%s):',$s->id,$s->shipment_status->status;
        my $si_rs = $s->shipment_items;
        my @items;
        while (my $si = $si_rs->next) {
            push @items, sprintf 'item %d (%s)',$si->id,$si->shipment_item_status->status;
            if ($si->container_id) {
                $items[-1] .= sprintf ' in container %s',$si->container_id;
            }
        }
        say '  ',$shipment,' ',join ', ',@items;
    }
}

my $schema = schema_handle();

my $s_rs = $schema->resultset('Public::Shipment');

my $shipments_being_processed = $s_rs->yet_to_be_dispatched->search(
    {},
    { prefetch => [ {'shipment_items'=> 'shipment_item_status' },'shipment_status' ] },
);

my $shipments_after_picking = $shipments_being_processed->with_items_between_picking_and_dispatch;
display_shipments('(at least partially) picked and not dispatched',$shipments_after_picking);

my $shipments_partially_picked = $shipments_being_processed->with_items_selected;
say '';
display_shipments('selected and not completely picked',$shipments_partially_picked);

my $containers_with_orphans = $schema->resultset('Public::OrphanItem')->containers;
say '';
say 'Containers with orphaned items in them';
while (my $c = $containers_with_orphans->next) {
    say '  Container ',$c->id;
}

my $sp_putaway = $schema->resultset('Public::StockProcess')->approved_but_not_completed->pgids;
say '';
say 'Stock process groups being put away';
while (my $s = $sp_putaway->next) {
    say '  PGID ',$s->group_id;
}

my $return_putaway = $schema->resultset('Public::Return')->in_processing->with_items_after_qc->search(
    {},
    {
        prefetch => [ 'return_status', { return_items => 'status'} ],
    }
);
say '';
say 'Returns being put away';
while (my $r = $return_putaway->next) {
    my $return = sprintf 'Return %d (%s):',$r->id,$r->return_status->status;
    my $ri_rs = $r->return_items;
    my @items;
    while (my $ri = $ri_rs->next) {
        push @items, sprintf 'item %d (%s)',$ri->id,$ri->status->status;
    }
    say '  ',$return,' ',join ', ',@items;
}

my $in_transfer = $schema->resultset('Public::ChannelTransfer')->between_selected_and_completed->product_ids;
say '';
say 'Products in channel transfers selected and not completed';
while (my $t = $in_transfer->next) {
    say '  PID ',$t->product_id;
}
