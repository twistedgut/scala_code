package XTracker::Database::Distribution;

use strict;
use warnings;

use Perl6::Export::Attrs;
use Carp qw(carp croak);
use List::MoreUtils qw/uniq/;

use NAP::DC::Barcode::Container;
use XTracker::Database::Shipment qw( is_premier get_shipment_boxes check_shipping_input_form );
use XTracker::Config::Local qw( config_var manifest_level manifest_countries );
use XTracker::Constants::FromDB qw(
    :allocation_status
    :container_status
    :correspondence_templates
    :customer_category
    :customer_class
    :note_type
    :rtv_shipment_status
    :rtv_inspection_pick_request_status
    :shipment_class
    :shipment_item_status
    :shipment_status
    :shipment_type
);
use XTracker::Database  qw( get_schema_using_dbh );
use XTracker::Database::Container  qw( :validation );
use XTracker::Database::Currency  qw( get_currency_glyph_map );
use XTracker::Database::Utilities qw( is_valid_database_id );
use XTracker::Utilities qw(number_in_list);
use XTracker::Database::Row;
use XTracker::DBEncode qw( decode_db );


sub split_out_staff_shipments :Export()
{
    my ($dbh, $shipments) = @_;
    my $schema = get_schema_using_dbh ($dbh, 'xtracker_schema');

    my $staff_ships = ();

    foreach my $chan (keys %{$shipments})
    {
        foreach my $ship (keys %{$shipments->{$chan}})
        {
            my $ship_id = $shipments->{$chan}{$ship}{shipment_id};
            unless ( is_valid_database_id($ship_id // '') ) {
                croak q{invalid shipment id '}.($ship_id // '').q{'};
            }

            my $shipment = $schema->resultset('Public::Shipment')->find( $ship_id );

            next unless ($shipment->order);

            if ($shipment->is_staff_order)
            {
                $shipments->{$chan}{$ship}{staff} = 1;
                $staff_ships->{$chan}{$ship} = $shipments->{$chan}{$ship};
                delete $shipments->{$chan}{$ship};
            }
        }
    }
    return ($shipments, $staff_ships);
}

### Subroutine : get_picking_shipment_list               ###
# usage        :                                  #
# description  :   returns a hash of all shipments at the picking
#                  stage of distribution process                               #
# parameters   :   db handle                               #
# returns      :   hash                               #

sub get_picking_shipment_list :Export() {

    my ( $dbh ) = @_;

    my %picking_list = ();
    my %sample_picking_list = ();
    my %rtv_picking_list = ();

    # get customer shipments
    my $qry = "
                SELECT
                    s.id as shipment_id,
                    los.orders_id,
                    ch.name as sales_channel,
                    case
                        when s.shipment_type_id = $SHIPMENT_TYPE__PREMIER
                        then 1 else 0
                    end as premier_shipment,
                    count(distinct si.id) as num_items,
                    max(to_char(log.date, 'DD-MM-YYYY  HH24:MI')) as date_selected,
                    max(to_char(log2.date, 'DD-MM-YYYY  HH24:MI')) as last_pick,
                    case
                        when max(log2.date) < current_timestamp - interval '1 hour'
                        then 1 else 0
                    end as delayed,
                    date_trunc('second',s.sla_cutoff - current_timestamp) as cutoff,
                    extract(epoch from (s.sla_cutoff - current_timestamp)) as cutoff_epoch
                FROM
                    shipment s,
                    link_orders__shipment los,
                    orders o,
                    channel ch,
                    shipment_item si
                    -- it would seem this is done for the delayed field
                    -- selected above
                    LEFT JOIN
                        shipment_item_status_log log2
                        ON si.id = log2.shipment_item_id
                        AND log2.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PICKED,
                        shipment_item_status_log log
                WHERE
                    s.shipment_status_id = $SHIPMENT_STATUS__PROCESSING
                    AND s.shipment_class_id != $SHIPMENT_CLASS__TRANSFER_SHIPMENT
                    AND s.id = los.shipment_id
                    AND los.orders_id = o.id
                    AND o.channel_id = ch.id
                    AND s.id = si.shipment_id
                    AND si.shipment_item_status_id IN (
                        $SHIPMENT_ITEM_STATUS__NEW,
                        $SHIPMENT_ITEM_STATUS__SELECTED,
                        $SHIPMENT_ITEM_STATUS__PICKED,
                        $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                        $SHIPMENT_ITEM_STATUS__PACKED
                    )
                    AND si.id = log.shipment_item_id
                    AND log.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__SELECTED
                    AND s.id IN (SELECT shipment_id FROM shipment_item WHERE shipment_item_status_id = $SHIPMENT_ITEM_STATUS__SELECTED)
                GROUP BY
                    s.id,
                    los.orders_id,
                    ch.name,
                    s.shipment_type_id,
                    s.sla_cutoff

    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
        my $key =
            # will be used for sorting, so we want the sla cutoff
            sprintf("%010d",int($row->{cutoff_epoch} // 0)) .
            # because it's the hash key we need to make sure it's unique too
            sprintf('%012d',$row->{shipment_id});
        $picking_list{ $row->{sales_channel} }{ $key } = $row;
    }

    # get sample shipments
    my $samp_qry = "SELECT s.id as shipment_id, ch.name as sales_channel, count(distinct si.id) as num_items, max(to_char(log.date, 'YYYYMMDDHH24MI')) || s.id as sort_value, max(to_char(log.date, 'DD-MM-YYYY  HH24:MI')) as date_selected
                FROM shipment s, shipment_item si, shipment_item_status_log log, link_stock_transfer__shipment lsts, stock_transfer st, channel ch
                WHERE s.shipment_status_id = $SHIPMENT_STATUS__PROCESSING
                AND s.shipment_class_id = $SHIPMENT_CLASS__TRANSFER_SHIPMENT
                AND s.id = si.shipment_id
                AND si.shipment_item_status_id IN (
                        $SHIPMENT_ITEM_STATUS__NEW,
                        $SHIPMENT_ITEM_STATUS__SELECTED,
                        $SHIPMENT_ITEM_STATUS__PICKED,
                        $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                        $SHIPMENT_ITEM_STATUS__PACKED
                )
                AND si.id = log.shipment_item_id
                AND log.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__SELECTED
                AND s.id IN (SELECT shipment_id FROM shipment_item WHERE shipment_item_status_id = $SHIPMENT_ITEM_STATUS__SELECTED)
                AND s.id = lsts.shipment_id
                AND lsts.stock_transfer_id = st.id
                AND st.channel_id = ch.id
                GROUP BY s.id, sales_channel";
    my $samp_sth = $dbh->prepare($samp_qry);
    $samp_sth->execute();

    while ( my $row = $samp_sth->fetchrow_hashref() ) {
        $sample_picking_list{ $row->{sales_channel} }{ $row->{sort_value} } = $row;
    }


    ## Add RTV inspection pick requests
    my $sql_rtvi
        = q{SELECT
                'RTVI-' || ripr.id AS rtv_inspection_pick_request_id,
                ch.name as sales_channel,
                to_char(ripr.date_time, 'DD-MM-YYYY  HH24:MI') AS rtv_inspection_pick_request_date_selected,
                to_char(ripr.date_time, 'YYYYMMDDHH24MI') || 'RTVI-' || ripr.id AS rtv_inspection_pick_request_date_order,
                sum(rq.quantity) AS rtv_inspection_pick_request_sum_quantity
            FROM rtv_inspection_pick_request ripr
            INNER JOIN rtv_inspection_pick_request_detail riprd
                ON (riprd.rtv_inspection_pick_request_id = ripr.id)
            INNER JOIN rtv_quantity rq
                ON (riprd.rtv_quantity_id = rq.id)
            INNER JOIN channel ch
                ON (rq.channel_id = ch.id)
            WHERE ripr.status_id = ?
            GROUP BY ripr.id, ch.name, ripr.date_time
        };
    my $sth_rtvi = $dbh->prepare($sql_rtvi);
    $sth_rtvi->execute($RTV_INSPECTION_PICK_REQUEST_STATUS__NEW);

    my ($rtv_inspection_pick_request_id, $sales_channel, $rtv_inspection_pick_request_date_selected,
        $rtv_inspection_pick_request_date_order, $rtv_inspection_pick_request_sum_quantity);

    $sth_rtvi->bind_columns(\($rtv_inspection_pick_request_id, $sales_channel, $rtv_inspection_pick_request_date_selected,
        $rtv_inspection_pick_request_date_order, $rtv_inspection_pick_request_sum_quantity));

    while ( $sth_rtvi->fetch() ) {
        $rtv_picking_list{$sales_channel}{$rtv_inspection_pick_request_date_order}{shipment_id}      = $rtv_inspection_pick_request_id;
        $rtv_picking_list{$sales_channel}{$rtv_inspection_pick_request_date_order}{num_items}        = $rtv_inspection_pick_request_sum_quantity;
        $rtv_picking_list{$sales_channel}{$rtv_inspection_pick_request_date_order}{date_selected}    = $rtv_inspection_pick_request_date_selected;
        $rtv_picking_list{$sales_channel}{$rtv_inspection_pick_request_date_order}{href}             = '/RTV/InspectPick?rtv_inspection_pick_request_id=' . $rtv_inspection_pick_request_id;
    }


    ## Add RTV shipments
    my $sql_rtvs
        = q{SELECT
                'RTVS-' || rs.id AS rtv_shipment_id,
                ch.name as sales_channel,
                to_char(rs.date_time, 'DD-MM-YYYY  HH24:MI') AS rtv_shipment_date_selected,
                to_char(rs.date_time, 'YYYYMMDDHH24MI') || 'RTVS-' || rs.id AS rtv_shipment_date_order,
                sum(rsd.quantity) AS rtv_shipment_sum_quantity
            FROM rtv_shipment rs
            INNER JOIN channel ch
                ON (rs.channel_id = ch.id)
            INNER JOIN rtv_shipment_detail rsd
                ON (rsd.rtv_shipment_id = rs.id)
            WHERE rs.status_id = ?
            GROUP BY rs.id, ch.name, rs.date_time
        };
    my $sth_rtvs = $dbh->prepare($sql_rtvs);
    $sth_rtvs->execute($RTV_SHIPMENT_STATUS__NEW);

    my ($rtv_shipment_id, $rtv_shipment_date_selected, $rtv_shipment_date_order, $rtv_shipment_sum_quantity);
    $sth_rtvs->bind_columns(\($rtv_shipment_id, $sales_channel, $rtv_shipment_date_selected, $rtv_shipment_date_order, $rtv_shipment_sum_quantity));

    while ( $sth_rtvs->fetch() ) {
        $rtv_picking_list{ $sales_channel }{$rtv_shipment_date_order}{shipment_id}      = $rtv_shipment_id;
        $rtv_picking_list{ $sales_channel }{$rtv_shipment_date_order}{num_items}        = $rtv_shipment_sum_quantity;
        $rtv_picking_list{ $sales_channel }{$rtv_shipment_date_order}{date_selected}    = $rtv_shipment_date_selected;
        $rtv_picking_list{ $sales_channel }{$rtv_shipment_date_order}{href}             = '/RTV/PickRTV?rtv_shipment_id=' . $rtv_shipment_id;
    }


    return split_out_staff_shipments ($dbh, \%picking_list), \%sample_picking_list, \%rtv_picking_list;

}



### Subroutine : get_packing_shipment_list               ###
# usage        :                                  #
# description  :   returns a hash of all shipments at the packing
#                  stage of distribution process                               #
# parameters   :   db handle                               #
# returns      :   hash                               #

sub get_packing_shipment_list :Export() {

    my ( $dbh ) = @_;

    my %packing_list = ();
    my %sample_packing_list = ();
    my %rtv_packing_list = ();

    # If we're using PRLs, we'll need to check allocation status too.
    my $prl_rollout_phase = config_var('PRL', 'rollout_phase');

    # get customer shipments
    my $qry = "SELECT s.id as shipment_id, los.orders_id, ch.name as sales_channel, case when s.shipment_type_id = $SHIPMENT_TYPE__PREMIER then 1 else 0 end as premier_shipment, count(distinct si.id) as num_items, to_char(max(log.date), 'DD-MM-YYYY  HH24:MI') as date_picked, date_trunc('second',s.sla_cutoff - current_timestamp) as cutoff, extract(epoch from (s.sla_cutoff - current_timestamp)) as cutoff_epoch
                FROM shipment s, link_orders__shipment los, orders o, channel ch, shipment_item si ";

    if ($prl_rollout_phase) {
        $qry .= "
                JOIN allocation_item ai ON ai.shipment_item_id = si.id JOIN allocation a on a.id = ai.allocation_id
        ";
    }

    $qry .= "
                LEFT JOIN shipment_item_status_log log ON si.id = log.shipment_item_id AND log.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PICKED
                WHERE s.shipment_status_id = $SHIPMENT_STATUS__PROCESSING
                AND s.shipment_class_id != $SHIPMENT_CLASS__TRANSFER_SHIPMENT
                AND s.id = si.shipment_id
                AND si.shipment_item_status_id IN (
                        $SHIPMENT_ITEM_STATUS__NEW,
                        $SHIPMENT_ITEM_STATUS__SELECTED,
                        $SHIPMENT_ITEM_STATUS__PICKED,
                        $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                        $SHIPMENT_ITEM_STATUS__PACKED
                )
                AND s.id IN (SELECT shipment_id FROM shipment_item WHERE shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PICKED)
                AND s.id NOT IN (SELECT shipment_id FROM shipment_item WHERE shipment_item_status_id IN (
                        $SHIPMENT_ITEM_STATUS__NEW,
                        $SHIPMENT_ITEM_STATUS__SELECTED,
                        $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION
                ))
    ";

    if ($prl_rollout_phase) {
        # Exclude shipments where any allocation is staged. We don't need to
        # worry about other pre-staging allocation statuses because they're
        # covered by the shipment item status checks, it's only the difference
        # between STAGED and PICKED for an allocation that we need this for.
        $qry .= "
                AND a.status_id = $ALLOCATION_STATUS__PICKED
        ";
    }

    $qry .= "
                AND s.id NOT IN (SELECT shipment_id from shipment_extra_item)
                AND s.id = los.shipment_id
                AND los.orders_id = o.id
                AND o.channel_id = ch.id
                GROUP BY s.id, los.orders_id, ch.name, s.shipment_type_id, s.sla_cutoff";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
               $packing_list{ $row->{sales_channel} }{ int($row->{cutoff_epoch} || 0) . $row->{shipment_id} } = $row;
    }


    # get sample shipments
    my $samp_qry = "SELECT s.id as shipment_id, ch.name as sales_channel, count(distinct si.id) as num_items, max(to_char(log.date, 'YYYYMMDDHH24MI')) || s.id as sort_value, max(to_char(log.date, 'DD-MM-YYYY  HH24:MI')) as date_picked
                FROM shipment s, shipment_item si LEFT JOIN shipment_item_status_log log ON si.id = log.shipment_item_id AND log.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PICKED, link_stock_transfer__shipment lsts, stock_transfer st, channel ch";

    if ($prl_rollout_phase) {
        $samp_qry .= "
                , allocation_item ai, allocation a
        ";
    }

    $samp_qry .= "
                WHERE s.shipment_status_id = $SHIPMENT_STATUS__PROCESSING
                AND s.shipment_class_id = $SHIPMENT_CLASS__TRANSFER_SHIPMENT
                AND s.id = si.shipment_id
                AND si.shipment_item_status_id IN (
                        $SHIPMENT_ITEM_STATUS__NEW,
                        $SHIPMENT_ITEM_STATUS__SELECTED,
                        $SHIPMENT_ITEM_STATUS__PICKED,
                        $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                        $SHIPMENT_ITEM_STATUS__PACKED
                )
                AND s.id IN (SELECT shipment_id FROM shipment_item WHERE shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PICKED)
                AND s.id NOT IN (SELECT shipment_id FROM shipment_item WHERE shipment_item_status_id IN (
                        $SHIPMENT_ITEM_STATUS__NEW,
                        $SHIPMENT_ITEM_STATUS__SELECTED,
                        $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION
                ))
    ";

    if ($prl_rollout_phase) {
        # Exclude shipments where any allocation is staged. We don't need to
        # worry about other pre-staging allocation statuses because they're
        # covered by the shipment item status checks, it's only the difference
        # between STAGED and PICKED for an allocation that we need this for.
        $samp_qry .= "
                AND ai.shipment_item_id = si.id AND a.id = ai.allocation_id
                AND s.id NOT IN (SELECT shipment_id FROM allocation WHERE status_id = $ALLOCATION_STATUS__STAGED)
        ";
    }

    $samp_qry .= "
                AND s.id = lsts.shipment_id
                AND lsts.stock_transfer_id = st.id
                AND st.channel_id = ch.id
                GROUP BY s.id, sales_channel";
    my $samp_sth = $dbh->prepare($samp_qry);
    $samp_sth->execute();

    while ( my $row = $samp_sth->fetchrow_hashref() ) {
        # if you don't give your data a sort_value, you default to 'a long way
        # down' .. helpfully preventing warnings like this:
        #    Use of uninitialized value in hash element at
        #    /home/c.wright/development/xt/lib/XTracker/Database/Distribution.pm
        #    line 505.
        $row->{sort_value} = 999999 if not defined $row->{sort_value};
        $sample_packing_list{ $row->{sales_channel} }{ $row->{sort_value} } = $row;
    }


    ## Add RTV shipments
    my $sql_rtv
        = q{SELECT
                'RTVS-' || rs.id AS rtv_shipment_id,
                ch.name as sales_channel,
                to_char(rssl.date_time, 'DD-MM-YYYY  HH24:MI') AS rtv_shipment_date_picked,
                to_char(rssl.date_time, 'YYYYMMDDHH24MI') || 'RTVS-' || rs.id AS rtv_shipment_date_order,
                sum(rsd.quantity) AS rtv_shipment_sum_quantity
            FROM rtv_shipment rs
            INNER JOIN channel ch
                ON (rs.channel_id = ch.id)
            INNER JOIN rtv_shipment_status_log rssl
                ON (rssl.rtv_shipment_id = rs.id AND rssl.rtv_shipment_status_id = rs.status_id)
            INNER JOIN rtv_shipment_detail rsd
                ON (rsd.rtv_shipment_id = rs.id)
            WHERE rs.status_id = ?
            GROUP BY rs.id, ch.name, rssl.date_time
        };
    my $sth_rtv = $dbh->prepare($sql_rtv);
    $sth_rtv->execute($RTV_SHIPMENT_STATUS__PICKED);

    my ($rtv_shipment_id, $sales_channel, $rtv_shipment_date_picked, $rtv_shipment_date_order, $rtv_shipment_sum_quantity);
    $sth_rtv->bind_columns(\($rtv_shipment_id, $sales_channel, $rtv_shipment_date_picked, $rtv_shipment_date_order, $rtv_shipment_sum_quantity));

    while ( $sth_rtv->fetch() ) {
        $rtv_packing_list{$sales_channel}{$rtv_shipment_date_order}{shipment_id}    = $rtv_shipment_id;
        $rtv_packing_list{$sales_channel}{$rtv_shipment_date_order}{num_items}      = $rtv_shipment_sum_quantity;
        $rtv_packing_list{$sales_channel}{$rtv_shipment_date_order}{date_picked}    = $rtv_shipment_date_picked;
        $rtv_packing_list{$sales_channel}{$rtv_shipment_date_order}{href}           = '/RTV/PackRTV?rtv_shipment_id=' . $rtv_shipment_id;
    }

    # Hack and ram the bloody sla_cutoff into the data structure.
    # This whole sub could potentially do with some Love and be properly re-written.
    # This of course needs to be decided.
#    apply_sla_cutoff_time_to_data($dbh ,\%packing_list );

    return split_out_staff_shipments ($dbh, \%packing_list), \%sample_packing_list, \%rtv_packing_list;

}


### Subroutine : get_dispatch_shipment_list                       ###
# usage        : get_dispatch_shipment_list($dbh)                   #
# description  : returns a hash of all shipments at the dispatch    #
#                stage of distribution process                      #
# parameters   : db handle                                          #
# returns      : hash                                               #

sub get_dispatch_shipment_list :Export() {

    my ( $dbh ) = @_;

    # temporary hashes
    my %shipments = ();
    my %items     = ();

    # final shipment hash to return
    my %list = ();

    # get shipments at the correct stage for dispatch
    my $qry = "SELECT s.id,
                      si.id as shipment_item_id,
                      si.shipment_item_status_id,
                      los.orders_id,
                      o.order_nr,
                      ch.name as sales_channel,
                      oa.country,
                      s.shipment_type_id,
                      s.outward_airway_bill,
                      s.return_airway_bill,
                      car.name as carrier,
                      date_trunc(\'second\',s.sla_cutoff - current_timestamp) as cutoff_time,
                      extract(epoch from (s.sla_cutoff - current_timestamp)) as cutoff_epoch,
                      c.category_id
                FROM shipment s
                    LEFT JOIN link_orders__shipment los ON s.id = los.shipment_id
                    JOIN orders o ON los.orders_id  = o.id
                    JOIN channel ch ON o.channel_id = ch.id,
                    shipment_item si,
                    order_address oa,
                    shipping_account sac,
                    carrier car,
                    customer c
                WHERE s.shipment_status_id = $SHIPMENT_STATUS__PROCESSING
                AND s.id = si.shipment_id
                AND s.shipment_address_id = oa.id
                AND s.shipping_account_id = sac.id
                AND sac.carrier_id = car.id
                AND c.id = o.customer_id";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {

        if ( number_in_list($row->{shipment_item_status_id},
                            $SHIPMENT_ITEM_STATUS__NEW,
                            $SHIPMENT_ITEM_STATUS__SELECTED,
                            $SHIPMENT_ITEM_STATUS__PICKED,
                            $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                            $SHIPMENT_ITEM_STATUS__PACKED,
                        ) && AWBs_are_present( { for => 'dispatch_list', on => $row } ) ) {

            if (!$shipments{ $row->{id} }) {
                $shipments{ $row->{id} } = $row;
            }

            $shipments{ $row->{id} }{num_items}++;
            $items{ $row->{id} }{ $row->{shipment_item_id} } = $row->{shipment_item_status_id};
        }
    }


    # prepare qry to check pack date for shipments
    $qry = "SELECT to_char(sisl.date, 'DD-MM-YYYY  HH24:MI')
                FROM shipment_item_status_log sisl, shipment_item si
                WHERE si.shipment_id = ?
                AND si.id = sisl.shipment_item_id
                AND sisl.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED
                ORDER BY sisl.date DESC
                LIMIT 1";
    $sth = $dbh->prepare($qry);


    # need to check items in shipments are all ready for dispatch
    foreach my $shipment_id ( keys %items ) {

        my $ready    = 0;
        my $notready = 0;

        foreach my $shipment_item_id ( keys %{ $items{$shipment_id} } ) {
            if ( number_in_list($items{$shipment_id}{$shipment_item_id},
                                $SHIPMENT_ITEM_STATUS__NEW,
                                $SHIPMENT_ITEM_STATUS__SELECTED,
                                $SHIPMENT_ITEM_STATUS__PICKED,
                                $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                            ) ) {
                $notready++;
            }
            elsif ( $items{$shipment_id}{$shipment_item_id} == $SHIPMENT_ITEM_STATUS__PACKED ) {
                $ready++;
            }
            else {

            }
        }

        # if all items ready pass shipment into final hash to be returned
        if ( $ready > 0 && $notready == 0 ) {

            $list{ $shipments{$shipment_id}{sales_channel} }{ int($shipments{$shipment_id}{cutoff_epoch} || 0) . $shipment_id} = $shipments{$shipment_id};

            # get packing date
            $sth->execute($shipment_id);

            while ( my $row = $sth->fetchrow_arrayref() ) {
                $list{ $shipments{$shipment_id}{sales_channel} }{int($shipments{$shipment_id}{cutoff_epoch} || 0) . $shipment_id}{date_packed} = $row->[0];
            }

        }
    }

    return \%list;

}


### Subroutine : get_shipment_hold_list                            ###
# usage        : get_shipment_hold_list($schema)                     #
# description  : returns a hash of all shipments which are on hold   #
# parameters   : Schema db handle                                    #
# returns      : hash                                                #

sub get_shipment_hold_list :Export() {

    my ( $schema )  = @_;

    croak "Need to pass a 'Schema' connection to '" . __PACKAGE__ . "::get_shipment_hold_list'"
                    if ( ref( $schema ) !~ /Schema/ );

    # get a map of Language Ids to Languages and the Default
    my $languages   = $schema->resultset('Public::Language')
                                ->get_all_languages_and_default;

    my $dbh = $schema->storage->dbh;

    my %list = ();

    # get all the currency symbols so that they
    # can be put together with the Order's Currency
    my $currency_glyph  = get_currency_glyph_map( $dbh );

    my $qry
         = "SELECT  s.id,
                    s.shipment_type_id,
                    los.orders_id,
                    ch.name AS sales_channel,
                    TO_CHAR(s.date, 'DD-MM-YYYY HH24:MI') AS shipment_date,
                    TO_CHAR(sh.hold_date, 'DD-MM-YYYY HH24:MI') AS hold_date,
                    TO_CHAR(sh.release_date, 'DD-MM-YYYY HH24:MI') AS release_date,
                    shr.reason,
                    op.name AS operator,
                    o.order_nr,
                    cus.category_id AS customer_category_id,
                    cuscat.category AS customer_category,
                    cuscat.customer_class_id,
                    cusclass.class AS customer_class,
                    cusattr.language_preference_id,
                    o.currency_id,
                    (
                        SELECT  SUM(si.unit_price) +
                                SUM(si.tax) +
                                SUM(si.duty) AS item_total
                        FROM    shipment_item si
                        WHERE   si.shipment_id = s.id
                    ) + s.shipping_charge AS shipment_total
            FROM    shipment s
                    JOIN link_orders__shipment los
                            ON los.shipment_id = s.id
                    JOIN orders o
                            ON o.id = los.orders_id
                    JOIN customer cus ON
                            cus.id = o.customer_id
                    JOIN customer_category cuscat
                            ON cuscat.id = cus.category_id
                    JOIN customer_class cusclass
                            ON cusclass.id = cuscat.customer_class_id
                    JOIN channel ch
                            ON ch.id = o.channel_id
                    JOIN shipment_hold sh
                            ON sh.shipment_id = s.id
                    JOIN shipment_hold_reason shr
                            ON shr.id = sh.shipment_hold_reason_id
                    JOIN operator op
                            ON op.id = sh.operator_id
                    LEFT JOIN customer_attribute cusattr
                            ON cusattr.customer_id = cus.id
            WHERE   s.shipment_status_id = $SHIPMENT_STATUS__HOLD
        ";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {

        # flag to store hold type for display as the section heading
        my $type = 'Held Shipments';

        if ( $row->{reason} eq "Incomplete Pick" ) {
            $type = 'Incomplete Picks';
        }
        if ( $row->{reason} eq "Stock Discrepancy" ) {
            $type = 'Stock Discrepancies';
        }
        if ( $row->{reason} eq "Failed Allocation" ) {
            $type = 'Failed Allocations';
        }

        # assigns the Customer's Preferred Language
        $row->{cpl} = $languages->{ $row->{language_preference_id} || 'default' };

        $list{ $row->{sales_channel} }{$type}{ $row->{id} } = $row;
        $list{ $row->{sales_channel} }{$type}{ $row->{id} }{selection_date} = get_selection_date( $dbh, $row->{id} );
        $list{ $row->{sales_channel} }{$type}{ $row->{id} }{shipment_total} = sprintf("%0.2f", $row->{shipment_total} );
        $list{ $row->{sales_channel} }{$type}{ $row->{id} }{currency_glyph} = $currency_glyph->{ $row->{currency_id} };

        my $silly_value =
            $list{ $row->{sales_channel} }{$type}{ $row->{id} }{release_date};
        if ( defined $silly_value and $silly_value ne q{} ) {

            my ( $date, $time )           = split / /, $list{ $row->{sales_channel} }{$type}{ $row->{id} }{release_date};
            my ( $day, $month, $year )    = split /-/, $date;

            $list{ $row->{sales_channel} }{$type}{ $row->{id} }{release_date_compare} = $year . $month . $day;
        }
    }

    return \%list;

}

