package XT::Domain::Shipment;

use strict;
use warnings;
use Class::Std;
use Data::Dump qw(pp);
use Data::Dumper;
use Readonly;
use XTracker::Utilities 'number_in_list';
use XTracker::Logfile qw(xt_logger);
use XTracker::Constants::FromDB qw(
    :shipment_status :shipment_item_status :shipment_type
    :rtv_shipment_status
);


# FIXME: Just migrating existing stuff. Hardcoding displaying formats in
# FIXME: code probably isnt the best decision.
Readonly my $DATEFORMAT_PICKEDDATE  => '%d-%m-%Y %H:%M';
Readonly my $DATEFORMAT_KEY         => '%Y%m%d%H%M';

Readonly my $MEMCACHED_TTL          => '2M';

use base qw/ XT::Domain /;
{
    sub packing_summary {
        my($self) = @_;
        my $schema = $self->get_schema;
        my $memcached = $self->get_memcached;
        my %shipments       = ();
        my %items           = ();
        my %packing_list    = ();

        # memcached: check for cached version
        if (defined $memcached) {
            xt_logger('Memcached')->info(__PACKAGE__.':Retrieving');
            my $stuff =  $memcached->get;

            return $stuff
                if (defined $stuff);
            xt_logger('Memcached')->info(__PACKAGE__.'Not found in cache');
        }

        my $rs = $schema->resultset('Public::Shipment')->packing_summary();

        # get list of shipments which are in processing
        while ( my $rec = $rs->next ) {
            #my $rec = $set
            if ( number_in_list($rec->shipment_item->shipment_item_status_id,
                                $SHIPMENT_ITEM_STATUS__NEW,
                                $SHIPMENT_ITEM_STATUS__SELECTED,
                                $SHIPMENT_ITEM_STATUS__PICKED,
                                $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                $SHIPMENT_ITEM_STATUS__PACKED,
                            ) ) {
                my $ship_id = $rec->id;
                my $ship = (defined $shipments{ $ship_id }) ?
                    $shipments{ $ship_id } : { };

                $ship->{outward_airway_bill} = $rec->outward_airway_bill;
                $ship->{orders_id} = $rec->orders->orders_id;
                $ship->{type_id} = $rec->shipment_type_id;

                if (defined $ship->{num_items}) {
                    $ship->{num_items}++
                } else {
                    $ship->{num_items} = 1;
                }

                my $shipitem_id = $rec->shipment_item->id;

                $ship->{items}->{ $shipitem_id }
                    = $rec->shipment_item->shipment_item_status_id;

                $shipments{ $ship_id } = $ship;
            }
        }

        # loop through shipment and see if they're at the packing stage
        foreach my $ship_id ( keys %shipments ) {
            my $ship = $shipments{$ship_id};

            # number of items in shipment ready to be packed (picked)
            my $ready  = 0;
            # number of items not ready to be packed (not picked yet)
            my $notready = 0;
            # number of items in shipment already packed
            my $packed  = 0;
            # total number of items in shipment
            my $total  = 0;


            # loop through items in shipment
            foreach my $shipment_item_id (
                keys %{ $ship->{items} } ) {
                my $item_status = $ship->{items}->{$shipment_item_id};


                if ( number_in_list($item_status,
                                    $SHIPMENT_ITEM_STATUS__NEW,
                                    $SHIPMENT_ITEM_STATUS__SELECTED) ) {
                    $notready++;
                } elsif ( $item_status == $SHIPMENT_ITEM_STATUS__PICKED ) {
                    $ready++;
                } else {
                    $packed++;
                }

                $total++;
            }

            my $pick_date = "";
            my $dateorder = "";


            # shipments awaiting packing OR in process of packing
            if (( $ready > 0 && $notready == 0 ) # items to be packed
                or
                ( $packed == $total
                and $ship->{type_id} != $SHIPMENT_TYPE__PREMIER
                and $ship->{outward_airway_bill} eq 'none')
                # all items packed, not Premier and no outbound AWB assigned
                ) {

                # final check for DHL Form - if generated then packing complete
                my $printed_docs = $schema->resultset(
                    'Public::ShipmentPrintLog')->dhl_printed_docs($ship_id);

                my $form_printed = $printed_docs->count;

                $pick_date = undef;
                $dateorder = undef;

                if ( $form_printed == 0 ) {

                    # get pick date
                    $rs = $schema->resultset(
                        'Public::ShipmentItem')->shipment_item_picking_date(
                        $ship_id);

                    my $rec = $rs->next;
                    my $picked = (defined $rec )
                        ? $rec->shipment_item_status_logs->first : undef;

                    if (defined $picked) {
                        $pick_date = $picked->date->strftime(
                            $DATEFORMAT_PICKEDDATE);
                        $dateorder = $picked->date->strftime(
                            $DATEFORMAT_KEY);

                       # $pick_date = $first->date;
                       # $dateorder = $first->date;
                    } else {
                        $pick_date = undef;
                        $dateorder = undef;
                    }

                    $dateorder .= $ship_id;

                    $packing_list{$dateorder} = {
                        shipment_id => $ship_id,
                        orders_id   => $shipments{$ship_id}{orders_id},
                        num_items   => $shipments{$ship_id}{num_items},
                        type_id     => $shipments{$ship_id}{type_id},
                        date_picked => $pick_date,
                    };

                }

            }

        }

        ## Add RTV shipments
        $rs = $schema->resultset('Public::RTVShipment')->rtv_packing_summary();

        if (defined $rs and $rs->count > 0) {
            while ( my $rec = $rs->next ) {
                my $rtv_ship_id = 'RTVS-'. $rec->id;
                my $rtv_date_picked = undef;
                my $rtv_date_order = undef;
                my $status_log = undef;

                my $rssl = $rec->rtv_shipment_status_log;

                if (defined $rssl) {
                    #$status_log = $rssl->first;

                    $rtv_date_picked = $rssl->date_time->strftime(
                        $DATEFORMAT_PICKEDDATE);
                    $rtv_date_order = $rssl->date_time->strftime(
                        $DATEFORMAT_KEY) .'RTVS-'. $rtv_ship_id;
                }

                $packing_list{ $rtv_date_order } = {
                    shipment_id => $rtv_ship_id,
                    num_items => $rec->get_column('num_items'),
                    date_picked => $rtv_date_picked,
                };
            }

        }

        # memcached: store results into memcached
        if (defined $memcached) {
            xt_logger('Memcached')->info(__PACKAGE__.'Storing');
            $memcached->set(
                expiration  => $MEMCACHED_TTL,
                value       => \%packing_list
            );
        }

        return \%packing_list;
    }

}

1;
