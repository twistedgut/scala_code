#!/usr/bin/perl
package XTracker::Database::Routing;
use strict;
use warnings;
use XTracker::Database::Utilities;
use XTracker::Database::Shipment;
use XTracker::Database::Customer qw(get_customer_notes);
use XTracker::XTemplate;
use Perl6::Export::Attrs;
use IO::File;
use Try::Tiny;
use XTracker::Config::Local     qw( config_var can_truncate_addresses_for_premier_routing );
use XTracker::DBEncode          qw( decode_db );

use XTracker::Constants::FromDB     qw(
                                        :correspondence_method
                                        :customer_category
                                        :customer_issue_type
                                        :return_status
                                        :routing_export_status
                                        :shipment_status
                                        :shipment_item_status
                                        :shipment_type
                                    );

use Carp;


sub generate_routing_export_file :Export() {
    my ($schema, $export_id, $filename, $cut_off, $channel_id)= @_;

    # check params
    my $croak_suffix    = "passed in to '" . __PACKAGE__ . "::generate_routing_export_file'";
    croak( "No 'schema' $croak_suffix" )            if ( !$schema );
    croak( "No 'export_id' $croak_suffix" )         if ( !$export_id );
    croak( "No 'filename' $croak_suffix" )          if ( !$filename );
    croak( "No 'cut_off' $croak_suffix" )           if ( !$cut_off );
    croak( "No 'channel_id' $croak_suffix" )        if ( !$channel_id );
    if ( ref( $schema ) !~ m/\bSchema$/ ) {
        croak( "'schema' is NOT expected DBIC Schema Class $croak_suffix" );
    }

    my $dbh = $schema->storage->dbh;

    my $routing_file = config_var('file_paths_NAP', 'source_base_path') . 'routing/' . $filename . '.txt';

    my $err;
    # now start creating the export file
    try {
        # open routing export text file
        open my $mt_fh, ">encoding(UTF-8)", $routing_file or die "Couldn't open $routing_file: $!";

        # get shipment data for export
        my $shipment_data = get_routing_export_shipment_data($schema, $cut_off, $channel_id);

        # write shipment data out to export file
        foreach my $shipment_id (keys %{$shipment_data}) {

        # strip out any newlines
        foreach my $field (keys %{$shipment_data->{$shipment_id}}) {
            next unless defined $shipment_data->{$shipment_id}{$field};
            $shipment_data->{$shipment_id}{$field} =~ s/\n//g;
            $shipment_data->{$shipment_id}{$field} =~ s/\r//g;
            $shipment_data->{$shipment_id}{$field} =~ s/\|//g;
        }

        # address lines restricted to 50 chars
        ($shipment_data->{$shipment_id}{address_line_1}, $shipment_data->{$shipment_id}{address_line_2}, $shipment_data->{$shipment_id}{county}) = _fix_address_lines( $shipment_data->{$shipment_id}{address_line_1}, $shipment_data->{$shipment_id}{address_line_2}, $shipment_data->{$shipment_id}{county} );

        my $start_window = truncate_hms_to_hour($shipment_data->{$shipment_id}->{earliest_delivery_daytime});
        my $end_window   = truncate_hms_to_hour($shipment_data->{$shipment_id}->{latest_delivery_daytime});

        # write shipment specific data
        my $shipment = $shipment_data->{$shipment_id};
        write_row_to_handle(
            $mt_fh, {
            number => $shipment->{order_nr},
            shipment_id =>$shipment_id,
            first_name => $shipment->{first_name},
            last_name => $shipment->{last_name},
            address_line_1 => $shipment->{address_line_1},
            address_line_2 => $shipment->{address_line_2},
            town => $shipment->{towncity},
            county => $shipment->{county},
            country => $shipment->{country},
            postcode => $shipment->{postcode},
            telephone => $shipment->{telephone},
            mobile_telephone => $shipment->{mobile_telephone},
            # no email
            zone => $shipment->{zone},
            start_window => $start_window,
            end_window => $end_window,
            notes => $shipment->{notes},
            type => $shipment->{type},
            routing_option => $shipment->{routing_option},
            num_bags => $shipment->{num_bags},
            sales_channel => $shipment->{sales_channel},
            source_app_name => $shipment->{source_app_name},
        });


        # log shipment as being included in export
            link_routing_export_shipment($dbh, $export_id, $shipment_id);

        }


        # get return data for export
        my $return_data = get_routing_export_return_data($schema, $channel_id);

        # write shipment data out to export file
        foreach my $return_id (keys %{$return_data}) {
            # strip out any newlines
            foreach my $field (keys %{$return_data->{$return_id}}) {
                next unless defined $return_data->{$return_id}{$field};
                $return_data->{$return_id}{$field} =~ s/\n//g;
                $return_data->{$return_id}{$field} =~ s/\r//g;
                $return_data->{$return_id}{$field} =~ s/\|//g;
            }

            # address lines restricted to 50 chars
            ($return_data->{$return_id}{address_line_1}, $return_data->{$return_id}{address_line_2}, $return_data->{$return_id}{county}) = _fix_address_lines( $return_data->{$return_id}{address_line_1}, $return_data->{$return_id}{address_line_2}, $return_data->{$return_id}{county} );

            my $start_window = config_var('Carrier_Premier', 'default_returns_start_window');
            my $end_window   = config_var('Carrier_Premier', 'default_returns_end_window');

            # write shipment specific data
            my $return = $return_data->{$return_id};
            write_row_to_handle(
                $mt_fh, {
                number => $return->{rma_number},
                # no shipment_id
                first_name => $return->{first_name},
                last_name => $return->{last_name},
                address_line_1 => $return->{address_line_1},
                address_line_2 => $return->{address_line_2},
                town => $return->{towncity},
                county => $return->{county},
                country => $return->{country},
                postcode => $return->{postcode},
                telephone => $return->{telephone},
                mobile_telephone => $return->{mobile_telephone},
                email => $return->{email},
                zone => $return->{zone},
                start_window => $start_window,
                end_window => $end_window,
                notes => $return->{notes},
                type => $return->{type},
                routing_option => config_var(
                    'Carrier_Premier','default_returns_routing_code'),
                num_bags => 1,
                sales_channel => $return->{sales_channel},
                source_app_name => $return->{source_app_name},
            });


            # log shipment as being included in export
            link_routing_export_return($dbh, $export_id, $return_id);

        }

        close $mt_fh;

        $dbh->commit();
        $err=0;
    } catch {
        $err=1;
        $dbh->rollback();
        warn "writing $routing_file failed: $_";
    };

    return if $err;
    return $routing_file;
}