### Subroutine : get_selection_date                          ###
# usage        : get_selection_date($dbh, $shipment_id)      #
# description  : returns the date a shipment was 'selected'  #
# parameters   : $dbh, $shipment_id                          #
# returns      : string                                      #

sub get_selection_date :Export() {

    my ( $dbh, $shipment_id) = @_;

    my $date = "";

    my $qry = "SELECT to_char(date, 'DD-MM-YYYY HH24:MI') selection_date
                FROM shipment_item_status_log
                WHERE shipment_item_id IN (SELECT id FROM shipment_item WHERE shipment_id = ?)
                AND shipment_item_status_id = $SHIPMENT_ITEM_STATUS__SELECTED
                ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $date = $row->{selection_date};
    }

    return $date;

}

### Subroutine : get_airwaybill_shipment_list           ###
# usage        : get_airwaybill_shipment_list($dbh)                 #
# description  : list of shipments awaiting an AWB to be assigned #
#                added extra logic to exclude DHL Ground as no AWB required #
# parameters   : $dbh                                            #
# returns      : hash                                            #

sub get_airwaybill_shipment_list :Export() {

    my ( $dbh ) = @_;

    my %shipments = ();
    my %items     = ();

    my %list = ();

    # get config settings for manifesting
    my $manifest_level      = manifest_level();
    my $manifest_countries  = manifest_countries();

    my $qry = "SELECT s.id as shipment_id,
                      si.id as item_id,
                      si.shipment_item_status_id,
                      los.orders_id,
                      oa.country,
                      o.order_nr,
                      oa.first_name,
                      oa.last_name,
                      ch.name as sales_channel,
                      date_trunc(\'second\',s.sla_cutoff - current_timestamp) as cutoff_time,
                      extract(epoch from (s.sla_cutoff - current_timestamp)) as cutoff_epoch,
                      c.category_id
                FROM shipment s,
                     shipment_item si,
                     link_orders__shipment los,
                     order_address oa,
                     orders o,
                     channel ch,
                     shipping_account sac,
                     carrier car,
                     customer c
                WHERE s.shipment_status_id = $SHIPMENT_STATUS__PROCESSING
                AND s.shipment_type_id > $SHIPMENT_TYPE__PREMIER
                AND (s.outward_airway_bill = 'none' OR s.return_airway_bill = 'none')
                AND s.id = si.shipment_id
                AND s.id = los.shipment_id
                AND s.shipment_address_id = oa.id
                AND los.orders_id = o.id
                AND o.channel_id = ch.id
                AND s.shipping_account_id = sac.id
                AND sac.carrier_id = car.id
                AND c.id = o.customer_id";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
        ));

        # check if manifesting is set to 'full'
        # or
        # if 'partial' make sure shipping country is switched on

        if ($manifest_level eq "off" || $manifest_level eq "full" || ($manifest_level eq "partial" && (grep { /\b$$row{country}\b/ } @{$manifest_countries}) )) {

            # only include items which haven't been cancelled
            if ( number_in_list($row->{shipment_item_status_id},
                                            $SHIPMENT_ITEM_STATUS__NEW,
                                            $SHIPMENT_ITEM_STATUS__SELECTED,
                                            $SHIPMENT_ITEM_STATUS__PICKED,
                                            $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                            $SHIPMENT_ITEM_STATUS__PACKED,
                                        ) ) {

                if ( !$shipments{ $row->{shipment_id} } ) {
                    $shipments{ $row->{shipment_id} }           = $row;
                    $shipments{ $row->{shipment_id} }{customer} = $row->{first_name}." ".$row->{last_name};
                }

                # increment number of items in the shipment
                $shipments{ $row->{shipment_id} }{num_items}++;

                # keep hash of shipment items for use later
                $items{ $row->{shipment_id} }{ $row->{item_id} } = $row->{shipment_item_status_id};
            }

        }
    }

    # query to get the "packed" date of a shipment
    $qry = "SELECT to_char(sisl.date, 'DD-MM-YYYY  HH24:MI'), to_char(sisl.date, 'YYYYMMDDHH24:MI')
                FROM shipment_item_status_log sisl, shipment_item si
                WHERE si.shipment_id = ?
                AND si.id = sisl.shipment_item_id
                AND sisl.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED
                ORDER BY sisl.date DESC
                LIMIT 1";
    $sth = $dbh->prepare($qry);

    foreach my $shipment_id ( keys %items ) {

        # vars to keep track of the number of items which are packed and not packed
        my $packed    = 0;
        my $not_packed = 0;

        # work out whats packed and what isn't
        foreach my $shipment_item_id ( keys %{ $items{$shipment_id} } ) {
            if ( number_in_list($items{$shipment_id}{$shipment_item_id},
                                $SHIPMENT_ITEM_STATUS__NEW,
                                $SHIPMENT_ITEM_STATUS__SELECTED,
                                $SHIPMENT_ITEM_STATUS__PICKED,
                                $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                            ) ) {
                $not_packed++;
            }
            elsif ( $items{$shipment_id}{$shipment_item_id} == $SHIPMENT_ITEM_STATUS__PACKED ) {
                $packed++;
            }
            else {

            }
        }

        # continue if all items in the shipment are packed
        if ( $packed > 0 && $not_packed == 0 ) {

            # check if box assigned to shipment
            my $boxes= get_shipment_boxes( $dbh, $shipment_id);

            my $num_boxes = keys(%{$boxes});

            if ( $num_boxes > 0 ) {

                # check if Shipping Form has been printed yet
                my $printed = check_shipping_input_form($dbh, $shipment_id);

                if ( $printed > 0 ) {

                    my $hash_key;       # key for hash - date packed plus shipment id to sort list by packe date desc
                    my $date_packed;

                    # get packed date
                    $sth->execute($shipment_id);
                    while ( my $row = $sth->fetchrow_arrayref() ) {
                        $hash_key       = int($shipments{$shipment_id}{cutoff_epoch} || 0) . $shipment_id;
                        $date_packed    = $row->[0];
                    }

                    # put data into final list hash
                    $list{ $shipments{$shipment_id}{sales_channel} }{ $hash_key } = $shipments{$shipment_id};
                    $list{ $shipments{$shipment_id}{sales_channel} }{ $hash_key }{shipment_id} = $shipment_id;
                    $list{ $shipments{$shipment_id}{sales_channel} }{ $hash_key }{date_packed} = $date_packed;
                }
            }

        }
    }

    return \%list;

}


