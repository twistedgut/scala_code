package XTracker::Database::Reporting;

use strict;
use warnings;

use Carp;
use Data::Dump 'pp';
use DateTime::Format::Pg;
use Readonly;
use Perl6::Export::Attrs;
use Math::Round qw(:all);

use XTracker::Constants::FromDB qw(
    :delivery_type
    :return_item_status
    :shipment_item_status
    :shipment_status
    :shipment_type
    :sub_region
);
use XTracker::Database::Currency qw( get_local_conversion_rate_mapping );
use XTracker::Config::Local qw( config_var );
use XTracker::Database qw( get_schema_using_dbh );

### Subroutine : get_outbound_overview                        ###
# usage        : $hash_ptr = get_outbound_overview(             #
#                          $dbh,                                #
#                          $date,                               #
#                          $type,                               #
#                          $channel_id                          #
#                     );                                        #
# description  : This gets an overview of Outbound items giving #
#                a summary of New, Selected, Picked, Packed &   #
#                Dispatched for a date. Can be shown by Items   #
#                or Shipments, also can be filtered by Sales    #
#                Channel.                                       #
# parameters   : A Database Handle, A Date, Type (Items or      #
#                Shipments) and a Sales Channel Id.             #
# returns      : A pointer to a HASH containing the results.    #

sub get_outbound_overview :Export(:Overview) {

    my ($dbh, $date, $type, $channel_id) = @_;

    my %list = ();
    my $qry;
    my @args;

    if ($channel_id) {
        $channel_id = ref $channel_id ? $channel_id : [$channel_id];
    }

    if ($type eq 'Items') {
        if (!$channel_id) {
            $qry = "SELECT shipment_item_status_id
                    FROM shipment_item_status_log
                    WHERE date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'";
        }
        else {
            $qry = "SELECT  sisl.shipment_item_status_id
                    FROM    shipment_item_status_log sisl,
                            shipment_item si,
                            link_orders__shipment los,
                            orders o
                    WHERE   sisl.date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'
                    AND     sisl.shipment_item_id = si.id
                    AND     los.shipment_id = si.shipment_id
                    AND     los.orders_id = o.id";

            $qry .= sprintf(
                ' AND o.channel_id IN (%s)',
                join q{, }, ('?') x scalar @$channel_id
            );

            $qry .= " UNION ALL
                    SELECT  sisl.shipment_item_status_id
                    FROM    shipment_item_status_log sisl,
                            shipment_item si,
                            link_stock_transfer__shipment lsts,
                            stock_transfer st
                    WHERE   sisl.date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'
                    AND     sisl.shipment_item_id = si.id
                    AND     lsts.shipment_id = si.shipment_id
                    AND     lsts.stock_transfer_id = st.id";

            $qry .= sprintf(
                ' AND st.channel_id IN (%s)',
                join q{, }, ('?') x scalar @$channel_id
            );

            # Push the channel id(s) onto args twice due to the union
            push @args, @$channel_id, @$channel_id;
        }
    }
    else {
        if (!$channel_id) {
            $qry = "SELECT  si.shipment_id,
                            sis.shipment_item_status_id,
                            COUNT(sis.*) AS total
                    FROM    shipment_item si,
                            shipment_item_status_log sis
                    WHERE   sis.date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'
                    AND     sis.shipment_item_id = si.id
                    GROUP BY    si.shipment_id,
                                sis.shipment_item_status_id";
        }
        else {
            $qry = "SELECT  si.shipment_id,
                            sisl.shipment_item_status_id,
                            COUNT(sisl.*) AS total
                    FROM    shipment_item si,
                            shipment_item_status_log sisl,
                            link_orders__shipment los,
                            orders o
                    WHERE   sisl.date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'
                    AND     sisl.shipment_item_id = si.id
                    AND     los.shipment_id = si.shipment_id
                    AND     los.orders_id = o.id";

            $qry .= sprintf(
                ' AND o.channel_id IN (%s)',
                join q{, }, ('?') x scalar @$channel_id
            );

            $qry .= " GROUP BY  si.shipment_id,
                                sisl.shipment_item_status_id
                    UNION ALL
                    SELECT  si.shipment_id,
                            sisl.shipment_item_status_id,
                            COUNT(sisl.*) AS total
                    FROM    shipment_item si,
                            shipment_item_status_log sisl,
                            link_stock_transfer__shipment lsts,
                            stock_transfer st
                    WHERE   sisl.date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'
                    AND     sisl.shipment_item_id = si.id
                    AND     lsts.shipment_id = si.shipment_id
                    AND     lsts.stock_transfer_id = st.id";

            $qry .= sprintf(
                ' AND    st.channel_id IN (%s)
                GROUP BY    si.shipment_id,
                            sisl.shipment_item_status_id',
                join q{, }, ('?') x scalar @$channel_id
            );

            # Push the channel id(s) onto args twice due to the union
            push @args, @$channel_id, @$channel_id;
        }
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute(@args);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $list{ $$row{shipment_item_status_id} }++;
    }

    if ($type eq 'Items') {
        if (!$channel_id) {
            $qry = "SELECT  COUNT(*) AS total
                    FROM    shipment_item
                    WHERE   shipment_id IN (SELECT id FROM shipment WHERE date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY')";
        }
        else {
            $qry = "SELECT  COUNT(*) AS total
                    FROM    shipment_item
                    WHERE   shipment_id IN (
                        SELECT  s.id
                        FROM    shipment s,
                                link_orders__shipment los,
                                orders o
                        WHERE   s.date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'
                        AND     s.id = los.shipment_id
                        AND     o.id = los.orders_id";

            $qry .= sprintf(
                ' AND o.channel_id IN (%s)',
                join q{, }, ('?') x scalar @$channel_id
            );

            $qry .=     " UNION
                        SELECT  s.id
                        FROM    shipment s,
                                link_stock_transfer__shipment lsts,
                                stock_transfer st
                        WHERE   s.date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'
                        AND     s.id = lsts.shipment_id
                        AND     st.id = lsts.stock_transfer_id";

            $qry .= sprintf(
                ' AND st.channel_id IN (%s))',
                join q{, }, ('?') x scalar @$channel_id
            );
        }
    }
    else {
        if (!$channel_id) {
            $qry = "SELECT  COUNT(*) AS total
                    FROM    shipment
                    WHERE   date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'";
        }
        else {
            $qry = "SELECT SUM(total) AS total FROM (
                        SELECT  COUNT(*) AS total
                        FROM    shipment s,
                                link_orders__shipment los,
                                orders o
                        WHERE   s.date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'
                        AND     s.id = los.shipment_id
                        AND     o.id = los.orders_id";

            $qry .= sprintf(
                ' AND o.channel_id IN (%s)',
                join q{, }, ('?') x scalar @$channel_id
            );

            $qry .=     " UNION ALL
                        SELECT  COUNT(*) AS total
                        FROM    shipment s,
                                link_stock_transfer__shipment lsts,
                                stock_transfer st
                        WHERE   s.date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'
                        AND     s.id = lsts.shipment_id
                        AND     st.id = lsts.stock_transfer_id";

            $qry .= sprintf(
                ' AND st.channel_id IN (%s)) AS total',
                join q{, }, ('?') x scalar @$channel_id
            );
        }
    }

    $sth = $dbh->prepare($qry);
    # The channel IDs (if given) have already been added to args for the previous query
    $sth->execute(@args);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $list{ 1 } = $$row{total};
    }

    return \%list;
}


### Subroutine : get_inbound_overview                         ###
# usage        : $hash_ptr = get_inbound_overview(              #
#                          $dbh,                                #
#                          $date,                               #
#                          $channel_id                          #
#                     );                                        #
# description  : This gives an overview of Inbound Deliveries & #
#                Returns for a given date. Also can be filtered #
#                by Sales Channel.                              #
# parameters   : Database Handler, Date & Sales Channel Id.     #
# returns      : A pointer to a HASH containing the results.    #

sub get_inbound_overview :Export(:Overview) {

    my ($dbh, $date, $channel_id) = @_;

    my %list = ();
    my @args;
    my $qry;

    if ($channel_id) {
        $channel_id = ref $channel_id ? $channel_id : [$channel_id];
    }

    # goods in
    $qry =  "SELECT ld.delivery_action_id,
                    SUM(ld.quantity) AS total
            FROM    log_delivery ld,
                    link_delivery__stock_order ldso,
                    stock_order so,
                    purchase_order po
            WHERE   ld.date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'
            AND     ld.delivery_id = ldso.delivery_id
            AND     so.id = ldso.stock_order_id
            AND     so.purchase_order_id = po.id";

    if ($channel_id) {
        $qry .= sprintf(
                ' AND po.channel_id IN (%s)',
                join q{, }, ('?') x scalar @$channel_id
            );
        push @args, @$channel_id;
    }

    $qry .= " GROUP BY ld.delivery_action_id";

    my $sth = $dbh->prepare($qry);
    $sth->execute(@args);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $list{goodsin}{ $$row{delivery_action_id} } += $$row{total};
    }

    # returns in
    if (!$channel_id) {
        $qry =  "SELECT risl.return_item_status_id,
                        COUNT(*) AS total
                FROM    return_item_status_log risl
                WHERE   risl.date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'
                GROUP BY    risl.return_item_status_id";
    }
    else {
        $qry =  "SELECT return_item_status_id,
                        SUM(total) AS total FROM (
                    SELECT  risl.return_item_status_id,
                            COUNT(*) AS total
                    FROM    return_item_status_log risl,
                            return_item ri,
                            shipment_item si,
                            link_orders__shipment los,
                            orders o
                    WHERE   risl.date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'
                    AND     risl.return_item_id = ri.id
                    AND     ri.shipment_item_id = si.id
                    AND     los.shipment_id = si.shipment_id
                    AND     los.orders_id = o.id";

        $qry .= sprintf(
                ' AND o.channel_id IN (%s)',
                join q{, }, ('?') x scalar @$channel_id
            );

        $qry .=     " GROUP BY risl.return_item_status_id
                    UNION ALL
                    SELECT  risl.return_item_status_id,
                            COUNT(*) AS total
                    FROM    return_item_status_log risl,
                            return_item ri,
                            shipment_item si,
                            link_stock_transfer__shipment lsts,
                            stock_transfer st
                    WHERE   risl.date BETWEEN '$date' AND timestamp '$date' + INTERVAL '1 DAY'
                    AND     risl.return_item_id = ri.id
                    AND     ri.shipment_item_id = si.id
                    AND     lsts.shipment_id = si.shipment_id
                    AND     lsts.stock_transfer_id = st.id";

        $qry .= sprintf(
                '   AND st.channel_id IN (%s)
                    GROUP BY risl.return_item_status_id
                ) AS outer_qry
                GROUP BY return_item_status_id',
                join q{, }, ('?') x scalar @$channel_id
            );
        push @args, @$channel_id;
    }

    $sth    = $dbh->prepare($qry);
    $sth->execute(@args);

    while ( my $row = $sth->fetchrow_hashref() ) {
        if ($$row{return_item_status_id} == $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION) {
            $$row{return_item_status_id} = $RETURN_ITEM_STATUS__PASSED_QC;
        }
        $list{returns}{ $$row{return_item_status_id} } += $$row{total};
    }

    return \%list;
}