sub write_row_to_handle {
    my($fh,$fields) = @_;

    my @row;
    foreach my $field (qw/
        number
        shipment_id
        first_name
        last_name
        address_line_1
        address_line_2
        town
        county
        country
        postcode
        telephone
        mobile_telephone
        email
        zone
        start_window
        end_window
        notes
        type
        routing_option
        num_bags
        sales_channel
        source_app_name
    /) {
        push @row, (defined $fields->{$field}) ? $fields->{$field} : '';
    }

    print $fh (join('|',@row)) ."\r\n";
}

sub truncate_hms_to_hour {
    my ($hms) = @_;
    return $hms =~ s/:\d\d$//r;
}

sub get_working_export_list :Export() {

    my ( $dbh ) = @_;

    my %list = ();

    my $qry
        = "SELECT e.id, (to_char(esl.date, 'YYYYMMDDHH24MI') || e.id) as date_sort,
                to_char(e.cut_off, 'DD-MM-YYYY HH24:MI') as cut_off,
                to_char(esl.date, 'DD-MM-YYYY HH24:MI') as date_created,
                to_char(esl2.date, 'DD-MM-YYYY HH24:MI') as date_sent,
                e.filename,
                e.status_id,
                es.status,
                ch.name as channel_name,
                bus.config_section
            FROM routing_export e
                LEFT JOIN routing_export_status_log esl2 ON e.id = esl2.routing_export_id AND esl2.status_id = 4,
                routing_export_status es,
                routing_export_status_log esl,
                channel ch,
                business bus
            WHERE e.status_id = es.id
            AND es.status in ('Exporting', 'Exported', 'Failed')
            AND e.id = esl.routing_export_id
            AND esl.status_id = (select id from routing_export_status where status = 'Exporting')
            AND e.channel_id = ch.id
            AND ch.business_id = bus.id
          ";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
           $list{ $$row{date_sort}} = $row;
    }

    return \%list;

}