### Subroutine : get_ddu_shipment_list           ###
# usage        : get_ddu_shipment_list($schema)                  #
# description  : list of shipments on DDU hold                   #
# parameters   : $schema                                         #
# returns      : hash                                            #

sub get_ddu_shipment_list :Export() {

    my ( $schema ) = @_;

    croak "Need to pass a 'Schema' connection to '" . __PACKAGE__ . "::get_ddu_shipment_list'"
                    if ( ref( $schema ) !~ /Schema/ );

    # get a map of Language Ids to Languages and the Default
    my $languages   = $schema->resultset('Public::Language')
                                ->get_all_languages_and_default;

    my $dbh = $schema->storage->dbh;

    my %channels = ();
    my %notification = ();
    my %reply     = ();

    # main list of shipments on hold
    my $qry = "SELECT   s.id AS shipment_id, oa.first_name, oa.last_name, oa.country AS destination,
                        to_char(s.date, 'DD-MM-YYYY  HH24:MI') AS date, o.order_nr, o.id AS orders_id,
                        s.email, ch.name AS sales_channel, ca.language_preference_id
                FROM    shipment s, order_address oa, link_orders__shipment los,
                        orders o
                            JOIN channel ch ON ch.id = o.channel_id
                            JOIN customer c ON c.id = o.customer_id
                            LEFT JOIN customer_attribute ca ON ca.customer_id = c.id
                WHERE   s.shipment_status_id = $SHIPMENT_STATUS__DDU_HOLD
                AND     s.shipment_address_id = oa.id
                AND     s.id = los.shipment_id
                AND     los.orders_id = o.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    # sub query to get email log for shipment
    my $subqry = "SELECT to_char(date, 'DD-MM-YYYY') AS email_date
                    FROM shipment_email_log
                    WHERE shipment_id = ?
                    AND correspondence_templates_id IN (
                        $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__REQUEST_ACCEPT_SHIPPING_TERMS,
                        $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__FOLLOW_UP
                    )
                    ORDER BY date desc LIMIT 1";
    my $substh = $dbh->prepare($subqry);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
        ));

        # get the Customer's Preferred Language
        $row->{cpl} = $languages->{ $row->{language_preference_id} || 'default' };

        $channels{ $row->{sales_channel} } = 1;

        my $notify_date = "";

        # get email log for shipment
        $substh->execute($row->{shipment_id});
        while ( my $subrow = $substh->fetchrow_hashref() ) {
            $notify_date = $subrow->{email_date};
        }

        if ($notify_date ne ""){
            $reply{ $row->{sales_channel} }{ $row->{shipment_id} } = $row;
            $reply{ $row->{sales_channel} }{ $row->{shipment_id} }{notified} = $notify_date;
        }
        else {
            $notification{ $row->{sales_channel} }{ $row->{shipment_id} } = $row;
        }
    }

    return \%channels, \%notification, \%reply;

}


