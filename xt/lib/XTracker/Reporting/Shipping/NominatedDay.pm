package XTracker::Reporting::Shipping::NominatedDay;

use strict;
use warnings;

use List::MoreUtils qw/ first_value /;

use XTracker::Handler;
use XTracker::Navigation qw( build_sidenav );
use XTracker::Database qw/get_schema_using_dbh/;
use XTracker::Database::Channel qw( get_channels );
use XTracker::Database::Reporting qw( :ShippingReports );
use XTracker::Config::Local qw( config_var );
use XT::Net::XTrackerAPI::Request::NominatedDay;

use XT::Data::DateStamp;
use XTracker::Config::Local qw( config_var );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    # Configuration for each type of report which can be run
    $handler->{data}{cookie_name} = 'shipping_reports';
    $handler->{data}{channels} = get_channels($handler->{dbh});
    $handler->{data}{section} = 'Reporting';
    $handler->{data}{subsection} = 'Shipping Reports';
    $handler->{data}{subsubsection} = 'Nominated Day';
    $handler->{data}{content} = 'reporting/shipping/nominated_day.tt';
    $handler->{data}{sidenav} = build_sidenav( { navtype => 'shipping_reports' } );
    $handler->{data}{use_cookie} = 0;

    my $report_durations = $handler->{data}{report}{durations} = [
        { key => "1week"   , moniker => "1 Week"   , day_count =>      7 },
        { key => "1month"  , moniker => "1 Month"  , day_count =>     30 },
        { key => "3months" , moniker => "3 Months" , day_count => 3 * 30 },
        { key => "12months", moniker => "12 Months", day_count =>    365 },
    ];
    my $report_duration_param = $handler->{param_of}->{report_duration} || "";
    my $report_duration = first_value(
        sub { $_->{key} eq $report_duration_param },
        @$report_durations,
    ) || $report_durations->[0];
    $handler->{data}{report}{duration} = $report_duration;

    my $schema = get_schema_using_dbh($handler->{dbh},'xtracker_schema');

    my $report_day_count = $report_duration->{day_count};
    my $query_day_count = config_var(
        "NominatedDay",
        "view_number_of_days_into_future",
    );
    my $daily_shipment_cap = config_var(
        "NominatedDay",
        "max_daily_shipment_count",
    );
    $handler->{data}{dates} = $schema->resultset('Public::Shipment')
        ->nominated_day_shipments_summary({
            query_day_count    => $query_day_count,
            report_day_count   => $report_duration->{day_count},
            daily_shipment_cap => $daily_shipment_cap,
        });

    # cap levels when to use which colour progress bar
    $handler->{data}{cap_levels} = calculate_cap_levels();


    my $shipping_charges = $schema->resultset('Public::ShippingCharge')
            ->get_all_nominated_day_id_description();

    my $today    = XT::Data::DateStamp->today();
    my $last_day = $today->clone->add(days => $report_day_count - 1); # inclusive
    $handler->{data}{restricted_dates} = {
        begin_date       => $today,
        end_date         => $last_day,
        shipping_charges => $shipping_charges,
    };

    return $handler->process_template( undef );
}

sub calculate_cap_levels {
    my $cap = config_var('NominatedDay','max_daily_shipment_count');
    my $one_percent_of_cap = $cap / 100;

    return {
        green => 0,
        orange => int($one_percent_of_cap * 70),
        red => int($one_percent_of_cap * 90)
    };
}

1;
