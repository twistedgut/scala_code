package XTracker::Stock::Reservation::Reports;

use strict;
use warnings;

use Data::Dump qw(pp);
use XTracker::Config::Local 'config_var';
use XTracker::Handler;

use XTracker::Constants::FromDB qw( :reservation_status :department );
use XTracker::DBEncode qw( decode_db );
use vars qw($operator_id);

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $operator_id = ($handler->{param_of}{alt_operator_id} // 0 )
        ? $handler->{param_of}{alt_operator_id}
        : $handler->operator_id;

    $handler->{data}{current_operator_id} = $operator_id;


    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    my $uri       = $handler->{data}{uri};
    my @levels    = split( /\//, $uri );

    #### get view type - if present
    my $view_type = $levels[4] ? $levels[4] : "Uploaded";
    my $filter_type = $levels[5] ? $levels[5] : "P";
    my $date_range = $levels[6] ? $levels[6] : "This";

    my $data = {
        section       => 'Reservation',
        subsection    => 'Reports',
        subsubsection => $view_type,
        view_type     => $view_type,
        filter_type   => $filter_type,
        date_range    => $date_range,
        error_msg     => '',
        content       => 'stocktracker/reservation/reports.tt',
    };

    $data->{sidenav} = [
        { 'Summary' =>
            [
                {   title => 'Summary',
                    url   => "/StockControl/Reservation",
                },
            ],
        },
        { 'Overview' =>
            [
                {   title => 'Upload',
                    url   => "/StockControl/Reservation/Overview/Upload",
                },
                {   title => 'Pending',
                    url   => "/StockControl/Reservation/Overview/Pending",
                },
                {   title => 'Waiting List',
                    url   => "/StockControl/Reservation/Overview/Waiting",
                },
            ],
        },
        { 'View' =>
            [
                {   title => 'Live Reservations',
                    url   => "/StockControl/Reservation/Live/P",
                },
                {   title => 'Pending Reservations',
                    url   => "/StockControl/Reservation/Pending/P",
                },
                {   title => 'Waiting Lists',
                    url   => "/StockControl/Reservation/Waiting/P",
                },
            ],
        },
        { 'Filter' =>
            [
                {   title => 'Show All',
                    url   => "/StockControl/Reservation/Reports/$view_type/A",
                },
                {   title => 'Show Personal',
                    url   => "/StockControl/Reservation/Reports/$view_type/P",
                },
            ],
        },
        { 'PreOrder' =>
            [
                 {   title => 'Pending Pre-Orders',
                     url   => "/StockControl/Reservation/PreOrder/PreOrderExported",
                 },
                 {   title => 'Pre-Order List',
                     url   => "/StockControl/Reservation/PreOrder/PreOrderList",
                 },
                 {   title => 'Orders on Hold',
                     url   => "/StockControl/Reservation/PreOrder/PreOrderOnhold",
                 },
            ],
        },
        { 'Search' =>
            [
                {   title => 'Product',
                    url   => "/StockControl/Reservation/Product",
                },
                {   title => 'Customer',
                    url   => "/StockControl/Reservation/Customer",
                },
            ],
        },
        { 'Email' =>
            [
                {   title => 'Customer Notification',
                    url   => "/StockControl/Reservation/Email",
                }
            ],
        },
        { 'Reports' =>
            [
                {   title => 'Uploaded',
                    url   => "/StockControl/Reservation/Reports/Uploaded/P",
                },
                {   title => 'Purchased',
                    url   => "/StockControl/Reservation/Reports/Purchased/P",
                },
            ],
        },
    ];

    ## this weeks start date and last weeks start date
    @{$data}{qw/this_week this_week_end last_week/} = _get_start_dates($dbh);

    @{$data}{qw/start_date end_date/} = @{$data}{qw/this_week this_week_end/};

    if ($date_range eq "Last"){
        @{$data}{qw/start_date end_date/} = @{$data}{qw/last_week this_week/};
    }

    if ($view_type eq "Uploaded") {

        ## populate operator data for PS and FA
        _get_operator_data( $handler );
        $handler->{data}{filter} = $filter_type;

        ### get uploaded list
        @{$data}{qw/uploaded operators customers/} = _get_uploaded($dbh, $data->{start_date}, $data->{end_date}, $filter_type);
      }
    elsif ($view_type eq "Purchased") {
        ## populate operator data for PS and FA
        _get_operator_data( $handler );
        $handler->{data}{filter} = $filter_type;

        ### get uploaded list
        @{$data}{qw/uploaded operators customers/} = _get_purchased($dbh, $data->{start_date}, $data->{end_date}, $filter_type);
    }

    my ($date, $time) = split(/ /, $data->{start_date});
    my ($year, $month, $day) = split(/-/, $date);
    $data->{start_date} = $day."-".$month."-".$year;

    ($date, $time) = split(/ /, $data->{end_date});
    ($year, $month, $day) = split(/-/, $date);
    $data->{end_date} = $day."-".$month."-".$year;

    $handler->{data} = { %{$handler->{data}}, %$data };
    return $handler->process_template;
}

sub _get_start_dates {
    my ($dbh) = @_;

    my $qry = "select extract(dow from current_timestamp)";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $row = $sth->fetchrow_arrayref;

    my $dow = $row->[0];

    my $interval = 7 - (7 - $dow);
    my $interval_end = 7 - $dow;
    my $last_interval = 7 + $interval;

    $qry = "select date_trunc('day', current_timestamp - interval '$interval days'), date_trunc('day', current_timestamp + interval '$interval_end days'), date_trunc('day', current_timestamp - interval '$last_interval days')";
    $sth = $dbh->prepare($qry);
    $sth->execute();

    $row = $sth->fetchrow_arrayref;

    my $this_week_start = $row->[0];
    my $this_week_end = $row->[1];
    my $last_week_start = $row->[2];

    return $this_week_start, $this_week_end, $last_week_start;
}

sub _get_uploaded {
    my ($dbh, $start, $end, $filter_type) = @_;

    my %specials = ();
    my %operators = ();
    my %customers = ();

    my $qry = "
    SELECT r.id,
           r.variant_id,
           r.customer_id,
           to_char(r.date_created, 'DD-MM-YY') AS date_created,
           to_char(r.date_uploaded, 'DD-MM-YY') AS date_uploaded,
           to_char(r.date_expired, 'DD-MM-YY') AS date_expired,
           rs.status,
           op.name AS operator_name,
           v.legacy_sku,
           c.is_customer_number,
           c.first_name,
           c.last_name,
           op.id AS operator_id,
           v.product_id,
           v.size_id
    FROM reservation r,
         reservation_status rs,
         operator op,
         variant v,
         customer c
    WHERE r.date_uploaded > ?
      AND r.date_uploaded < ?
      AND r.status_id = rs.id
      AND r.operator_id = op.id
      AND r.variant_id = v.id
      AND r.customer_id = c.id";

    if ($filter_type eq "P"){
        $qry .= " AND op.id = $operator_id";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute($start, $end);

    ### find customer
    my $subqry = "
    SELECT to_char(o.date, 'DD-MM-YY') AS date, si.unit_price, oa.first_name, oa.last_name, cur.currency
    FROM orders o, link_orders__shipment los, shipment s, shipment_item si, order_address oa, currency cur
    WHERE o.customer_id = ?
      AND o.id = los.orders_id and los.shipment_id = s.id
      AND s.id = si.shipment_id
      AND si.variant_id = ?
      AND o.invoice_address_id = oa.id AND o.currency_id = cur.id
    ";
    my $substh = $dbh->prepare($subqry);

    ### write out CSV file
    my $output_fh;
    open ($output_fh, '>:encoding(utf8)', config_var('SystemPaths','export_dir').'/reservation_Uploaded_report.csv') || warn "Cannot open site input file: $!";
    print $output_fh "Customer No,Customer,SKU,Operator,Status,Created,Uploaded,Expired/Cancelled,Purchased,Currency,Unit Price\n\n";

    while ( my $row = $sth->fetchrow_hashref ) {
            $row->{$_} = decode_db( $row->{$_} ) for (qw(
                first_name
                last_name
            ));
            $operators{$row->{operator_id}} = $row->{operator_name};

            my %specials_row;
            my %customers_row;
            $specials_row{customer_info_id} = $row->{customer_id};
            $specials_row{variant_id} = $row->{variant_id};
            $specials_row{sku} = $row->{product_id}."-".$row->{size_id}." (".$row->{legacy_sku}.")";
            $specials_row{product_id} = $row->{product_id};
            $specials_row{created} = $row->{date_created};
            $specials_row{uploaded} = $row->{date_uploaded};

            $specials_row{expired} = $row->{status} =~ m{^(?:Cancelled|Expired)$}
                                   ? $row->{date_expired}
                                   : q{};
            $specials_row{status} = $row->{status};
            $specials_row{operator} = $row->{operator_name};
            $specials_row{customer_nr} = $row->{is_customer_number};

            $customers_row{customer_nr} = $row->{is_customer_number};

            if ($row->{status} eq "Purchased"){
                $substh->execute($row->{customer_id},$row->{variant_id});

                while ( my $subrow = $substh->fetchrow_hashref ) {
                    $subrow->{$_} = decode_db( $subrow->{$_} ) for (qw(
                        first_name
                        last_name
                    ));
                    $specials_row{purchased} = $subrow->{date};
                    $specials_row{value} = $subrow->{unit_price};
                    $specials_row{name} = $subrow->{first_name}." ".$subrow->{last_name};
                    $specials_row{currency} = $subrow->{currency};

                    $customers_row{name} = $subrow->{first_name}." ".$subrow->{last_name};
                }
            }
            else{
                $specials_row{purchased} = q{};
                $specials_row{value} = q{};
                $specials_row{name} = "$row->{first_name} $row->{last_name}";

                $customers_row{name} = "$row->{first_name} $row->{last_name}";
            }
            my $output_str = join q{,},
                $specials_row{customer_nr} // '',
                $specials_row{name} // '',
                $specials_row{sku} // '',
                $specials_row{operator} // '',
                $specials_row{status} // '',
                $specials_row{created} // '',
                $specials_row{uploaded} // '',
                $specials_row{expired} // '',
                $specials_row{purchased} // '',
                $specials_row{currency} // '',
                $specials_row{value} // '',
            ;
            print $output_fh "$output_str\n";
            $specials{$row->{operator_id}}{$row->{customer_id}}{$row->{id}} = \%specials_row;
            $customers{$row->{customer_id}} = \%customers_row;
    }

    close($output_fh);

    return \%specials, \%operators, \%customers;
}

sub _get_purchased {
    my ($dbh, $start, $end, $filter_type) = @_;

    my %specials = ();
    my %operators = ();
    my %customers = ();

    my $qry = "
    SELECT si.unit_price, o.order_nr, o.customer_id, to_char(o.date, 'DD-MM-YY') as purchased, c.is_customer_number, c.first_name, c.last_name, cur.currency,  r.id as reservation_id, to_char(r.date_created, 'DD-MM-YY') as created, to_char(r.date_uploaded, 'DD-MM-YY') as uploaded, to_char(r.date_expired, 'DD-MM-YY') as expired, op.id as operator_id, op.name as operator_name, v.product_id, v.size_id, v.legacy_sku
    FROM orders o, link_orders__shipment los, shipment_item si, customer c, order_address oa,
    currency cur, reservation r, operator op, variant v
    WHERE si.special_order_flag = true
    AND si.shipment_id = los.shipment_id
    AND los.orders_id = o.id
    AND o.date > ?
    AND o.date < ?
    AND o.customer_id = c.id
    AND o.invoice_address_id = oa.id
    AND o.currency_id = cur.id
    AND o.customer_id = r.customer_id
    AND si.variant_id = r.variant_id
    AND r.status_id = $RESERVATION_STATUS__PURCHASED
    AND r.operator_id = op.id
    AND r.variant_id = v.id
    ";

    if ($filter_type eq "P"){
        $qry .= " AND op.id = $operator_id";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute($start, $end);

    while ( my $row = $sth->fetchrow_hashref ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
        ));

        $operators{$row->{operator_id}} = $row->{operator_name};

        $customers{$row->{customer_id}}{name} = "$row->{first_name} $row->{last_name}";
        $customers{$row->{customer_id}}{customer_nr} = $row->{is_customer_number};

        my $reservation = {
            status           => "Purchased",
            purchased        => $row->{purchased},
            value            => $row->{unit_price},
            name             => "$row->{first_name} $row->{last_name}",
            customer_info_id => $row->{customer_id},
            variant_id       => $row->{variant_id},
            sku              => "$row->{product_id}-$row->{size_id} ($row->{legacy_sku})",
            product_id       => $row->{product_id},
            created          => $row->{created},
            uploaded         => $row->{uploaded},
            operator         => $row->{operator_name},
            customer_nr      => $row->{is_customer_number},
            currency         => $row->{currency},
        };
        $specials{$row->{operator_id}}{$row->{customer_id}}{$row->{reservation_id}} = $reservation;
    }

    ### write out CSV file
    my $output_fh;
    open ($output_fh,'>:encoding(UTF-8)', config_var('SystemPaths','export_dir').'/reservation_Purchased_report.csv') || warn "Cannot open site input file: $!";
    print $output_fh "Customer No,Customer,SKU,Operator,Created,Uploaded,Purchased,Currency,Unit Price\n\n";

    ### output csv file
    foreach my $operator_id ( keys %specials ) {
        foreach my $customer_id ( keys %{ $specials{ $operator_id } } ) {
            foreach my $reservation_id ( keys %{ $specials{ $operator_id }{ $customer_id } } ) {
                my $output_str = join q{,},
                    $specials{ $operator_id }{ $customer_id }{ $reservation_id }{customer_nr},
                    $specials{ $operator_id }{ $customer_id }{ $reservation_id }{name},
                    $specials{ $operator_id }{ $customer_id }{ $reservation_id }{sku},
                    $specials{ $operator_id }{ $customer_id }{ $reservation_id }{operator},
                    $specials{ $operator_id }{ $customer_id }{ $reservation_id }{created},
                    $specials{ $operator_id }{ $customer_id }{ $reservation_id }{uploaded},
                    $specials{ $operator_id }{ $customer_id }{ $reservation_id }{purchased},
                    $specials{ $operator_id }{ $customer_id }{ $reservation_id }{currency},
                    $specials{ $operator_id }{ $customer_id }{ $reservation_id }{value},
                ;
                print $output_fh "$output_str\n";
            }
        }
    }

    close($output_fh);

    return \%specials, \%operators, \%customers;
}

sub _get_operator_data {
    my $handler = shift;

    if( $handler->{data}{department_id} == $DEPARTMENT__PERSONAL_SHOPPING ||
        $handler->{data}{department_id} == $DEPARTMENT__FASHION_ADVISOR ) {

        $handler->{data}{all_operators} = $handler->{schema}->resultset('Public::Operator')
            ->operators_in_departments_for_ui( [
                $DEPARTMENT__PERSONAL_SHOPPING,
                $DEPARTMENT__FASHION_ADVISOR
            ] );

    }

    return;
}

1;