### Subroutine : check_pick_complete                                            ###
# usage        : check_pick_complete($dbh, $shipment_id)                          #
# description  : returns 0 or 1 to indicate if picking is complete on a shipment  #
# parameters   : $dbh, $shipment_id                                               #
# returns      : integer                                                          #

sub check_pick_complete :Export() {
    my ($dbh, $shipment_id) = @_;

    croak('Shipment id required') if not defined $shipment_id;

    my $schema   = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);
    croak("shipment with id $shipment_id not found") unless $shipment;

    return $shipment->is_pick_complete;
}


### Subroutine : check_shipment_item_location                                         ###
# usage        : check_shipment_item_location($dbh, $shipment_item_id, $location_id) #
# description  : returns a flag for status of item in location                      #
#                1 = sku not found in location given or no stock left in location   #
#                2 = sku found in location, last item in stock                      #
#                3 = sku found in location                                          #
# parameters   : $dbh, $shipment_item_id, $location_id                              #
# returns      : integer                                                            #

sub check_shipment_item_location :Export() {

    my ( $dbh, $shipment_item_id, $location_id ) = @_;

    if ( not defined $shipment_item_id ) {
        croak('Shipment item id required');
    }
    if ( not defined $location_id ) {
        croak('Location id required');
    }

    my $flag                = 0;
    my $match_location      = 0;
    my $location_quantity   = 0;

    # get quantity for location id provided
    my $qry = "SELECT q.quantity FROM quantity q, shipment_item si WHERE si.id = ? AND ( si.variant_id = q.variant_id OR si.voucher_variant_id = q.variant_id ) AND q.location_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $shipment_item_id, $location_id );
    while ( my $row = $sth->fetchrow_arrayref ) {
        $location_quantity = $row->[0];
        $match_location    = 1;
    }

    # sku not found in location
    if ( $match_location != 1 ) {
        $flag = 1;
    }
    # sku found in location
    else {
        # no stock left in that location
        if ( $location_quantity < 1 ) {
            $flag = 1;
        }
        elsif ( ( $location_quantity - 1 ) == 0 ) {
            $flag = 2;
        }
        else {
            $flag = 3;
        }
    }

    return $flag;
}

