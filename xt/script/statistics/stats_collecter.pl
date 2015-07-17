#!/opt/xt/xt-perl/bin/perl 

use strict;
use warnings;

use Getopt::Long;
use Perl6::Say;
use Readonly;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Config::Local;
use XTracker::Database              qw( xtracker_schema );
use XTracker::Utilities             qw( current_date reporting_date );
use XTracker::Database::Channel     qw( get_channels );

use XTracker::Statistics::Graph     qw( read_graph_file
                                        write_graph_file );

use XTracker::Statistics::Collector qw( on_credit_hold
                                        on_credit_check
                                        on_preorder_hold
                                        on_ddu_hold
                                        shipment_status
                                        airwaybill_status
                                        dispatch_status
                                        order_total
                                        ranged_order_total
                                        dispatch_total );

Readonly my $PATH_GRAPH  => config_var('Statistics','stats_base_path');

my $group = '';
GetOptions( 'group=s' => \$group );

# database handle
my $dbh = xtracker_schema->storage->dbh;

# run the right stats collection
my %dispatch = ( 'daily'       => \&daily_stats,
                 'order_stats' => \&stats,
               );


$dispatch{$group}->();

###

# tasks to run daily
sub stats {

    my $channels    = get_channels($dbh);

    # get all the config sections for each channel
    my @channel_grps    = map{ $channels->{$_}{config_section}} sort keys %$channels ;
    push @channel_grps,"ALL";       # put ALL on list for totals across all channels

    # daily order count statistics
    write_graph_file( collect_order_count($channels), { y_axis => 'No of Orders' }, $PATH_GRAPH .'daily_count.xml', \@channel_grps );

    # daily value statistics
    write_graph_file( collect_order_value($channels), { y_axis => 'No of Orders'}, $PATH_GRAPH .'daily_value.xml', \@channel_grps );

    # dispatch statistics
    write_graph_file( collect_dispatch($channels), { y_axis => 'No of Orders' }, $PATH_GRAPH .'daily_dispatch.xml', \@channel_grps );

    # weekly orders
    write_graph_file( collect_weekly_orders($channels), { y_axis => 'No of Orders' }, $PATH_GRAPH .'weekly_orders.xml', \@channel_grps );

    # monthly orders
    write_graph_file( collect_monthly_orders($channels), { y_axis => 'No of Orders' }, $PATH_GRAPH .'monthly_orders.xml', \@channel_grps );

    # yearly orders
    write_graph_file( collect_yearly_orders($channels), { y_axis => 'No of Orders' }, $PATH_GRAPH .'yearly_orders.xml', \@channel_grps );

    # order flow statistics
    write_graph_file( collect_order_flow('all',$channels), { y_axis => 'No of Orders' }, $PATH_GRAPH .'order_flow.xml', \@channel_grps );

    # order flow statistics - premier only
    write_graph_file( collect_order_flow('premier',$channels), { y_axis => 'No of Orders' }, $PATH_GRAPH .'order_flow_premier.xml', \@channel_grps );
}


