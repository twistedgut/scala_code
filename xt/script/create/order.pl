use NAP::policy "tt";
use Test::XTracker::Data;
use XTracker::Constants::FromDB   qw(
    :shipment_item_status
    :shipment_status
);

sub main {
    my ($args) = @_;

    my $channel_row = Test::XTracker::Data->get_schema()->resultset('Public::Channel')->search({
        name    => $args->{channel_name},
    })->first;
    die 'Could not find channel ' . $args->{channel_name} unless $channel_row;

    my (undef, $pid_data) = Test::XTracker::Data->grab_products({
        channel_id => $channel_row->id(),
        how_many_variants => 1,
        ensure_stock_all_variants => 1,
    });

    my ($order, undef) = Test::XTracker::Data->create_db_order({
        base => {
            channel_id          => $channel_row->id(),
            shipment_status     => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status=> $SHIPMENT_ITEM_STATUS__NEW,
        },
        pids => $pid_data,
    });

    say 'Created order with order number: ' . $order->order_nr();
}

if (!defined($ARGV[0])) {
    say q/Require a channel (e.g. 'JIMMYCHOO.COM')/;
    exit;
}


main({
    channel_name => $ARGV[0],
}) unless caller;