# DCS-1126
=head2  AWBs_are_present

boolean = AWBs_are_present( {
            for => 'packing|dispatch_list|dispatching|dispatching_no_return_awb|shipment_docs',
            on  => $shipment_info
          } );

This checks to see whether both or either of the AWBs - outward_airway_bill
or return_airway_bill - are present for the shipment at several stages in
packing and dispatching.

Parameters:
Anonymous HASH ref containing a 'for' & 'on'. The 'for' describes the stage
the check is required and also decides which decision in the routine to use.
The 'on' contains the data to check which is commonoly the result of the
routine get_shipment_info().

Returns:
BOOLEAN TRUE or FALSE (1 or 0)

=cut

sub AWBs_are_present :Export() {

    my $args        = shift;

    my $result;

    CASE: {
        if ( $args->{for} eq "packing" ) {
            # Used to decide if the user should be prompted to enter the
            # Return Airwaybill at the end of the Packing process

            $result = 1;

            if ( $args->{on}{carrier} =~ /DHL Express/ && $args->{on}{return_airway_bill} eq 'none' ) {
                # If carrier is DHL Express then will need a return airway bill
                $result = 0;
            }

            ## Prevent return AWB input in packing if expect_AWB is set to 0 in config
            $result = 1 unless config_var('DistributionCentre', 'expect_AWB');

            last CASE;
        }

        if ( $args->{for} eq "dispatch_list" ) {
            # Used to decide if the shipment can be shown in the Fulfilment->Dispatch list

            $result = 0;

            # If shipment is not Premier then
            # both outward & return airway bill are required
            if ( $args->{on}{shipment_type_id} == $SHIPMENT_TYPE__PREMIER || (
                        $args->{on}{shipment_type_id} != $SHIPMENT_TYPE__PREMIER && (
                            ( ( $args->{on}{outward_airway_bill} && $args->{on}{outward_airway_bill} ne "none" ) &&
                              ( $args->{on}{return_airway_bill} && $args->{on}{return_airway_bill} ne "none" ) )
                        )
                 )
               ) {
                $result = 1;
            }

            last CASE;
        }

        if ( $args->{for} eq 'dispatching' ) {
            # Used to decide if the shipment can be dispatched on the Fulfilment->Dispatch screen

            $result = 1;

            # If shipment is not Premier then
            # both outward and return airway bills are required
            if ( $args->{on}{shipment_type_id} != $SHIPMENT_TYPE__PREMIER
                 && ( ( !$args->{on}{outward_airway_bill} || $args->{on}{outward_airway_bill} eq "none") ||
                      ( !$args->{on}{return_airway_bill} || $args->{on}{return_airway_bill} eq "none" ) )
               ) {
                $result = 0;
            }

            last CASE;
        }

        if ( $args->{for} eq 'dispatching_no_return_awb' ) {
            # Used to decide if the shipment can be dispatched on the Fulfilment->Dispatch screen
            # where no return airway bill is required

            $result = 1;

            # If shipment is not Premier then
            # only the outward airway bill is required
            if ( $args->{on}{shipment_type_id} != $SHIPMENT_TYPE__PREMIER
                 && ( !$args->{on}{outward_airway_bill} || $args->{on}{outward_airway_bill} eq "none"  ) ) {
                $result = 0;
            }

            last CASE;
        }

        if ( $args->{for} eq 'shipment_docs' ) {
            # Used to decide if Shipping Documents can be printed

            $result = 1;

            # Return airway bill required
            if ( !$args->{on}{return_airway_bill} || $args->{on}{return_airway_bill} eq 'none' ) {
                $result = 0;
            }

            ## Prevent return AWB input in packing if expect_AWB is set to 0 in config
            $result = 1 unless config_var('DistributionCentre', 'expect_AWB');

            last CASE;
        }

        if ( $args->{for} eq 'CarrierAutomation' ) {
            # Used to decide if the Carrier Automation process has already been through
            # by checking to see if the 'outward_airway_bill' field has been filled in
            # at the complete packing stage

            $result = 1;

            if ( !$args->{on}{outward_airway_bill} || $args->{on}{outward_airway_bill} eq 'none' ) {
                $result = 0;
            }

            last CASE;
        }
    };

    return $result;
}