sub collect_weekly_orders {

    my $channels        = shift;

    my $monday_this_week= reporting_date( 'this_monday' );
    my $monday_last_week= reporting_date( 'last_monday' );
    my $today           = current_date();
    my $today_last_week = reporting_date( 'today_last_week' );

    my @days = ( 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' );

    my %ranged_order_count = ();
    $ranged_order_count{'this week'}    = ranged_order_total( $dbh, $monday_this_week, $today, 'day', $channels );
    $ranged_order_count{'last week'}    = ranged_order_total( $dbh, $monday_last_week, $today_last_week, 'day', $channels );


    # label values
    my @data_labels = ();
    push ( @data_labels, @days );
    my @dates       = ();
    my %datasets    = ();

    foreach my $dataset ( sort keys %ranged_order_count ){

        foreach my $date ( sort keys %{ $ranged_order_count{$dataset} } ){

            # add dates
            push @dates, $date;

            # add values
            push @{ $datasets{$dataset} }, $ranged_order_count{$dataset}->{$date};
        }
    }

    # create graph data structure
    return [ \@data_labels, \@dates, \%datasets ];
}

sub collect_monthly_orders {

    my $channels    = shift;

    my $this_month_first_day    = reporting_date( 'first_day_of_month' );
    my $last_year_first_day     = reporting_date( 'first_day_of_month_last_year' );
    my $today                   = current_date();
    my $today_last_year         = reporting_date( 'today_last_year' );

    my %ranged_order_count  = ();
    $ranged_order_count{'this year'}    = ranged_order_total( $dbh, $this_month_first_day, $today, 'day', $channels );
    $ranged_order_count{'last year'}    = ranged_order_total( $dbh, $last_year_first_day, $today_last_year, 'day', $channels );

    # label values
    my @data_labels = ();
    my @dates       = ();
    my %datasets    = ();

    foreach my $dataset ( sort keys %ranged_order_count ){

        foreach my $date ( sort keys %{ $ranged_order_count{$dataset} } ){

            # add dates
            push @dates, $date;

            # add values
            push @{ $datasets{$dataset} }, $ranged_order_count{$dataset}->{$date};
        }
    }

    # create graph data structure
    return [ \@data_labels, \@dates, \%datasets ];
}


sub collect_yearly_orders {

    my $channels        = shift;

    my $this_year_first_day = reporting_date( 'first_day_of_year' );
    my $last_year_first_day = reporting_date( 'first_day_of_last_year' );
    my $today               = current_date();
    my $today_last_year     = reporting_date( 'today_last_year' );

    my %ranged_order_count  = ();
    $ranged_order_count{'this year'}    = ranged_order_total( $dbh, $this_year_first_day, $today, 'day', $channels );
    $ranged_order_count{'last year'}    = ranged_order_total( $dbh, $last_year_first_day, $today_last_year, 'day', $channels );

    # label values
    my @data_labels = ();
    my @dates       = ();
    my %datasets    = ();

    foreach my $dataset ( sort keys %ranged_order_count ){

        foreach my $date ( sort keys %{ $ranged_order_count{$dataset} } ){

            # add dates
            push @dates, $date;

            # add values
            push @{ $datasets{$dataset} }, $ranged_order_count{$dataset}->{$date};
        }
    }
    # create graph data structure
    return [ \@data_labels, \@dates, \%datasets ];
}



sub collect_order_count {

    my $channels    = shift;

    # collect stats for totals

    my $yest        = reporting_date( 'yesterday' );
    my $today       = current_date();
    my $tomorrow    = reporting_date( 'tomorrow' );

    my @currencies = get_currency_list();

    # create totals graph
    # label axis
    my %labels = ( );

    # label values
    my @data_labels = ( 'Orders Today', 'Orders Yest' );

    # add dates
    my @dates       = ( $today, $yest, $today, $yest );

    # add values
    my %dataset     = ();

    foreach my $ccy (@currencies) {
        my ($order_today, $value_today) = order_total( $dbh, $today, $tomorrow, $ccy, $channels );
        my ($order_yest,  $value_yest)  = order_total( $dbh, $yest,  $today,    $ccy, $channels );
        $dataset{$ccy} = [ $order_today, $order_yest ];
    }

    # create graph data structure
    return [ \@data_labels, \@dates, \%dataset ];

}


sub collect_order_value {

    my $channels    = shift;

    # collect stats for totals

    my $yest        = reporting_date( 'yesterday' );
    my $today       = current_date();
    my $tomorrow    = reporting_date( 'tomorrow' );

    my @currencies = get_currency_list();

    # create totals graph
    # label axis
    my %labels = ( );

    # label values
    my @data_labels = ( 'Value Today', 'Value Yest' );

    # add dates
    my @dates       = ( $today, $yest, $today, $yest );

    # add values
    my %dataset     = ();

    foreach my $ccy (@currencies) {
        my ($order_today, $value_today) = order_total( $dbh, $today, $tomorrow, $ccy, $channels );
        my ($order_yest,  $value_yest)  = order_total( $dbh, $yest,  $today,    $ccy, $channels );
        $dataset{$ccy} = [ $value_today, $value_yest ];
    }

    # create graph data structure
    return [ \@data_labels, \@dates, \%dataset ];

}


sub collect_dispatch {

    my $channels    = shift;

    # collect stats for dispatch

    my $yest        = reporting_date('yesterday');
    my $today       = current_date();
    my $tomorrow    = reporting_date('tomorrow');

    my ($dispatch_today)    = dispatch_total( $dbh, $today, $tomorrow, $channels );
    my ($dispatch_yest)     = dispatch_total( $dbh, $yest, $today, $channels );


    # create totals graph
    # label axis
    my %labels = ( );

    # label values
    my @data_labels = ( 'Orders Today', 'Orders Yest' );

    # add dates
    my @dates       = ( $today, $yest, $today, $yest );

    # add values
    my %dataset     = ( total => [ $dispatch_today, $dispatch_yest ], );

    # create graph data structure
    return [ \@data_labels, \@dates, \%dataset ];

}



sub collect_order_flow {

    my $type            = shift;
    my $channels        = shift;

    # collect stats for overview graph
    my $credit_hold     = on_credit_hold( $dbh, $type, $channels );
    my $credit_check    = on_credit_check( $dbh, $type, $channels );
    my $preorder_hold   = on_preorder_hold( $dbh, $type, $channels );
    my $ddu_hold        = on_ddu_hold( $dbh, $type, $channels );
    my $selection       = shipment_status( $dbh, 'selection', $type, $channels );
    my $picking         = shipment_status( $dbh, 'picking', $type, $channels );
    my $packing         = shipment_status( $dbh, 'packing', $type, $channels );
    my $airwaybill      = airwaybill_status( $dbh, $type, $channels );
    my $dispatch        = dispatch_status( $dbh, $type, $channels );

    # label values
    my @data_labels = ( 'Credit Hold', 'Credit Check', 'Pre-Order Hold', 'DDU Hold', 'Selection', 'Picking', 'Packing', 'Airwaybill', 'Dispatch' );

    # add dates
    my @dates       = ( 'point_in_time', 'point_in_time', 'point_in_time', 'point_in_time',
                        'point_in_time', 'point_in_time', 'point_in_time', 'point_in_time', );

    # add values
    my %values      = ( orders => [$credit_hold, $credit_check, $preorder_hold, $ddu_hold, $selection, $picking, $packing, $airwaybill, $dispatch] );

    # create graph data structure
    return  [ \@data_labels, \@dates, \%values ];
}

sub get_currency_list {
    my @currencies = ();
    push(@currencies, config_var('Currency', 'local_currency_code'));

    my $additional_currency = config_var('Currency', 'additional_currency');
    if (ref($additional_currency) eq 'ARRAY') {
        push(@currencies, @$additional_currency);
    } elsif ($additional_currency) {
        push(@currencies, $additional_currency);
    }
    return @currencies;
}

$dbh->disconnect();