sub get_routing_export_list :Export() {

        my ( $dbh, $args ) = @_;

    my %list = ();

    my $qry = "SELECT e.id, (to_char(esl.date, 'YYYYMMDDHH24MI') || e.id) as date_sort, to_char(e.cut_off, 'DD-MM-YYYY HH24:MI') as cut_off, to_char(esl.date, 'DD-MM-YYYY HH24:MI') as date_created, to_char(esl2.date, 'DD-MM-YYYY HH24:MI') as date_sent, e.filename, e.status_id, es.status
                                FROM routing_export e LEFT JOIN routing_export_status_log esl2 ON e.id = esl2.routing_export_id AND esl2.status_id = 4, routing_export_status es, routing_export_status_log esl
                                WHERE e.status_id = es.id
                                AND e.id = esl.routing_export_id
                                AND esl.status_id = (select id from routing_export_status where status = 'Exporting')";

        if ($args->{"type"} eq "date") {
                $qry .= "AND esl.date between '".$args->{"start"}."' and '".$args->{"end"}."'";
        }
        elsif ($args->{"type"} eq "shipment") {
                $qry .= "AND e.id IN (select routing_export_id from link_routing_export__shipment where shipment_id = ".$args->{"shipment_id"}.")";
        }
        elsif ($args->{"type"} eq "return") {
                $qry .= "AND e.id IN (select routing_export_id from link_routing_export__return where return_id = (select id from return where rma_number = '".$args->{"rma_number"}."'))";
        }

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
           $list{ $$row{date_sort}} = $row;
    }

    return \%list;

}