=pod

### Subroutine : get_packing_exception_shipment_list               ###
# usage        :                                  #
# description  :   returns a hash of all shipments in packing_exception
#                  state
# parameters   :   db handle                               #
# returns      :   hash                               #

=cut


sub get_packing_exception_shipment_list :Export() {
    my ( $dbh, $schema, $iws_phase ) = @_;

    my %packing_exception_list = ();

    # get shipments which have items in packing exception, or are in PE containers
     my $qry = "SELECT s.id as shipment_id, los.orders_id, ch.name as sales_channel,
                       case when s.shipment_type_id = $SHIPMENT_TYPE__PREMIER then 1 else 0 end as premier_shipment,
                       case when cc.customer_class_id = $CUSTOMER_CLASS__EIP then 1 else 0 end as eip,
                       count(distinct si.id) as num_items,
                       max(to_char(log.date, 'YYYYMMDDHH24MI')) || s.id as sort_value,
                       max(to_char(log.date, 'DD-MM-YYYY  HH24:MI')) as date_picked,
                       max(date_trunc('second',s.sla_cutoff - current_timestamp)) as cutoff,
                       max(extract(epoch from (s.sla_cutoff - current_timestamp))) as cutoff_epoch
                FROM shipment s
                JOIN link_orders__shipment los ON los.shipment_id=s.id
                JOIN orders o ON los.orders_id=o.id
                JOIN customer c ON o.customer_id = c.id
                JOIN customer_category cc ON c.category_id = cc.id
                JOIN channel ch ON o.channel_id=ch.id
                JOIN shipment_item si ON (
                    si.shipment_id=s.id
                    AND (
                        si.shipment_item_status_id IN (
                            $SHIPMENT_ITEM_STATUS__NEW,
                            $SHIPMENT_ITEM_STATUS__SELECTED,
                            $SHIPMENT_ITEM_STATUS__PICKED,
                            $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION
                        )
                        OR (
                            si.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
                            AND si.container_id IS NOT NULL
                        )
                    )
                )
                JOIN shipment_item_status_log log ON si.id = log.shipment_item_id AND log.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PICKED
                WHERE s.shipment_class_id != $SHIPMENT_CLASS__TRANSFER_SHIPMENT
                  AND s.shipment_class_id != $SHIPMENT_CLASS__RTV_SHIPMENT
                AND s.id IN (
                    SELECT shipment_id
                    FROM shipment_item
                    WHERE shipment_item.shipment_item_status_id=$SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION
                 UNION
                    SELECT shipment_id
                    FROM shipment_item
                    JOIN container ON shipment_item.container_id=container.id
                    WHERE container.status_id = $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS
                )
                GROUP BY s.id, los.orders_id, ch.name, s.shipment_type_id, cc.customer_class_id";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
        $packing_exception_list{ $row->{sales_channel} }{ $row->{sort_value} } = $row;
    }

    # NOTE: sample shipments won't ever go to packing exeception!

    # Select comments and containerss for the shipments we found, and store them. It
    # would have been nice to do these in the queries above, but also it would
    # have made the queries above /even/ more complicated, and that's not
    # something they seem seem to need.

    # First get the shipment ids, and also add a lookup table so we can get the
    # shipment back by ID when we need (at the moment it's keyed on channel
    # first)
    my %shipment_lookup;
    my @shipment_ids =
        map {
            my $shipment_id = $_->{'shipment_id'};
            # Save to lookup
            $shipment_lookup{ $shipment_id } = $_;
            # Return a copy too
            $shipment_id;
        }
        # Find the hash values in it
        map { values %$_ }
        # Values in our exception lists
        (values %packing_exception_list);

    # Grab these shipments and prefetch their containerss
    my $rs = $schema->resultset('Public::Shipment')->search(
        {
            'me.id' => { IN => \@shipment_ids },
            #                'shipment_items.shipment_item_status_id'
            #                    => $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
        }, {
            prefetch => { shipment_items => 'container' },
        }
    );
    while (my $shipment = $rs->next) {
        my $row=$shipment_lookup{$shipment->id};

        if ( $shipment->is_awaiting_replacements($iws_phase) ) {
            $row->{px_status_msg}='Awaiting replacements';
        }
        elsif ($shipment->is_being_replaced) {
            $row->{px_status_msg}='Replacements arriving';
        }
        else {
            $row->{px_status_msg}='';
        }

        my @containers =                      # Read these from the bottom up...
            sort {$a cmp $b}                  # Sort for consistency
            uniq                              # Only want each one once
            grep { $_ }                       # Skip empty ones
            map  { $_->container_id }         # Get the container it's in
            $shipment->shipment_items;        # Foreach associated shipment item

        $row->{'containers'} = \@containers;
        $row->{'is_pigeonhole_only'} = $shipment->is_pigeonhole_only;
        $row->{'has_pigeonhole_items'} = $shipment->has_pigeonhole_items;
        $row->{'has_cage_items'} = $shipment->has_cage_items;
    }

    # Actually grab all the comments
    for my $comment (
        $schema->resultset('Public::ShipmentNote')
            ->search(
                {
                    shipment_id  => { IN => \@shipment_ids },
                    note_type_id => $NOTE_TYPE__QUALITY_CONTROL,
                }, {
                    order_by    => 'date',
                    prefetch    => 'operator'
                }
            )
    ) {
        # Find the right shipment to add them to
        my $shipment_id = $comment->shipment_id;
        my $shipment = $shipment_lookup{ $shipment_id };

        # Add them to that shipment
        $shipment->{'packing_exception_notes'} ||= [];
        push( @{ $shipment->{'packing_exception_notes'} }, $comment );
    }

    return split_out_staff_shipments($dbh,\%packing_exception_list);
}

