package XTracker::Schema::ResultSet::Public::RTVShipment;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use XTracker::Constants::FromDB qw( :rtv_shipment_status );
use XTracker::Schema;

use base 'DBIx::Class::ResultSet';

sub rtv_packing_summary {
    my $resultset = shift;
    my $status_id = shift;

    my $attr = {
        join        => [ qw/rtv_shipment_detail rtv_shipment_status_log/ ],
        '+select'   => [ {sum => 'rtv_shipment_detail.quantity' } ],
        '+as'       => [ qw/num_items/],
        columns     => [ qw/ me.id rtv_shipment_status_log.date_time/],
        group_by    => [qw/ me.id rtv_shipment_status_log.date_time /],
        order_by    => ['rtv_shipment_status_log.date_time ASC'],
    };

    my $list = $resultset->search(
        {
            'me.status_id' => $RTV_SHIPMENT_STATUS__PICKED,
            'rtv_shipment_status_log.rtv_shipment_status_id'
                => $RTV_SHIPMENT_STATUS__PICKED,
        }, $attr
    );

    return $list;
}


1;