sub get_routing_export_shipment_data :Export() {

    my ($schema, $cut_off, $channel_id) = @_;

    # check params
    my $croak_suffix    = "passed in to '" . __PACKAGE__ . "::get_routing_export_shipment_data'";
    croak( "No 'schema' $croak_suffix" )            if ( !$schema );
    croak( "No 'cut_off' $croak_suffix" )           if ( !$cut_off );
    croak( "No 'channel_id' $croak_suffix" )        if ( !$channel_id );
    if ( ref( $schema ) !~ m/\bSchema$/ ) {
        croak( "'schema' is NOT expected DBIC Schema Class $croak_suffix" );
    }

    my $dbh = $schema->storage->dbh;

    my $channel_rec = $schema->resultset('Public::Channel')->find( $channel_id );

    my $csm_rec = _get_csm_for_phone_optin( $channel_rec );
    my $qry_phone_opt_in    = "FALSE";
    if ( $csm_rec ) {
        $qry_phone_opt_in   = "can_order_use_csm( o.id, o.customer_id, " . $csm_rec->id . " )";
    }

    my %data = ();

    # prepare shipment box sub query for use in the main loop
    my $box_qry = "SELECT COUNT(*) FROM shipment_box WHERE shipment_id = ?";
    my $box_sth = $dbh->prepare($box_qry);

    # shipment data query
    my $ship_qry = qq{SELECT s.id,
                             oa.first_name,
                             oa.last_name,
                             oa.address_line_1,
                             oa.address_line_2,
                             oa.towncity,
                             oa.county,
                             oa.country,
                             oa.postcode,
                             s.telephone,
                             s.mobile_telephone,
                             s.email,
                             o.order_nr,
                             o.customer_id,
                             sc.description AS zone,
                             sis.status,
                             'Drop' AS type,
                             '' AS notes,
                             pr.code AS routing_option,
                             pr.earliest_delivery_daytime,
                             pr.latest_delivery_daytime,
                             $qry_phone_opt_in AS can_use_phone,
                             o_attr.source_app_name
                        FROM shipment s,
                             order_address oa,
                             link_orders__shipment los,
                             orders o LEFT JOIN order_attribute o_attr ON o_attr.orders_id = o.id,
                             shipment_item si,
                             shipment_item_status sis,
                             shipment_item_status_log sisl,
                             shipping_charge sc,
                             customer c,
                             premier_routing pr
                       WHERE s.shipment_status_id = $SHIPMENT_STATUS__PROCESSING -- not on hold or cancelled
                        AND sisl.date <= ?
                        AND s.id NOT IN (
                                    SELECT  lres.shipment_id
                                    FROM    link_routing_export__shipment lres
                                                        JOIN routing_export re ON re.id = lres.routing_export_id
                                                                               AND re.status_id != $ROUTING_EXPORT_STATUS__CANCELLED
                                    WHERE   lres.shipment_id = s.id
                            ) -- shipment not already assigned to an export
                        AND s.shipment_type_id = $SHIPMENT_TYPE__PREMIER -- Premier deliveries only
                        AND s.shipment_address_id = oa.id
                        AND s.id = los.shipment_id
                        AND los.orders_id = o.id
                        AND o.customer_id = c.id
                        AND o.channel_id = ?
                        AND c.category_id != $CUSTOMER_CATEGORY__STAFF
                        AND s.id = si.shipment_id
                        AND si.shipment_item_status_id = sis.id
                        AND si.id = sisl.shipment_item_id
                        -- exclude shipments with any item in 'packing exception' status
                        AND NOT EXISTS (SELECT NULL
                                          FROM shipment_item si2
                                         WHERE si2.shipment_id=s.id
                                           AND si2.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION
                                       )
                        AND sisl.shipment_item_status_id IN ($SHIPMENT_ITEM_STATUS__SELECTED,
                                                             $SHIPMENT_ITEM_STATUS__PICKED,
                                                             $SHIPMENT_ITEM_STATUS__PACKED)
                        AND s.shipping_charge_id = sc.id
                        AND s.premier_routing_id = pr.id};
    my $ship_sth = $dbh->prepare($ship_qry);

    $ship_sth->execute($cut_off, $channel_id);

    while ( my $row = decode_db($ship_sth->fetchrow_hashref()) ) {
        $data{ $row->{id} } = $row;
        $data{ $row->{id} }{zone} =~ s/Premier - //i;

        # set default number of bags used
        $data{ $row->{id} }{num_bags} = 1;

        # set the Sales Channel Name
        $data{ $row->{id} }{sales_channel}  = $channel_rec->name;
    }

    # remove all shipments which aren't ready for export - get notes for those which are
    foreach my $shipment_id ( keys %data ) {

        # remove shipment
        if ($data{ $shipment_id }{notready}) {
            delete $data{ $shipment_id };
        }
        # get delivery notes
        else {

            # get Premier Delivery/Collection notes from customer notes
            my $notes_ref = get_customer_notes( $dbh, $data{ $shipment_id }{customer_id} );

            foreach my $note_id ( keys %{ $notes_ref } ) {
                if ($notes_ref->{$note_id}{description} eq "Premier Delivery/Collection" ) {
                    $data{ $shipment_id }{notes} .= $notes_ref->{$note_id}{note}."/";
                }
            }

            # get number of bags used
            $box_sth->execute( $shipment_id );
                while ( my $box_row = $box_sth->fetchrow_arrayref() ) {
                $data{ $shipment_id }{num_bags} = $box_row->[0];
            }

            if ( delete $data{ $shipment_id }{can_use_phone} ) {
                $data{ $shipment_id }{routing_option}   = 'C';  # 'C'all the Customer
            }
        }
    }

    return \%data;
}