=head2 get_orphaned_items

Returns a hashref keyed on channel 'name'. Each key is an arrayref containing
all orphaned items we know about, as DBIx::Class result rows. Prefetches variant
and voucher variant using an outer join, so each result will have one or the
other (but not both). Results are ordered by SKU.



=cut

sub get_orphaned_items :Export() {
    my ( $schema ) = @_;

    if (!$schema->isa('DBIx::Class::Schema')) {
        $schema = get_schema_using_dbh($schema,'xtracker_schema');
    }

    # Get non-voucher items. No point in prefetching channel data as it needs
    # to do some nonsense to find that out anyway that invariably makes other
    # calls that includes that data.
    my @stock = $schema->resultset('Public::OrphanItem')->search(
        { 'variant_id' => { '>' => '0' } },
        {
            prefetch => {
                'variant' => [
                    { 'product' => ['product_attribute'] },
                    'size'
                ]
            }
        }
    );

    # Get vouchers
    my @variants = $schema->resultset('Public::OrphanItem')->search(
        { 'voucher_variant_id' => { '>' => '0' } },
        {
            prefetch => {
                'voucher_variant' => { 'product' => ['channel', 'currency'] }
            }
        }
    );

    # Sort by SKU
    my @items = sort { $a->get_sku cmp $b->get_sku } @stock, @variants;

    # Place in channels
    my %channels;
    for my $item ( @items ) {
        my $channel = $item->get_channel->name;
        $channels{ $channel } ||= [];
        push( @{$channels{ $channel }}, $item );
    }

    return \%channels;
}