sub _format_time {
    my ( $trunc, $timestamp ) = @_;
    my $fmt = $trunc eq 'hour'            ? '%F %H:%M'
            : $trunc =~ m{^(?:day|week)$} ? '%F'
            : $trunc eq 'month'           ? '%Y-%m'
            : croak q{you must truncate by one of 'hour', 'day', 'week' or 'month'};
    return DateTime::Format::Pg->parse_datetime($timestamp)->strftime($fmt);
}

=head2 shipment_summary_list( \%args ) : \@results

Returns an arrayref of hashrefs with totals for received or dispatched
shipments for a date range. Can be grouped by hour, day, week or month. Also
accepts an optional channel_id can be passed in to filter the list further.

=cut

sub shipment_summary_list :Export(:Shipment) {
    my ( $args ) = @_;

    if ( my @vals = grep {
            not defined $args->{$_}
        } qw{dbh start end grouping status}
    ) {
        croak sprintf(
            'You must provide a hashref with value(s) for %s',
            join q{, }, @vals
        );
    }

    for my $arg (qw/start end/) {
        croak "$arg must be a DateTime object"
            if !$args->{$arg} || !$args->{$arg}->isa('DateTime');
    }

    my ($dbh, $start, $end, $trunc, $status, $channel_id)
        = @{$args}{qw/dbh start end grouping status channel_id/};

    my $qry;
    my @args = ((map { $_->strftime('%F %H:%M') } $start, $end), $status);
    my $trunc_sql = $trunc eq 'week'
                  ? "(DATE_TRUNC('$trunc',ssl.date + interval '1 day') - interval '1 day')"
                  : "DATE_TRUNC('$trunc',ssl.date)";

    if (!$channel_id) {
        $qry = "SELECT $trunc_sql AS trunc_date, COUNT(ssl.*) AS total
                FROM shipment_status_log ssl
                WHERE ssl.date BETWEEN ? AND ?
                AND ssl.shipment_status_id = ?
                GROUP BY trunc_date
                ORDER BY trunc_date
                ";
    }
    else {
        $qry    =<<QRY
SELECT trunc_date, SUM(total) AS total FROM (
    SELECT  $trunc_sql AS trunc_date,
            COUNT(ssl.*) AS total
    FROM    shipment_status_log ssl,
            link_orders__shipment los,
            orders o
    WHERE   ssl.date BETWEEN ? AND ?
    AND     ssl.shipment_status_id = ?
    AND     ssl.shipment_id = los.shipment_id
    AND     o.id = los.orders_id
    AND     o.channel_id = ?
    GROUP BY trunc_date
    UNION ALL
    SELECT  $trunc_sql AS trunc_date,
            COUNT(ssl.*) AS total
    FROM    shipment_status_log ssl,
            link_stock_transfer__shipment lsts,
            stock_transfer st
    WHERE   ssl.date BETWEEN ? AND ?
    AND     ssl.shipment_status_id = ?
    AND     ssl.shipment_id = lsts.shipment_id
    AND     st.id = lsts.stock_transfer_id
    AND     st.channel_id = ?
    GROUP BY trunc_date
) AS outer_qry
GROUP BY trunc_date
ORDER BY trunc_date
QRY
;
        # add the channel_id to the list of args
        push @args,$channel_id;
        # dupe the args so the UNION works
        push @args,@args;
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute(@args);

    my @list;
    while ( my $row = $sth->fetchrow_hashref() ) {
        push @list, {
            start  => _format_time($trunc, $row->{trunc_date}),
            total => $row->{total},
        };
    }

    return \@list;
}

=head2 inbound_summary_list( \%args ) : \@results

Returns an arrayref of hashrefs with totals for delivery actions for a given
date range. Can be grouped by hour, day, week or month. Also accepts an
optional channel_id can be passed in to filter the list further.

=cut

sub inbound_summary_list :Export(:Inbound) {
    my ( $args ) = @_;

    if ( my @vals = grep {
            not defined $args->{$_}
        } qw{dbh start end grouping report_type_id}
    ) {
        croak sprintf(
            'You must provide a hashref with value(s) for %s',
            join q{, }, @vals
        );
    }

    for my $arg (qw/start end/) {
        croak "$arg must be a DateTime object"
            if !$args->{$arg} || !$args->{$arg}->isa('DateTime');
    }

    my ($dbh, $start, $end, $trunc, $delivery_action_id, $channel_id)
        = @{$args}{qw/dbh start end grouping report_type_id channel_id/};

    my $qry;
    my @args = ((map { $_->strftime('%F %H:%M') } $start, $end), $delivery_action_id);
    my $trunc_sql = $trunc eq 'week'
                  ? "(DATE_TRUNC('$trunc',ld.date + interval '1 day') - interval '1 day')"
                  : "DATE_TRUNC('$trunc',ld.date)";

    if (!$channel_id) {
        $qry = "SELECT $trunc_sql AS trunc_date,
                SUM(ld.quantity) AS total,
                COUNT(DISTINCT so.product_id) AS total_nr_of_pids
                FROM    log_delivery ld,
                        delivery d,
                        link_delivery__stock_order ldso,
                        stock_order so
                WHERE   ld.date BETWEEN ? AND ?
                AND     ld.delivery_action_id = ?
                AND     ld.delivery_id = d.id
                AND     d.type_id = $DELIVERY_TYPE__STOCK_ORDER
                AND     ldso.delivery_id = d.id
                AND     so.id = ldso.stock_order_id
                GROUP BY trunc_date
                ORDER BY trunc_date";
    } else {
        # Have been given either a channel ID or array ref of channel IDs
        $qry = "SELECT  $trunc_sql AS trunc_date,
                SUM(ld.quantity) AS total,
                COUNT(DISTINCT so.product_id) AS total_nr_of_pids
                FROM    log_delivery ld,
                        delivery d,
                        link_delivery__stock_order ldso,
                        stock_order so,
                        purchase_order po
                WHERE   ld.date BETWEEN ? AND ?
                AND     ld.delivery_action_id = ?
                AND     ld.delivery_id = d.id
                AND     d.type_id = $DELIVERY_TYPE__STOCK_ORDER
                AND     ldso.delivery_id = d.id
                AND     so.id = ldso.stock_order_id
                AND     po.id = so.purchase_order_id";

        $channel_id = ref $channel_id ? $channel_id : [$channel_id];
        $qry .= sprintf(
            ' AND po.channel_id IN (%s)',
            join q{, }, ('?') x scalar @$channel_id
        );
        push @args, @$channel_id;

        $qry .= " GROUP BY trunc_date
                ORDER BY trunc_date";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute(@args);

    my @list;
    while ( my $row = $sth->fetchrow_hashref() ) {
        push @list, {
            start => _format_time($trunc, $row->{trunc_date}),
            total => $row->{total},
            total_nr_of_pids => $row->{total_nr_of_pids}
        };
    }

    return \@list;
}

=head2 inbound_operator_list( \%args ) : \@results

Returns an arrayref of hashrefs with totals for delivery actions for a given
date range and grouped by operators. Can be grouped by hour, day, week or
month. Also accepts an optional channel_id can be passed in to filter the list
further.

=cut

sub inbound_operator_list :Export(:Inbound) {
    my ( $args ) = @_;

    if ( my @vals = grep {
            not defined $args->{$_}
        } qw{dbh start end grouping report_type_id}
    ) {
        croak sprintf(
            'You must provide a hashref with value(s) for %s',
            join q{, }, @vals
        );
    }

    for my $arg (qw/start end/) {
        croak "$arg must be a DateTime object"
            if !$args->{$arg} || !$args->{$arg}->isa('DateTime');
    }

    my ($dbh, $start, $end, $trunc, $delivery_action_id, $channel_id)
        = @{$args}{qw/dbh start end grouping report_type_id channel_id/};

    my $qry;
    my @args = ((map { $_->strftime('%F %H:%M') } $start, $end), $delivery_action_id);
    my $trunc_sql = $trunc eq 'week'
                  ? "(DATE_TRUNC('$trunc',ld.date + interval '1 day') - interval '1 day')"
                  : "DATE_TRUNC('$trunc',ld.date)";

    if (!$channel_id) {
        $qry = "SELECT op.name, $trunc_sql AS trunc_date,
                SUM(ld.quantity) AS total,
                COUNT(DISTINCT so.product_id) AS total_nr_of_pids
                FROM    log_delivery ld,
                        delivery d,
                        operator op,
                        link_delivery__stock_order ldso,
                        stock_order so
                WHERE   ld.date BETWEEN ? AND ?
                AND     ld.delivery_action_id = ?
                AND     ld.operator_id = op.id
                AND     ld.delivery_id = d.id
                AND     d.type_id = $DELIVERY_TYPE__STOCK_ORDER
                AND     ldso.delivery_id = d.id
                AND     so.id = ldso.stock_order_id
                GROUP BY op.name, trunc_date
                ORDER BY op.name, trunc_date";
    } else {
        # Have been given either a channel ID or array ref of channel IDs
        $qry = "SELECT op.name, $trunc_sql AS trunc_date,
                SUM(ld.quantity) AS total,
                COUNT(DISTINCT so.product_id) AS total_nr_of_pids
                FROM    log_delivery ld,
                        delivery d,
                        operator op,
                        link_delivery__stock_order ldso,
                        stock_order so,
                        purchase_order po
                WHERE   ld.date BETWEEN ? AND ?
                AND     ld.delivery_action_id = ?
                AND     ld.operator_id = op.id
                AND     ld.delivery_id = d.id
                AND     d.type_id = $DELIVERY_TYPE__STOCK_ORDER
                AND     ldso.delivery_id = d.id
                AND     so.id = ldso.stock_order_id
                AND     po.id = so.purchase_order_id";

        $channel_id = ref $channel_id ? $channel_id : [$channel_id];
        $qry .= sprintf(
            ' AND po.channel_id IN (%s)',
            join q{, }, ('?') x scalar @$channel_id
        );
        push @args, @$channel_id;

        $qry .= " GROUP BY op.name, trunc_date
                ORDER BY op.name, trunc_date";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute(@args);

    my @list;
    while ( my $row = $sth->fetchrow_hashref() ) {
        push @list, {
            start => _format_time($trunc, $row->{trunc_date}),
            total => $row->{total},
            operator => $row->{name},
            total_nr_of_pids => $row->{total_nr_of_pids}
        };
    }

    return \@list;
}

=head2 returns_summary_list( \%args ) : \@results

Returns an arrayref of hashrefs with totals for return items for a given date
range. Can be grouped by hour, day, week or month. Also accepts optional
channel_ids, which can be passed in to filter the list further.

=cut

sub returns_summary_list :Export(:Returns) {
    my ( $args ) = @_;

    if ( my @vals = grep {
            not defined $args->{$_}
        } qw{dbh start end grouping report_type_id}
    ) {
        croak sprintf(
            'You must provide a hashref with value(s) for %s',
            join q{, }, @vals
        );
    }

    for my $arg (qw/start end/) {
        croak "$arg must be a DateTime object"
            if !$args->{$arg} || !$args->{$arg}->isa('DateTime');
    }

    my ($dbh, $start, $end, $trunc, $return_item_status_id, $channel_id)
        = @{$args}{qw/dbh start end grouping report_type_id channel_id/};

    my $schema = get_schema_using_dbh($dbh, "xtracker_schema");

    $start = $schema->format_datetime($start);
    $end = $schema->format_datetime($end);

    my $qry;
    my @args = ($start, $end, @$return_item_status_id);
    my $in_clause = join q{, }, map { q{?} } @{$return_item_status_id};
    my $trunc_sql = $trunc eq 'week'
                  ? "(DATE_TRUNC('$trunc',risl.date + interval '1 day') - interval '1 day')"
                  : "DATE_TRUNC('$trunc',risl.date)";

    if (!$channel_id) {
        $qry = "SELECT $trunc_sql AS trunc_date, COUNT(*) AS total
                FROM return_item_status_log risl
                WHERE date BETWEEN ? AND ?
                AND return_item_status_id IN ($in_clause)
                GROUP BY trunc_date
                ORDER BY trunc_date";
    } else {
        $channel_id = ref $channel_id ? $channel_id : [$channel_id];

        $qry = "SELECT trunc_date, SUM(total) AS total FROM (
                    SELECT  $trunc_sql AS trunc_date,
                            COUNT(*) AS total
                    FROM    return_item_status_log risl,
                            return_item ri,
                            shipment_item si,
                            link_orders__shipment los,
                            orders o
                    WHERE   risl.date BETWEEN ? AND ?
                    AND     risl.return_item_status_id IN ($in_clause)
                    AND     risl.return_item_id = ri.id
                    AND     ri.shipment_item_id = si.id
                    AND     los.shipment_id = si.shipment_id
                    AND     o.id = los.orders_id";

        $qry .= sprintf(
            ' AND o.channel_id IN (%s)',
            join q{, }, ('?') x scalar @$channel_id
        );
        push @args, @$channel_id;

        # Push times and return item status ID into args again for second SELECT query
        push @args, ($start, $end, @$return_item_status_id);

        $qry .=     " GROUP BY trunc_date
                UNION ALL
                    SELECT  $trunc_sql AS trunc_date,
                            COUNT(*) AS total
                    FROM    return_item_status_log risl,
                            return_item ri,
                            shipment_item si,
                            link_stock_transfer__shipment lsts,
                            stock_transfer st
                    WHERE   risl.date BETWEEN ? AND ?
                    AND     risl.return_item_status_id IN ($in_clause)
                    AND     risl.return_item_id = ri.id
                    AND     ri.shipment_item_id = si.id
                    AND     lsts.shipment_id = si.shipment_id
                    AND     st.id = lsts.stock_transfer_id";

        $qry .= sprintf(
            ' AND st.channel_id IN (%s)',
            join q{, }, ('?') x scalar @$channel_id
        );
        push @args, @$channel_id;

        $qry .=     " GROUP BY trunc_date
                ) AS outer_qry
                GROUP BY trunc_date
                ORDER BY trunc_date";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute(@args);

    my @list;
    while ( my $row = $sth->fetchrow_hashref() ) {
        push @list, {
            start => _format_time($trunc, $row->{trunc_date}),
            total => $row->{total},
        };
    }
    return \@list;
}

=head2 returns_operator_list( \%args ) : \@results

Returns an arrayref of hashrefs with totals for return items for a given date
range grouped by operators. Can be grouped by hour, day, week or month. Also
accepts optional channel_ids, which can be passed in to filter the list further.

=cut

sub returns_operator_list :Export(:Returns) {
    my ( $args ) = @_;

    if ( my @vals = grep {
            not defined $args->{$_}
        } qw{dbh start end grouping report_type_id}
    ) {
        croak sprintf(
            'You must provide a hashref with value(s) for %s',
            join q{, }, @vals
        );
    }

    for my $arg (qw/start end/) {
        croak "$arg must be a DateTime object"
            if !$args->{$arg} || !$args->{$arg}->isa('DateTime');
    }

    my ($dbh, $start, $end, $trunc, $return_item_status_id, $channel_id)
        = @{$args}{qw/dbh start end grouping report_type_id channel_id/};

    my $schema = get_schema_using_dbh($dbh, "xtracker_schema");

    $start = $schema->format_datetime($start);
    $end = $schema->format_datetime($end);

    my $qry;
    my @args = ($start, $end, @$return_item_status_id);
    my $in_clause = join q{, }, map { q{?} } @{$return_item_status_id};
    my $trunc_sql = $trunc eq 'week'
                  ? "(DATE_TRUNC('$trunc',log.date + interval '1 day') - interval '1 day')"
                  : "DATE_TRUNC('$trunc',log.date)";

    if (!$channel_id) {
        $qry = "SELECT op.name, $trunc_sql AS trunc_date, COUNT(log.*) AS total
                FROM return_item_status_log log, operator op
                WHERE log.date BETWEEN ? AND ?
                AND log.return_item_status_id IN ($in_clause)
                AND log.operator_id = op.id
                GROUP BY op.name, trunc_date
                ORDER BY op.name, trunc_date";
    } else {
        $channel_id = ref $channel_id ? $channel_id : [$channel_id];

        $qry = "SELECT name, trunc_date, SUM(total) AS total FROM (
                    SELECT  op.name,
                            $trunc_sql AS trunc_date,
                            COUNT(log.*) AS total
                    FROM    return_item_status_log log,
                            operator op,
                            return_item ri,
                            shipment_item si,
                            link_orders__shipment los,
                            orders o
                    WHERE   log.date BETWEEN ? AND ?
                    AND     log.return_item_status_id IN ($in_clause)
                    AND     log.operator_id = op.id
                    AND     log.return_item_id = ri.id
                    AND     si.id = ri.shipment_item_id
                    AND     los.shipment_id = si.shipment_id
                    AND     o.id = los.orders_id";

        $qry .= sprintf(
            ' AND o.channel_id IN (%s)',
            join q{, }, ('?') x scalar @$channel_id
        );
        push @args, @$channel_id;

        # Push times and return item status ID into args again for second SELECT query
        push @args, ($start, $end, @$return_item_status_id);

        $qry .=     " GROUP BY op.name, trunc_date
                    UNION ALL
                    SELECT  op.name,
                            $trunc_sql AS trunc_date,
                            COUNT(log.*) AS total
                    FROM    return_item_status_log log,
                            operator op,
                            return_item ri,
                            shipment_item si,
                            link_stock_transfer__shipment lsts,
                            stock_transfer st
                    WHERE   log.date BETWEEN ? AND ?
                    AND     log.return_item_status_id IN ($in_clause)
                    AND     log.operator_id = op.id
                    AND     log.return_item_id = ri.id
                    AND     si.id = ri.shipment_item_id
                    AND     lsts.shipment_id = si.shipment_id
                    AND     st.id = lsts.stock_transfer_id";

        $qry .= sprintf(
            ' AND st.channel_id IN (%s)',
            join q{, }, ('?') x scalar @$channel_id
        );
        push @args, @$channel_id;

        $qry .=     " GROUP BY op.name, trunc_date
                ) AS outer_qry
                GROUP BY name, trunc_date
                ORDER BY name, trunc_date";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute(@args);

    my @list;
    while ( my $row = $sth->fetchrow_hashref() ) {
        push @list, {
            start => _format_time($trunc, $row->{trunc_date}),
            total => $row->{total},
            operator => $row->{name},
        };
    }

    return \@list;
}


### Subroutine : outbound_airwaybill_report                           ###
# usage        : $hash_ptr = outbound_airwaybill_report(                #
#                      $dbh,                                            #
#                      $country,                                        #
#                      $start_date,                                     #
#                      $end_date,                                       #
#                      $channel_id,                                     #
#                      $channel_hash_ptr                                #
#                      $carrier_id                  #
#                   );                                                  #
# description  : This produces a report showing the costs for delivery  #
#                of items excluding premier delivery. A date range can  #
#                be passed in along with a country ('All' to do the     #
#                lot) and a sales channel id to filter the report       #
#                further.                                               #
# parameters   : Database Handle, Country ('All' for all countries),    #
#                Start Date, End Date, Sales Channel Id, Sales Channels #
#                HASH pointer to all Channels with the Channel Id as    #
#                the KEY.                                               #
# returns      : A pointer to a HASH containing the results.            #

sub outbound_airwaybill_report :Export(:ShippingReports) {
    my ($dbh, $country, $start, $end, $channel_id, $channels, $carrier_id, $carriers)   = @_;

    # get DHL outbound rates
    my $dhl_rates       = _get_outbound_dhl_rates($dbh);
    # get conversion rates to local currency
    my $conversion_rates = get_local_conversion_rate_mapping($dbh);
    my %output = ();
    my @args   = ($start,$end);

    my $qry =<<QRY
SELECT  s.id,
        s.outward_airway_bill,
        s.shipping_account_id,
        sac.account_number,
        c.country,
        c.dhl_tariff_zone,
        to_char(ssl.date, 'DD-MM-YYYY') as date,
        o.order_nr,
        o.currency_id,
        sum(sa.weight) as item_weight,
        s.shipping_charge,
        s.nominated_delivery_date,
        o.channel_id,
                sac.carrier_id,
        CASE
            WHEN (ssl.date < '2007-06-12') OR
                 (ssl.date > '2007-09-11' AND (s.shipment_type_id = $SHIPMENT_TYPE__DOMESTIC OR c.sub_region_id = $SUB_REGION__EU_MEMBER_STATES))
                THEN
                    (s.shipping_charge + sum( CASE WHEN si.unit_price = 0 THEN 1 ELSE si.unit_price END + si.tax ))
                ELSE
                    (s.shipping_charge + SUM( CASE WHEN si.unit_price = 0 THEN 1 ELSE si.unit_price END ))
        END AS total_value,
        SUM( si.tax ) AS total_tax,
        SUM( si.duty ) AS total_duty
FROM    shipment s,
        shipping_account sac,
        shipment_status_log ssl,
        link_orders__shipment los,
        orders o,
        order_address oa,
        country c,
        shipment_item si,
        variant v,
        shipping_attribute sa
WHERE   ssl.date BETWEEN ? AND ?
QRY
;

    if ($country ne "All") {
        $qry .= "AND c.country = ? ";
        push @args,$country;
    }
    if ($channel_id) {
        $qry .= "AND o.channel_id = ? ";
        push @args,$channel_id;
    }
        if ($carrier_id) {
        $qry .= "AND sac.carrier_id = ? ";
        push @args,$carrier_id;
    }

    $qry .=<<WHERE_CLAUSE
AND     s.shipping_account_id = sac.id
AND     s.shipment_type_id != $SHIPMENT_TYPE__PREMIER -- DHL deliveries only
AND     s.id = los.shipment_id
AND     los.orders_id = o.id
AND     s.id = ssl.shipment_id
AND     ssl.shipment_status_id = $SHIPMENT_STATUS__DISPATCHED
AND     s.shipment_address_id = oa.id
AND     oa.country = c.country
AND     s.id = si.shipment_id
AND     si.shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
AND     si.shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCELLED
AND     si.variant_id = v.id
AND     v.product_id = sa.product_id
GROUP BY s.id,
         s.outward_airway_bill,
         s.shipment_type_id,
         s.shipping_account_id,
         sac.account_number,
         c.country,
         c.sub_region_id,
         c.dhl_tariff_zone,
         ssl.date,
         o.order_nr,
         o.currency_id,
         s.shipping_charge,
         s.nominated_delivery_date,
         o.channel_id,
                 sac.carrier_id
WHERE_CLAUSE
;


    my $sth = $dbh->prepare($qry);
    $sth->execute(@args);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $output{ $row->{outward_airway_bill} } = $row;

        # convert values to local currency
        my $conversion_rate = $conversion_rates->{ $row->{currency_id} };
        $row->{total_value}     = sprintf( "%.2f", ($row->{total_value}     * $conversion_rate) );
        $row->{total_tax}       = sprintf( "%.2f", ($row->{total_tax}       * $conversion_rate) );
        $row->{total_duty}      = sprintf( "%.2f", ($row->{total_duty}      * $conversion_rate) );
        $row->{shipping_charge} = sprintf( "%.2f", ($row->{shipping_charge} * $conversion_rate) );

        $row->{actual_weight}       = $row->{item_weight};
        $row->{volumetric_weight}   = 0;
        $row->{num_pieces}          = 0;
        $row->{sales_channel}       = $channels->{ $row->{channel_id} }{name};
                $row->{carrier_name}        = $carriers->{ $row->{carrier_id} };
        $row->{boxes}               = "";

        ### get shipment box info
        my $sub_qry = "SELECT box, weight, volumetric_weight
                    FROM box WHERE id IN (SELECT box_id FROM shipment_box WHERE shipment_id = ?)";
        my $sub_sth = $dbh->prepare($sub_qry);
        $sub_sth->execute($row->{id});

        while ( my $sub_row = $sub_sth->fetchrow_hashref() ) {
            $row->{num_pieces}++;
            $row->{actual_weight}     += $sub_row->{weight};
            $row->{volumetric_weight} += $sub_row->{volumetric_weight};
            $row->{boxes}             .= $sub_row->{box}." ";
        }
    }

    my $schema = get_schema_using_dbh($dbh, "xtracker_schema");
    for my $waybill ( values %output ) {
        my $shipment_row = $schema->resultset("Public::Shipment")->find(
            $waybill->{id},
        );
        $waybill->{is_saturday_nominated_delivery_date}
            = $shipment_row->is_saturday_nominated_delivery_date();

        ### use the greater out of volumetric and actual weight to calculate tariff
        if ($waybill->{volumetric_weight} > $waybill->{actual_weight}) {
            $waybill->{total_weight} = $waybill->{volumetric_weight};
        }
        else {
            $waybill->{total_weight} = $waybill->{actual_weight};
        }

        ### round up weight to the nearest 0.5
        $waybill->{total_weight} = sprintf( "%.2f", (nhimult(.5, $waybill->{total_weight})) );

        ### use weight & shipping account to get DHL tariff
        # Note that the data quality in dhl_tariff_zone is very poor
        # and is probably useless as it is. Consider removing it
        # altogether. If so, the total_weight can also be removed from
        # this data structure, and probably country.dhl_tariff_zone as
        # well.
        # We can't use undef values as hash keys, so let's ignore this final
        # statement unless dhl_tariff_zone is defined
        $waybill->{tariff}
            = defined $waybill->{dhl_tariff_zone}
            ? $dhl_rates->{ $waybill->{shipping_account_id} }{ $waybill->{dhl_tariff_zone} }{ $waybill->{total_weight} }
            : q{};
    }

    return \%output;
}


### Subroutine : premier_shipments_report                                ###
# usage        : $hash_ptr = premier_shipments_report(                     #
#                       $dbh,                                              #
#                       $start_date,                                       #
#                       $end_date,                                         #
#                       $channel_id,                                       #
#                       $channel_hash_ptr                                  #
#                   );                                                     #
# description  : This produces a report showing the costs for delivery     #
#                of items using premier delivery. A date range can         #
#                be passed in along with a sales channel id to filter      #
#                the report further.                                       #
# parameters   : Database Handle, Start Date, End Date, Sales Channel Id,  #
#                Sales Channel HASH pointer to all Channels with the       #
#                Channel Id as the KEY.                                    #
# returns      : A pointer to a HASH containing the results.               #

sub premier_shipments_report :Export(:ShippingReports) {

    my ($dbh, $start, $end, $channel_id, $channels) = @_;

    # get conversion rates to local currency
    my $conversion_rates    = get_local_conversion_rate_mapping($dbh);

    my %output  = ();
    my @args    = ($start,$end);

    my $channel_qry = "";


    if ($channel_id) {
        $channel_qry    = " AND o.channel_id = ? ";
        push @args,$channel_id;
    }

    my $qry =<<QRY
SELECT  s.id,
        sc.description AS delivery_zone,
        TO_CHAR(ssl.date, 'DD-MM-YYYY') AS date,
        o.order_nr,
        o.currency_id,
        SUM(sa.weight) AS item_weight,
        s.shipping_charge,
        SUM( CASE WHEN si.unit_price = 0 THEN 1 ELSE si.unit_price END ) AS total_unit_price,
        SUM( si.tax ) AS total_tax,
        oa.postcode,
        o.channel_id
FROM    shipment s,
        shipping_charge sc,
        shipment_status_log ssl,
        link_orders__shipment los,
        orders o,
        order_address oa,
        shipment_item si,
        variant v,
        shipping_attribute sa
WHERE   ssl.date BETWEEN ? AND ?
AND     s.shipping_charge_id = sc.id
AND     s.shipment_type_id = $SHIPMENT_TYPE__PREMIER -- Premier deliveries only
AND     s.id = los.shipment_id
AND     los.orders_id = o.id
$channel_qry
AND     s.id = ssl.shipment_id
AND     ssl.shipment_status_id = $SHIPMENT_STATUS__DISPATCHED
AND     s.shipment_address_id = oa.id
AND     s.id = si.shipment_id
AND     si.shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
AND     si.shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCELLED
AND     si.variant_id = v.id
AND     v.product_id = sa.product_id
GROUP BY s.id,
         sc.description,
         ssl.date,
         o.order_nr,
         o.currency_id,
         s.shipping_charge,
         oa.postcode,
         o.channel_id
QRY
;

    my $sth = $dbh->prepare($qry);
    $sth->execute(@args);

    while ( my $row = $sth->fetchrow_hashref() ) {

        $output{ $row->{id} } = $row;

        # convert values to local currency
        $output{ $row->{id} }{total_unit_price} = sprintf( "%.2f", ($output{ $row->{id} }{total_unit_price} * $conversion_rates->{ $row->{currency_id} }) );
        $output{ $row->{id} }{total_tax}        = sprintf( "%.2f", ($output{ $row->{id} }{total_tax} * $conversion_rates->{ $row->{currency_id} }) );
        $output{ $row->{id} }{shipping_charge}  = sprintf( "%.2f", ($output{ $row->{id} }{shipping_charge} * $conversion_rates->{ $row->{currency_id} }) );

        $output{ $row->{id} }{actual_weight}        = $output{ $row->{id} }{item_weight};
        $output{ $row->{id} }{volumetric_weight}    = 0;
        $output{ $row->{id} }{num_pieces}           = 0;
        $output{ $row->{id} }{sales_channel}        = $channels->{ $output{ $row->{id} }{channel_id} }{name};
        $output{ $row->{id} }{boxes}                = "";

        ### get shipment box info
        my $sub_qry = "SELECT box, weight, volumetric_weight
                    FROM box WHERE id IN (SELECT box_id FROM shipment_box WHERE shipment_id = ?)";
        my $sub_sth = $dbh->prepare($sub_qry);
        $sub_sth->execute($row->{id});

        while ( my $sub_row = $sub_sth->fetchrow_hashref() ) {
            $output{ $row->{id} }{num_pieces}++;
            $output{ $row->{id} }{actual_weight}        += $sub_row->{weight};
            $output{ $row->{id} }{volumetric_weight}    += $sub_row->{volumetric_weight};
            $output{ $row->{id} }{boxes}                .= $sub_row->{box}." ";
        }
    }


    ### open csv for exporting report
#    my $output_fh;
#    open ($output_fh,">", config_var('SystemPaths','export_dir')."/premier_report.csv") || warn "Cannot open site input file: $!";
#   print $output_fh "Date,Sales Channel,Order Number,Shipment Number,Zone,Postcode,No. Pieces, Actual Weight, DIM Weight, Total Unit Cost, Total Taxes, Shipping Charge, Boxes\n\n";

#   foreach my $shipment_id ( keys %output ) {
#       print $output_fh "$output{ $shipment_id }{date},$output{ $shipment_id }{sales_channel},$output{ $shipment_id }{order_nr},$shipment_id,$output{ $shipment_id }{delivery_zone},$output{ $shipment_id }{postcode},$output{ $shipment_id }{num_pieces},$output{ $shipment_id }{actual_weight},$output{ $shipment_id }{volumetric_weight},$output{ $shipment_id }{total_unit_price},$output{ $shipment_id }{total_tax},$output{ $shipment_id }{shipping_charge},$output{ $shipment_id }{boxes}\n";
#   }

#    close($output_fh);

    return \%output;
}


### Subroutine : shipment_outer_boxes                               ###
# usage        : $hash_ptr = shipment_outer_boxes(                    #
#                      $dbh,                                          #
#                      $start_date,                                   #
#                      $end_date,                                     #
#                      $channel_id,                                   #
#                      $channel_hash_ptr                              #
#                   );                                                #
# description  : This gets a list of outer boxes used for shipments   #
#                for a given date range. You can also pass in a sales #
#                channel id to further refine the search.             #
# parameters   : Database Handle, Start Date, End Date, Sales Channel #
#                Id, Sales Channel HASH pointer to all Channels with  #
#                the Channel Id as the KEY.                           #
# returns      : A pointer to a HASH containing the results.          #

sub shipment_outer_boxes :Export(:ShippingReports) {

    my ($dbh, $start, $end, $channel_id, $channels) = @_;

    my %output  = ();
    my @args    = ($start,$end);


    my $qry =<<QRY
SELECT  sb.id,
        s.id AS shipment_id,
        s.outward_airway_bill,
        st.type AS shipment_type,
        c.country,
        TO_CHAR(ssl.date, 'DD-MM-YYYY') AS date,
        o.order_nr,
        b.box,
        o.channel_id
FROM    shipment s,
        shipment_type st,
        shipment_status_log ssl,
        link_orders__shipment los,
        orders o,
        order_address oa,
        country c,
        shipment_box sb,
        box b
WHERE   ssl.date BETWEEN ? AND ?
AND     s.shipment_type_id = st.id
AND     s.id = los.shipment_id
AND     los.orders_id = o.id
AND     s.id = ssl.shipment_id
AND     ssl.shipment_status_id = $SHIPMENT_STATUS__DISPATCHED
AND     s.shipment_address_id = oa.id
AND     oa.country = c.country
AND     s.id = sb.shipment_id
AND     sb.box_id = b.id
QRY
;
    if ($channel_id) {
        $qry    .= " AND o.channel_id = ? ";
        push @args,$channel_id;
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute(@args);

    while ( my $row = $sth->fetchrow_hashref() ) {

        $output{ $row->{id} } = $row;
        $output{ $row->{id} }{sales_channel}    = $channels->{ $output{ $row->{id} }{channel_id} }{name};

    }


    ### open csv for exporting report
#    my $output_fh;
#    open ($output_fh,">", config_var('SystemPaths','export_dir')."/box_report.csv") || die "Cannot open export file: $!";
#   print $output_fh "Shipment Number,Sales Channel,Shipment Date,Sender Reference,Receiver Country,Outer Box\n\n";
#
#   foreach my $boxid ( keys %output ) {
#
#       print $output_fh "$output{ $boxid }{outward_airway_bill},$output{ $boxid }{sales_channel},$output{ $boxid }{date},$output{ $boxid }{order_nr},$output{ $boxid }{country},$output{ $boxid }{box}\n";
#   }
#
#    close($output_fh);

    return \%output;
}


### Subroutine : shipment_inner_boxes                               ###
# usage        : $hash_ptr = shipment_inner_boxes(                    #
#                      $dbh,                                          #
#                      $start_date,                                   #
#                      $end_date,                                     #
#                      $channel_id,                                   #
#                      $channel_hash_ptr                              #
#                   );                                                #
# description  : This gets a list of inner boxes used for shipments   #
#                for a given date range. You can also pass in a sales #
#                channel id to further refine the search.             #
# parameters   : Database Handle, Start Date, End Date, Sales Channel #
#                Id, Sales Channel HASH pointer to all Channels with  #
#                the Channel Id as the KEY.                           #
# returns      : A pointer to a HASH containing the results.          #

sub shipment_inner_boxes :Export(:ShippingReports) {

    my ($dbh, $start, $end, $channel_id, $channels) = @_;

    my %output  = ();
    my @args    = ($start,$end);


    my $qry =<<QRY
SELECT  sb.id,
        s.id AS shipment_id,
        s.outward_airway_bill,
        st.type AS shipment_type,
        c.country,
        TO_CHAR(ssl.date, 'DD-MM-YYYY') AS date,
        o.order_nr,
        ib.inner_box AS box,
        o.channel_id
FROM    shipment s,
        shipment_type st,
        shipment_status_log ssl,
        link_orders__shipment los,
        orders o,
        order_address oa,
        country c,
        shipment_box sb,
        inner_box ib
WHERE   ssl.date BETWEEN ? AND ?
AND     s.shipment_type_id = st.id
AND     s.id = los.shipment_id
AND     los.orders_id = o.id
AND     s.id = ssl.shipment_id
AND     ssl.shipment_status_id = $SHIPMENT_STATUS__DISPATCHED
AND     s.shipment_address_id = oa.id
AND     oa.country = c.country
AND     s.id = sb.shipment_id
AND     sb.inner_box_id = ib.id
QRY
;
    if ($channel_id) {
        $qry    .= " AND o.channel_id = ? ";
        push @args,$channel_id;
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute(@args);

    while ( my $row = $sth->fetchrow_hashref() ) {

        $output{ $row->{id} } = $row;
        $output{ $row->{id} }{sales_channel}    = $channels->{ $output{ $row->{id} }{channel_id} }{name};

    }


    ### open csv for exporting report
#    my $output_fh;
#    open ($output_fh,">", config_var('SystemPaths','export_dir')."/box_report.csv") || die "Cannot open export file: $!";
#   print $output_fh "Shipment Number,Sales Channel,Shipment Date,Sender Reference,Receiver Country,Inner Box\n\n";
#
#   foreach my $boxid ( keys %output ) {
#
#       print $output_fh "$output{ $boxid }{outward_airway_bill},$output{ $boxid }{sales_channel},$output{ $boxid }{date},$output{ $boxid }{order_nr},$output{ $boxid }{country},$output{ $boxid }{box}\n";
#   }
#
#    close($output_fh);

    return \%output;
}


### Subroutine : duplicate_paperwork_report                         ###
# usage        : $hash_ptr = duplicate_paperwork_report(              #
#                      $dbh,                                          #
#                      $start_date,                                   #
#                      $end_date,                                     #
#                      $start_time,                                   #
#                      $end_time,                                     #
#                   );                                                #
# description  : This gets a list of duplicate printing of paperwork  #
#                for shipments for a given date & time range.         #
# parameters   : Database Handle, Start Date, End Date, Start Time,   #
#                End Time.                                            #
# returns      : A pointer to a HASH containing the results.          #

sub duplicate_paperwork_report :Export(:ShippingReports) {
    my ($dbh, $start_date, $end_date, $start_time, $end_time)   = @_;

    my $line_qry    = "";
    my $qry         = "";

    my $from_date   = $start_date . " " . $start_time;
    my $to_date     = $end_date . " " . $end_time;

    my %retval;


    $line_qry   =<<SQL
SELECT  *
FROM    shipment_print_log
WHERE   shipment_id = ?
AND     document = 'Return Proforma'
AND     date BETWEEN ? AND ?
ORDER BY date
SQL
;
    my $line_sth    = $dbh->prepare($line_qry);

    $qry    =<<SQL
SELECT  spl.shipment_id,
        o.order_nr,
        o.id,
        o.channel_id,
        c.title,
        c.first_name,
        c.last_name,
        COUNT(*) AS num_printed
FROM    shipment_print_log spl
        JOIN (orders o
                JOIN link_orders__shipment los ON los.orders_id = o.id ) ON los.shipment_id = spl.shipment_id
        JOIN customer c ON c.id = o.customer_id
WHERE   spl.date BETWEEN ? AND ?
AND     spl.document = 'Return Proforma'
GROUP BY 1,2,3,4,5,6,7
HAVING COUNT(*) > 1
SQL
;
    my $sth = $dbh->prepare($qry);
    $sth->execute( $from_date, $to_date );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $retval{ $row->{shipment_id} }  = $row;

        $line_sth->execute( $row->{shipment_id}, $from_date, $to_date );
        while ( my $sub_row = $line_sth->fetchrow_hashref() ) {
            push @{ $retval{ $row->{shipment_id} }{sub_rows} }, $sub_row;
        }
    }

    return \%retval;
}


### Subroutine : _get_outbound_dhl_rates                          ###
# usage        : $hash_ptr = _get_outbound_dhl_rates(               #
#                       $dbh                                        #
#                   );                                              #
# description  : This returns the DHL outbound tariffs.             #
# parameters   : Database Handler.                                  #
# returns      : A pointer to a HASH containing the results with    #
#                the shipping_account_id being the KEY.             #

sub _get_outbound_dhl_rates {

    my ($dbh)   = @_;

    my %rates   = ();

    my $qry = "SELECT tariff_zone, weight, tariff, shipping_account_id FROM dhl_outbound_tariff";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {

        $rates{ $row->{shipping_account_id} }{ $row->{tariff_zone} }{ $row->{weight} } = $row->{tariff};

    }

    return \%rates;
}

1;