sub get_routing_export_return_data :Export() {
    my ($schema, $channel_id)= @_;

    # check params
    my $croak_suffix    = "passed in to '" . __PACKAGE__ . "::get_routing_export_return_data'";
    croak( "No 'schema' $croak_suffix" )            if ( !$schema );
    croak( "No 'channel_id' $croak_suffix" )        if ( !$channel_id );
    if ( ref( $schema ) !~ m/\bSchema$/ ) {
        croak( "'schema' is NOT expected DBIC Schema Class $croak_suffix" );
    }

    my $dbh = $schema->storage->dbh;

    my $channel_rec = $schema->resultset('Public::Channel')->find( $channel_id );

    my $csm_rec = _get_csm_for_phone_optin( $channel_rec );
    my $qry_phone_opt_in    = "FALSE";
    if ( $csm_rec ) {
        $qry_phone_opt_in   = "can_order_use_csm( o.id, o.customer_id, " . $csm_rec->id . " )";
    }

    ### returns data query
    my $qry = "
SELECT
    r.id,
    r.rma_number,
    r.shipment_id,
    oa.first_name,
    oa.last_name,
    oa.address_line_1,
    oa.address_line_2,
    oa.towncity,
    oa.county,
    oa.country,
    oa.postcode,
    s.telephone,
    s.mobile_telephone,
    s.email,
    o.order_nr,
    o.customer_id,
    sc.description as zone,
    'Collection'   as type,
    ''             as notes,
    pr.code        as routing_option,
    pr.earliest_delivery_daytime,
    pr.latest_delivery_daytime,
    $qry_phone_opt_in as can_use_phone,
    o_attr.source_app_name
FROM
    return                r,
    shipment              s,
    order_address         oa,
    link_orders__shipment los,
    orders                o LEFT JOIN order_attribute o_attr on o_attr.orders_id = o.id,
    shipping_charge       sc,
    customer              c,
    premier_routing       pr
WHERE r.return_status_id = $RETURN_STATUS__AWAITING_RETURN
AND r.id NOT IN (
        SELECT  lrer.return_id
        FROM    link_routing_export__return lrer
                            JOIN routing_export re ON re.id = lrer.routing_export_id
                                                   AND re.status_id != $ROUTING_EXPORT_STATUS__CANCELLED
        WHERE   lrer.return_id = r.id
    ) -- return not already assigned to an export
AND r.id IN (
        SELECT  ri.return_id
        FROM    return_item ri
        WHERE   ri.return_id = r.id
        AND     ri.customer_issue_type_id != $CUSTOMER_ISSUE_TYPE__7__DISPATCH_FSLASH_RETURN
    ) -- don't include 'Dispatch/Return' Returns
AND r.shipment_id = s.id
AND s.shipment_type_id = $SHIPMENT_TYPE__PREMIER -- Premier deliveries only
AND s.shipment_address_id = oa.id
AND s.id = los.shipment_id
AND los.orders_id = o.id
AND o.customer_id = c.id
AND o.channel_id = ?
AND c.category_id != $CUSTOMER_CATEGORY__STAFF
AND s.shipping_charge_id = sc.id
AND s.premier_routing_id = pr.id
";
    my $sth = $dbh->prepare($qry);

    $sth->execute($channel_id);

    my %data = ();
    while ( my $row = decode_db($sth->fetchrow_hashref()) ) {
        $data{ $row->{id} } = $row;

        $data{ $row->{id} }{zone} =~ s/Premier - //i;

        # get Premier Delivery/Collection notes from customer notes
        my $notes_ref = get_customer_notes( $dbh, $data{ $row->{id} }{customer_id} );

        foreach my $note_id ( keys %{ $notes_ref } ) {
            if ($notes_ref->{$note_id}{description} eq "Premier Delivery/Collection" ) {
                $data{ $row->{id} }{notes} .= $notes_ref->{$note_id}{note}."/";
            }
        }

        if ( delete $data{ $row->{id} }{can_use_phone} ) {
            $data{ $row->{id} }{routing_option} = 'C';  # 'C'all the Customer
        }

        # set the Sales Channel Name
        $data{ $row->{id} }{sales_channel}  = $channel_rec->name;
    }

    return \%data;
}