=head2 get_superfluous_item_containers

Returns a hashref keyed on channel name, each containing an arrayref of
hashrefs:

 {
    'theOutnet.com' => [
        {
            'container_id'    => 'MX12345',
            'cancelled_items' => 5,
            'orphaned_items'  => 2,
        },
    ]
 }

Pass in a dbh, and optionally, the result of C<get_orphaned_items> if you already
have it so we don't recall it.

=cut

sub get_superfluous_item_containers :Export() {
    my ( $dbh, $orphaned_items ) = @_;
    $orphaned_items = get_orphaned_items( $dbh ) unless $orphaned_items;

    my $schema = get_schema_using_dbh ($dbh, 'xtracker_schema');

    # We have the orphaned item counts already, so grab the cancelled item ones.
    my $rs = $schema->resultset('Public::ShipmentItem')->search({
        'me.shipment_item_status_id' => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
        'container.status_id' => $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS
    }, {
        prefetch => [
            { shipment => { shipping_account => 'channel' } },
            'container'
        ],
    });
    $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    my @cancelled_items = $rs->all;

    # Line these up by channel...
    my %channels;

    # First let's add in the orphaned items
    for my $channel ( keys %$orphaned_items ) {
        for my $item ( @{ $orphaned_items->{$channel} } ) {
            my $container_id = $item->container_id;

            # Increment number of orphaned items by one
            $channels{ $channel }->{ $container_id }->{'orphaned'}++;
            $channels{ $channel }->{ $container_id }->{'old_container_id'} = $item->old_container_id
                if defined $item->old_container_id;
        }
    }

    # Now add the cancelled items
    for my $item ( @cancelled_items ) {
        my $channel = $item->{shipment}{shipping_account}{channel}{name};
        my $container_id = NAP::DC::Barcode::Container->new_from_id(
            $item->{container_id},
        );

        $channels{ $channel }->{ $container_id }->{'is_pigeonhole'}
            = $container_id->is_type('pigeon_hole');
        # Increment number of cancelled items by one
        $channels{ $channel }->{ $container_id }->{'cancelled'}++;
    }

    # Make the data like we said it would be...
    my %return_channels;
    for my $channel ( keys %channels ) {
        my @container_ids =
            map { NAP::DC::Barcode::Container->new_from_id($_) }
            keys %{$channels{ $channel }};
        for my $container_id (@container_ids) {
            $return_channels{ $channel } ||= [];

            my $old_container_id =
                $channels{ $channel }->{ $container_id }->{'old_container_id'};
            push( @{ $return_channels{ $channel } }, {
                container_id    => $container_id,
                is_pigeonhole   => $container_id->is_type('pigeon_hole') || 0,
                cancelled_items
                    => $channels{ $channel }->{ $container_id }->{'cancelled'} || '0',
                orphaned_items
                    => $channels{ $channel }->{ $container_id }->{'orphaned'}  || '0',
                ( $old_container_id ? ( old_container_id => $old_container_id ) : ()),
            });
        }
        # Sort by container id
        $return_channels{ $channel } = [
            sort {
                $a->{'container_id'} cmp $b->{'container_id'}
            } @{ $return_channels{ $channel } }
        ];
    }
    return \%return_channels;
}

1;
