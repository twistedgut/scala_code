package XTracker::Reporting::Shipping::Overview;

use strict;
use warnings;
use DateTime;
use DateTime::Duration;

use XTracker::Handler;
use XTracker::Navigation            qw( build_sidenav );
use XTracker::Database::Address     qw( get_country_list );
use XTracker::Database::Channel     qw( get_channels );
use XTracker::Database::Reporting   qw( :ShippingReports );
use XTracker::Utilities         qw( isdates_ok );
use XTracker::Config::Local;
use XTracker::Database                  qw( get_schema_using_dbh );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my @levels      = split /\//, $handler->{data}{uri};


    # Configuration for each type of report which can be run
    my %subsubsect_map  = (
            'AirwaybillReport'  => {
                        title       => 'Air Waybill Report',
                        content     => 'reporting/shipping/airwaybillreport.tt',
                        csv_filename=> 'outbound_airwaybill.csv',
                        use_cookie  => 0,
                },
            'PremierReport'     => {
                        title       => 'Premier Report',
                        content     => 'reporting/shipping/premierreport.tt',
                        csv_filename=> 'premier_report.csv',
                        use_cookie  => 0,
                },
            'BoxReport'     => {
                        title       => 'Box Report',
                        content     => 'reporting/shipping/boxreport.tt',
                        csv_filename=> 'box_report.csv',
                        use_cookie  => 0,
                },
            'DuplicatePaperwork'    => {
                        title       => 'Duplicate Paperwork',
                        content     => 'reporting/shipping/duplicate_paperwork.tt',
                        use_cookie  => 1,
                },
        );


    $handler->{data}{cookie_name}   = 'shipping_reports';
    $handler->{data}{channels}      = get_channels($handler->{dbh});
    $handler->{data}{section}       = 'Reporting';
    $handler->{data}{subsection}    = 'Shipping Reports';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'reporting/shipping/overview.tt';
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'shipping_reports' } );
    $handler->{data}{use_cookie}    = 0;

    if ( !exists $handler->{param_of}{submit} ) {
        # check to see if there is a cookie to automatically pick the report type & params
        _check_for_cookie($handler,\@levels);
    }

    # default to AirwaybillReport if none specified
    $levels[3]      = "AirwaybillReport"        if (!$levels[3]);

    # does the report exist in the configuration
    if ( exists($subsubsect_map{$levels[3]}) ) {

        $handler->{data}{subsubsection} = $subsubsect_map{$levels[3]}{title};
        $handler->{data}{content}       = $subsubsect_map{$levels[3]}{content};
        $handler->{data}{url_level}     = $levels[3];
        $handler->{data}{use_cookie}    = $subsubsect_map{$levels[3]}{use_cookie};

        if ($levels[3] eq "AirwaybillReport") {

                        my $schema = get_schema_using_dbh($handler->{dbh},'xtracker_schema');
            my $shipping_options_rs;
            my $carriers;

            if(config_var('DistributionCentre','ups_city')){
                $shipping_options_rs = $schema->resultset('Public::Carrier')->search(
                    { -or => [ { name => { like => 'UPS%' } }, { name => {like => '%Express'} }] }
                );
            }
            else {
                $shipping_options_rs = $schema->resultset('Public::Carrier')->search(
                    { name => { like => 'DHL%' } }
                );
            }

            while (my $shipping_option = $shipping_options_rs->next){
                 $carriers->{$shipping_option->id} = $shipping_option->name;
            }

            $handler->{data}{carriers}      = $carriers;

            $handler->{data}{countries} = get_country_list($handler->{dbh});
        }

    }

    my $params  = _get_form_params($handler,$handler->{data}{use_cookie},@levels);

    if ( !exists($params->{date_error}) && !exists($params->{no_params}) ) {
        CASE: {
            if ($levels[3] eq "AirwaybillReport") {

                                $handler->{data}{results}   = outbound_airwaybill_report( $handler->{dbh}, $params->{country}, $params->{from_date}, $params->{to_date}, $params->{channel_id}, $handler->{data}{channels}, $params->{carrier_id}, $handler->{data}{carriers} );

                                last CASE;
            }
            if ($levels[3] eq "PremierReport") {

                $handler->{data}{results}   = premier_shipments_report( $handler->{dbh}, $params->{from_date}, $params->{to_date}, $params->{channel_id}, $handler->{data}{channels} );

                last CASE;
            }
            if ($levels[3] eq "BoxReport") {

                my @args    = ( $handler->{dbh}, $params->{from_date}, $params->{to_date}, $params->{channel_id}, $handler->{data}{channels} );

                $handler->{data}{results}   = ( $params->{box_type} eq "Inner"
                                                ? shipment_inner_boxes( @args )
                                                : shipment_outer_boxes( @args ) );

                last CASE;
            }
            if ($levels[3] eq "DuplicatePaperwork") {

                $handler->{data}{results}   = duplicate_paperwork_report( $handler->{dbh}, $params->{from_date}, $params->{to_date}, $params->{from_time}, $params->{to_time} );

                last CASE;
            }
        };
    }
    else {
        $handler->{data}{error_msg}     = "Invalid Date Passed!"        if (exists($params->{date_error}));
    }

    # if the user wants to export the results to a CSV file
    if ( $params->{csv_export} && scalar(keys %{$handler->{data}{results}}) ) {
        $handler->{data}{template_type} = "csv";
        $handler->{r}->headers_out->set( 'Content-Disposition' => q{inline; filename="}.$subsubsect_map{$levels[3]}{csv_filename} . q{"} );
    }

    return $handler->process_template( undef );
}