sub check_routing_export_lock :Export() {

        my ($dbh)= @_;

        my $lock = 0;

        my $qry = "SELECT id FROM routing_export WHERE status_id = (SELECT id FROM routing_export_status WHERE status = 'Exporting')";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
       $lock = 1;
    }

        return $lock;
}


sub create_routing_export :Export() {

    my ($dbh, $filename, $cutoff, $operator_id, $channel_id)= @_;

    my $lock = 0;

    my $qry = "INSERT INTO routing_export (id,filename,cut_off,status_id,channel_id) VALUES (default, ?, ?, (SELECT id FROM routing_export_status WHERE status = 'Exporting'), ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($filename, $cutoff, $channel_id);

    my $routing_export_id = last_insert_id( $dbh, 'routing_export_id_seq' );

    ### log it
    log_routing_export_status($dbh, $routing_export_id, "Exporting", $operator_id);

    return $routing_export_id;
}

sub get_routing_export :Export() {

        my ( $dbh, $id ) = @_;

    my $qry = "SELECT e.id, e.filename, to_char(e.cut_off, 'DD-MM-YYYY HH24:MM') as cut_off, e.status_id, es.status
                                FROM routing_export e, routing_export_status es
                                WHERE e.id = ?
                                AND e.status_id = es.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    my $row = $sth->fetchrow_hashref();

    return $row;

}

sub get_routing_export_status_log :Export() {

        my ( $dbh, $id ) = @_;

        my %data = ();

    my $qry = "SELECT esl.id, to_char(esl.date, 'DD-MM-YYYY') as date, to_char(esl.date, 'HH24:MI') as time, op.name, es.status
                                FROM routing_export_status_log esl, routing_export_status es, operator op
                                WHERE esl.routing_export_id = ?
                                AND esl.status_id = es.id
                                AND esl.operator_id = op.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    while ( my $row = $sth->fetchrow_hashref() ) {
           $data{ $$row{id}} = $row;
    }

    return \%data;

}


sub update_routing_export_status :Export() {

        my ($dbh, $id, $status, $operator_id)= @_;

        ### update status
        my $qry = "UPDATE routing_export SET status_id = (SELECT id FROM routing_export_status WHERE status = ?) WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($status, $id);

    ### log it
    log_routing_export_status($dbh, $id, $status, $operator_id);

}

sub log_routing_export_status :Export() {

        my ($dbh, $id, $status, $operator_id)= @_;

        my $qry = "INSERT INTO routing_export_status_log VALUES (default, ?,(SELECT id FROM routing_export_status WHERE status = ?), ?, current_timestamp)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($id, $status, $operator_id);
}


sub get_routing_export_shipment_list :Export() {

        my ( $dbh, $export_id ) = @_;

    my %list = ();

    my $qry
        = "SELECT s.id as shipment_id, ss.status, to_char(s.date, 'DD-MM-YYYY HH24:MI') as shipment_date, oa.postcode, o.id as order_id,
            o.order_nr, oa.first_name, oa.last_name, ch.name as channel_name, bus.config_section
            FROM link_routing_export__shipment les, shipment s, shipment_status ss, link_orders__shipment los, order_address oa, orders o, channel ch, business bus
            WHERE les.routing_export_id = ?
            AND les.shipment_id = s.id
            AND s.id = los.shipment_id
            AND s.shipment_address_id = oa.id
            AND s.shipment_status_id = ss.id
            AND los.orders_id = o.id
            AND o.channel_id = ch.id
            AND ch.business_id = bus.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($export_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
            postcode
        ));
        $list{ $$row{shipment_id}} = $row;
    }

    return \%list;

}