### Subroutine : _get_form_params                                     ###
# usage        : $hash_ptr = _get_form_params(                          #
#                          $handler,                                    #
#                          $use_cookie_flag,                            #
#                          @url_path_levels                             #
#                     );                                                #
# description  : This gets the paramters from the Filter Section of the #
#                pages and puts them into a new hash and also populates #
#                the {data}{form} hash in the Handler so that they can  #
#                be re-displayed in the form. Also sets defaults if no  #
#                params were passed.                                    #
# parameters   : Pointer to the Handler, Array containing the sections  #
#                of the URL (delimited by '/').                         #
# returns      : A HASH Pointer to the Parameters.                      #

sub _get_form_params {
    my ($handler, $use_cookie, @url_levels)  = @_;

    my %params;
    my @chkdates;


    # get the parameters passed
    if ( scalar keys(%{$handler->{param_of}}) ) {
        if ($url_levels[3]) {
            $params{from_date}  = $handler->{param_of}{fromyear}."-".$handler->{param_of}{frommonth}."-".$handler->{param_of}{fromday};
            $params{to_date}    = $handler->{param_of}{toyear}."-".$handler->{param_of}{tomonth}."-".$handler->{param_of}{today};
            $params{channel_id} = $handler->{param_of}{channel_id}  if ($handler->{param_of}{channel_id});
                        $params{carrier_id} = $handler->{param_of}{carrier_id}  if ($handler->{param_of}{carrier_id});
            $params{country}    = $handler->{param_of}{country}     if ($handler->{param_of}{country});
            $params{box_type}   = $handler->{param_of}{box_type}    if ($handler->{param_of}{box_type});

            $handler->{data}{form}{fromyear}    = $handler->{param_of}{fromyear};
            $handler->{data}{form}{frommonth}   = $handler->{param_of}{frommonth};
            $handler->{data}{form}{fromday}     = $handler->{param_of}{fromday};
            $handler->{data}{form}{toyear}      = $handler->{param_of}{toyear};
            $handler->{data}{form}{tomonth}     = $handler->{param_of}{tomonth};
            $handler->{data}{form}{today}       = $handler->{param_of}{today};
            $handler->{data}{form}{channel_id}  = $handler->{param_of}{channel_id}              if ($handler->{param_of}{channel_id});
            $handler->{data}{form}{country}     = $handler->{param_of}{country}                 if ($handler->{param_of}{country});
            $handler->{data}{form}{box_type}    = $handler->{param_of}{box_type}                if ($handler->{param_of}{box_type});
            $handler->{data}{form}{carrier_id}      = $handler->{param_of}{carrier_id}              if ($handler->{param_of}{carrier_id});

            if ($url_levels[3] eq "DuplicatePaperwork") {
                $params{from_time}  = sprintf("%0.2d:%0.2d",$handler->{param_of}{fromhour},$handler->{param_of}{frommins});
                $params{to_time}    = sprintf("%0.2d:%0.2d",$handler->{param_of}{tohour},$handler->{param_of}{tomins});

                $handler->{data}{form}{fromhour}    = $handler->{param_of}{fromhour};
                $handler->{data}{form}{frommins}    = $handler->{param_of}{frommins};
                $handler->{data}{form}{tohour}      = $handler->{param_of}{tohour};
                $handler->{data}{form}{tomins}      = $handler->{param_of}{tomins};
            }

            if ($handler->{param_of}{csv_export}) {
                $handler->{data}{form}{csv_export}  = 1;
                $params{csv_export}                 = 1;
            }

            $handler->{data}{form}{submitted}   = 1;

            push @chkdates,($params{from_date},$params{to_date});
        }

        if ( !isdates_ok(@chkdates) ) {
            $params{date_error}     = 1;
            delete $handler->{data}{form}{submitted};
            delete $params{csv_export}      if ( exists($params{csv_export}) );
        }
    }
    # Defaults
    else {
        if ($url_levels[3]) {
            my $today       = DateTime->now( time_zone => "local" );
            my $tommorow    = $today + DateTime::Duration->new( days => 1 );

            $params{from_date}  = $today->ymd;
            $params{to_date}    = $tommorow->ymd;

            $handler->{data}{form}{fromday}     = $today->day;
            $handler->{data}{form}{frommonth}   = $today->month;
            $handler->{data}{form}{fromyear}    = $today->year;
            $handler->{data}{form}{today}       = $tommorow->day;
            $handler->{data}{form}{tomonth}     = $tommorow->month;
            $handler->{data}{form}{toyear}      = $tommorow->year;

            $params{channel_id} = 0;

            if ($url_levels[3] eq "AirwaybillReport") {
                $params{country}                = "All";
                $handler->{data}{form}{country} = "";
                                $params{carrier_id} = 0;
            }
            if ($url_levels[3] eq "BoxReport") {
                $params{box_type}               = "Inner";
                $handler->{data}{form}{box_type}= "Inner";
            }
        }

        $params{no_params}  = 1;
    }

    if ( $use_cookie ) {
        my $qry_str = 'auto_rep_section='.$url_levels[3] . '&';

        $qry_str    .= join('&', map { $_ . '=' . $handler->{data}{form}{$_} } keys %{ $handler->{data}{form} } );
        $handler->get_cookies('Search')
            ->create_search_cookie($handler->{data}{cookie_name}, $qry_str);
    }

    return \%params;
}


### Subroutine : _check_for_cookie                                      ###
# usage        : $scalar = _check_for_cookie(                             #
#                          $handler,                                      #
#                          $url_levels_ptr                                #
#                     );                                                  #
# description  : This checks to see if a search cookie exists that this   #
#                module should use. If it does then it poulates the       #
#                url levels array idx 3 if it has not already been set    #
#                to the report section so it can automatically pick the   #
#                correct report later on and populates the 'param_of'     #
#                hash in the handler with the contents of the cookie.     #
# parameters   : Pointer to the Handler, Pointer to the URL Levels Array. #
# returns      : A SCALAR representing the report to switch to.           #

sub _check_for_cookie {
    my $handler     = shift;
    my $url_levels  = shift;

    my $rep_section = "";
    my $params = $handler->get_cookies('Search')->get_search_cookie("shipping_reports");

    if ( $params ) {
        my $auto_report         = delete( $params->{auto_rep_section} );
        $url_levels->[3]        = $auto_report      if ( !$url_levels->[3] );
        $handler->{param_of}    = { %{$handler->{param_of}} , %{$params} };
        $handler->get_cookies('Search')->expire_cookie($handler->{data}{cookie_name});
    }

    return $rep_section;
}


1;