sub get_routing_export_return_list :Export() {

        my ( $dbh, $export_id ) = @_;

    my %list = ();

    my $qry
        = "SELECT r.id as return_id, r.rma_number, r.shipment_id, rs.status, to_char(rsl.date, 'DD-MM-YYYY HH24:MI') as created_date, oa.postcode, o.id as order_id,
            o.order_nr, oa.first_name, oa.last_name, ch.name as channel_name, bus.config_section
            FROM link_routing_export__return ler, return r, shipment s, return_status rs, return_status_log rsl, link_orders__shipment los, order_address oa, orders o, channel ch, business bus
            WHERE ler.routing_export_id = ?
            AND ler.return_id = r.id
            AND r.id = rsl.return_id
            AND rsl.return_status_id = $RETURN_STATUS__AWAITING_RETURN
            AND r.return_status_id = rs.id
            AND r.shipment_id = s.id
            AND s.id = los.shipment_id
            AND s.shipment_address_id = oa.id
            AND los.orders_id = o.id
            AND o.channel_id = ch.id
            AND ch.business_id = bus.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($export_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
            postcode
        ));
        $list{ $$row{return_id}} = $row;
    }

    return \%list;

}


sub link_routing_export_shipment :Export() {

        my ( $dbh, $export_id, $shipment_id ) = @_;

        my $qry = "INSERT INTO link_routing_export__shipment VALUES (?, ?)";
        my $sth = $dbh->prepare($qry);
        $sth->execute($export_id, $shipment_id);

        return;

}

sub remove_routing_export_shipment :Export() {

        my ( $dbh, $export_id, $shipment_id ) = @_;

        my $qry = "DELETE FROM link_routing_export__shipment WHERE routing_export_id = ? AND shipment_id = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute($export_id, $shipment_id);

        return;

}


sub link_routing_export_return :Export() {

        my ( $dbh, $export_id, $return_id ) = @_;

        my $qry = "INSERT INTO link_routing_export__return VALUES (?, ?)";
        my $sth = $dbh->prepare($qry);
        $sth->execute($export_id, $return_id);

        return;

}

sub remove_routing_export_return :Export() {

        my ( $dbh, $export_id, $return_id ) = @_;

        my $qry = "DELETE FROM link_routing_export__return WHERE routing_export_id = ? AND return_id = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute($export_id, $return_id);

        return;

}


sub _fix_address_lines {

    my ( $address_line_1, $address_line_2, $county ) = @_;

    # check first if this should be done for this DC
    return ( $address_line_1, $address_line_2, $county )
                    unless ( can_truncate_addresses_for_premier_routing() );

    # address lines restricted to 50 chars

    # check 1st address line
    if ( length($address_line_1) > 50) {

        my $empty       = '';
        my $remainder   = '';

        # get everything after the 50th char from address line 1
        ($empty, $remainder) = split(/.{50}/, $address_line_1, 2);

        # add it to the start of the next address line
        $address_line_2 = $remainder .','. $address_line_2;

        # reduce line 1 down to 50 chars
        $address_line_1 = substr($address_line_1, 0, 50);

    }

    # check 2nd address line
    if ( length($address_line_2) > 50) {

        my $empty       = '';
        my $remainder   = '';

        # get everything after the 50th char from address line 2
        ($empty, $remainder) = split(/.{50}/, $address_line_2, 2);

        # add it to the start of the county field
        $county = $remainder .','. $county;

        # reduce line 2 down to 50 chars
        $address_line_2 = substr($address_line_2, 0, 50);

        # if county now greater than 50 chars just chop the end off, we're all out of fields
        if ( length($county) > 50) {
            $county = substr($county, 0, 47);
            $county .= '...';
        }

    }

    return $address_line_1, $address_line_2, $county;

}


# this returns a Correspondence Subject Method Record for 'Premier Delivery'
# for the relevant Sales Channel, but only if the Subject is enabled
# and the 'Phone' Correspondence Method is enabled for the Subject.
sub _get_csm_for_phone_optin {
    my $channel     = shift;

    my $retval;
    if ( my $subject = $channel->get_correspondence_subject('Premier Delivery') ) {
        if ( $subject->enabled ) {
            if ( my $method = $subject->get_enabled_methods()->{ $CORRESPONDENCE_METHOD__PHONE } ) {
                $retval = $method->{csm_rec};
            }
        }
    }

    return $retval;
}


1;
