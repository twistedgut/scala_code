package XTracker::Reporting::Distribution::Overview;

use strict;
use warnings;

use DateTime;
use DateTime::Format::Strptime;
use Date::Calc qw( check_date );
use List::Util 'max';

use XTracker::Error qw( xt_warn );
use XTracker::Handler;
use XTracker::Navigation            qw( build_sidenav );
use XTracker::Constants::FromDB     qw(
    :shipment_item_status
    :delivery_action
    :return_item_status
    :shipment_status
);

use XTracker::Database::Channel     qw( get_channels );
use XTracker::Database::Reporting   qw( :Overview :Shipment :Inbound :Returns );

# There are no constants for shipment_box_log__action
use Readonly;
Readonly my $SHIPMENT_BOX_LOG__ACTION => 'Labelled';

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my @levels      = split /\//, $handler->{data}{uri};

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    $handler->{data}{channels}      = get_channels($dbh);
    $handler->{data}{section}       = 'Reporting';
    $handler->{data}{subsection}    = 'Distribution Reports';
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'distribution_reports' } );
    my $date_error_message = "You have entered an invalid date, check format (YYYY-MM-DD) and re-enter.";
    # This is actually the 'subsubsection' but that's too much typing...
    my $section = $levels[3];
    # If we don't have levels[3] we display an overview page, so return asap
    unless ( $section ) {
        $handler->{data}{subsubsection} = 'Overview';
        $handler->{data}{content}       = 'reporting/distribution/overview.tt';

        my $params = get_overview_params( $handler );

        # Print search results output to screen if there is no date_error flag,
        # otherwise display error message to user
        if ( !$params->{date_error} ) {

            my $shipment_box_log_rs = $schema->resultset('Public::ShipmentBoxLog')
                ->search({ "date_trunc('day', timestamp)" => $params->{date} });

            $shipment_box_log_rs = $shipment_box_log_rs
                ->filter_by_customer_channel($params->{channel_id})
                    if ($params->{channel_id});

            # get total number of labelled boxes
            $handler->{data}{labelling_data_count} = $shipment_box_log_rs->count
                if ($params->{type} eq 'Shipments');

            # get total number of items in all boxes
            if ($params->{type} eq 'Items') {
                my @all_skus = $shipment_box_log_rs->get_column('skus')->all;
                map {$handler->{data}{labelling_data_count} += scalar @$_} @all_skus;
            }

            $handler->{data}{outbound_data} = get_outbound_overview(
                $dbh, $params->{date}, $params->{type}, $params->{channel_id}
            );
            $handler->{data}{inbound_data}  = get_inbound_overview(
                $dbh, $params->{date}, $params->{channel_id}
            );
            $handler->{data}{scale_by} = get_scale_by( "overview", {
                outbound => $handler->{data}{outbound_data},
                inbound => $handler->{data}{inbound_data},
            });
        }
        else {
            xt_warn( $date_error_message );
        }

        return $handler->process_template;
    }

    # Configuration for each type of report which can be run
    my %section_map = _get_section_map($schema);
    # Redirect with an error message if we don't know what to do with the
    # section
    unless ( $section_map{$section} ) {
        xt_warn( "Unrecognised section '$_'" );
        return $handler->redirect_to('/Reporting/DistributionReports');
    }

    my $report_type_id  = 0;

    $handler->{data}{subsubsection} = $section_map{$section}{title};
    $handler->{data}{content}       = $section_map{$section}{content};
    $handler->{data}{url_level}     = $section;

    # are there sub-types for the report
    if ( $section_map{$section}{type_map} ) {
        my $report_type = $handler->{param_of}{report_type};
        $handler->{data}{form}{rep_type}    = $report_type;

        $handler->{data}{subsubsection} .= $section_map{$section}{type_map}{$report_type}{suffix};
        $report_type_id                  = $section_map{$section}{type_map}{$report_type}{rep_type_id};
    }

    $handler->{data}{search_option} = $section_map{$section}{search_option} || {};

    my $params = get_section_params($handler, $section);

    # If one of the dates is invalid, display error message to user
    if ( $params->{date_error} ) {
        xt_warn( $date_error_message );
        return $handler->process_template;
    }

    if ( $params->{date_order_error} ) {
        xt_warn( "You have entered a 'From' date that is later than the 'To' date, please check and re-enter." );
        return $handler->process_template;
    }
    # Display start/end search criteria to user
    @{$handler->{data}{search_params}}{@$_} = @{$params}{@$_}
        for [qw/start end/];

    my %args = (
        dbh => $dbh,
        map { $_ => $params->{$_} } qw[start end grouping channel_id]
    );

    my $action_map = $section_map{$section};
    $handler->{data}{results}
        = $section eq 'ShipmentReport'  ? $action_map->{sub}({%args, status => $params->{status},
                                                              shipment_type => $params->{shipment_type}})
        : $section eq 'LabellingReport' ? $action_map->{sub}({%args, shipment_type => $params->{shipment_type},
                                                              by_operator => $params->{display} eq 'operator'})
        : $section eq 'Outbound'        ? $action_map->{sub}({
            %args,
            shipment_item_status_id => $report_type_id,
            by_operator             => $params->{display} eq 'operator',
            shipment_type           => $params->{shipment_type},
        })
        : $action_map->{$params->{display}}({%args, report_type_id => $report_type_id});

     $handler->{data}{scale_by} = get_scale_by(
        $section,
        $handler->{data}{results},
        $params->{grouping},
    );

    return $handler->process_template;
}

### Subroutine : _get_form_params                                     ###
# usage        : $hash_ptr = _get_form_params(                          #
#                          $handler,                                    #
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

sub get_overview_params {
    my ( $handler ) = @_;

    my %params;
    # The user has submitted parameters
    if ( keys %{$handler->{param_of}} ) {
        $handler->{data}{form}{$_} = $params{$_} = $handler->{param_of}{$_}
            for qw{date channel_id type};
        #check validity of date, set error flag in params to 1 if invalid
        my $date_checked = $params{date};
        $params{date_error} = 1 unless (
            $date_checked =~ m/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ &&
            check_date(split /-/, $date_checked ) );
        return \%params;
    }

    # Default params
    my $today = DateTime->now( time_zone => "local" );

    $handler->{data}{form}{$_} = $params{$_} = $today->ymd for 'date';
    $handler->{data}{form}{$_} = $params{$_} = 'Items' for 'type';

    return \%params;
}

sub get_section_params {
    my ( $handler, $section ) = @_;

    my %params;

    # TODO: Set tz to something better when we sort out our timezone mess
    my $tz = 'local';

    # get the parameters passed - ignore report type as we want to use defaults
    # when we have just that field
    if ( grep { 'report_type' ne $_ } keys %{$handler->{param_of}} ) {
        $handler->{data}{form}{$_} = $params{$_} = $handler->{param_of}{$_}
            for glob('{start,end}_{date,hour,minute}'),
                qw{channel_id grouping display status shipment_type};

        my $fmt = DateTime::Format::Strptime->new(
            pattern => '%Y-%m-%d %H:%M',
            time_zone => $tz,
        );

        # check validity of start_date and end_date, set error flag in params to
        # 1 if invalid
        my @checked_dates;
        push @checked_dates, $params{$_} for qw(start_date end_date);
        for my $date ( @checked_dates ) {
            unless ( $date =~ m/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ && check_date(split /-/, $date ) ) {
                $params{date_error} = 1;
                return \%params;
            }
        }
        @params{qw/start end/} = map {
            $fmt->parse_datetime($_) || die "Could not parse datetime $_\n";
        } map {
            sprintf '%s %02i:%02i', @{$_}[0..2]
        } [ @params{qw/start_date start_hour start_minute/} ],
          [ @params{qw/end_date end_hour end_minute/} ];
        # compare start and end DateTime objects. If start is later than end, set
        # date_order_error flag in params to 1
        $params{date_order_error} = 1 if DateTime->compare( $params{start}, $params{end} ) == 1;

        return \%params;
    }

    # Default params
    my $today    = DateTime->now( time_zone => $tz );
    my $tomorrow = $today->clone->add( days => 1 );

    @params{qw/start end/} = ( $today, $tomorrow );

    $handler->{data}{form}{$_} = $params{$_} = $today->strftime('%F')
        for 'start_date';
    $handler->{data}{form}{$_} = $params{$_} = $tomorrow->strftime('%F')
        for 'end_date';
    $handler->{data}{form}{$_} = $params{$_} = "hour" for 'grouping';

    if ($section eq "ShipmentReport") {
        $handler->{data}{form}{$_} = $params{$_} = $SHIPMENT_STATUS__PROCESSING
            for 'status';
    } else {
        $handler->{data}{form}{$_} = $params{$_} = "total" for 'display';
    }

    return \%params;
}

# Returns a value to scale the bar charts on the webpage
sub get_scale_by {
    my ( $type, $list, $group )   = @_;

    return 0 unless $list;

    my ($max_width, $max_total);

    if ( $type ne "overview" ) {
        $max_width = 500;
        $max_total = max( map {
            my $item = $_;
            map { $item->{$_} // 0 } qw/total total_items total_shipments total_labelled_boxes/
        } @$list);
    }
    # Should probably do the status filtering in the sql, not here...
    else {
        $max_width = 600;
        $max_total = max(
            grep { defined }
            (@{$list->{inbound}{goodsin}}{
                $DELIVERY_ACTION__CREATE,
                $DELIVERY_ACTION__COUNT,
                $DELIVERY_ACTION__CHECK,
                $DELIVERY_ACTION__BAG_AND_TAG,
                $DELIVERY_ACTION__PUTAWAY_PREP,
                $DELIVERY_ACTION__PUTAWAY,
            }),
            (@{$list->{inbound}{returns}}{
                $RETURN_ITEM_STATUS__BOOKED_IN,
                $RETURN_ITEM_STATUS__PASSED_QC,
                $RETURN_ITEM_STATUS__PUTAWAY_PREP,
                $RETURN_ITEM_STATUS__PUT_AWAY,
            }),
            (@{$list->{outbound}}{
                $SHIPMENT_ITEM_STATUS__NEW,
                $SHIPMENT_ITEM_STATUS__SELECTED,
                $SHIPMENT_ITEM_STATUS__PICKED,
                $SHIPMENT_ITEM_STATUS__PACKED,
                $SHIPMENT_ITEM_STATUS__DISPATCHED,
            }),
        );
    }
    # We have no totals so we don't want to draw bar charts
    return 0 unless $max_total;

    return $max_total <= $max_width ? 1 : $max_width / $max_total;
}

sub _get_section_map {
    my ( $schema ) = shift;
    return (
        'ShipmentReport'=> {
            title       => 'Shipment Report',
            content     => 'reporting/distribution/shipmentreport.tt',
            search_option => {
                allow_multiple_channels => 1,
                allow_shipment_type => 1,
            },
            sub => sub {
                my $rs = $schema->resultset('Public::ShipmentStatusLog')
                    ->filter_for_report(@_);
                $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
                my @rows = $rs->all;
                $_->{start} = XTracker::Database::Reporting::_format_time(
                    $_[0]{grouping}, $_->{start}
                ) for @rows;
                return \@rows;
            },
        },
        'LabellingReport'=> {
            title       => 'Labelling Report',
            content     => 'reporting/distribution/labelling_report.tt',
            search_option => {
                allow_multiple_channels => 1,
                allow_shipment_type     => 1,
            },
            sub         => sub {
                my $rs = $schema->resultset('Public::ShipmentBoxLog')
                    ->search({ action => $SHIPMENT_BOX_LOG__ACTION })
                    ->filter_for_report(@_);
                $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
                my @rows = $rs->all;
                $_->{start} = XTracker::Database::Reporting::_format_time(
                    $_[0]{grouping}, $_->{start}
                ) for @rows;
                return \@rows;
            },
        },
        'Outbound'      => {
            title       => 'Outbound',
            content     => 'reporting/distribution/report_view.tt',
            # These search options will require additional work to get working
            # for other pages that share the templates, so we need to add some
            # flags to enable them here only
            search_option => {
                allow_multiple_channels => 1,
                allow_shipment_type     => 1,
            },
            sub         => sub {
                # Pass hashrefs so we can use the same display logic as the
                # other non-DBIC results in our view
                my $rs = $schema->resultset('Public::ShipmentItemStatusLog')
                    ->filter_for_report(@_);
                $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
                my @rows = $rs->all;
                # This sub shouldn't really live in the model :(
                $_->{start} = XTracker::Database::Reporting::_format_time(
                    $_[0]{grouping}, $_->{start}
                ) for @rows;
                return \@rows;
            },
            type_map    => {
                'Picking'   => {
                    suffix      => ' - Picking',
                    rep_type_id => $SHIPMENT_ITEM_STATUS__PICKED,
                },
                'Packing'   => {
                    suffix      => ' - Packing',
                    rep_type_id => $SHIPMENT_ITEM_STATUS__PACKED,
                },
            },
        },
        'Inbound'       => {
            title       => 'Inbound',
            content     => 'reporting/distribution/report_view.tt',
            search_option => {
                allow_multiple_channels => 1,
            },
            total       => sub { inbound_summary_list(@_) },
            operator    => sub { inbound_operator_list(@_) },
            type_map    => {
                'stock_in'    => {
                    suffix      => ' - Stock In',
                    rep_type_id => $DELIVERY_ACTION__CREATE,
                },
                'item_count'    => {
                    suffix      => ' - Item Count',
                    rep_type_id => $DELIVERY_ACTION__COUNT,
                },
                'QC'    => {
                    suffix      => ' - QC',
                    rep_type_id => $DELIVERY_ACTION__CHECK,
                },
                'Bag_Tag'=> {
                    suffix      => ' - Bag &amp; Tag',
                    rep_type_id => $DELIVERY_ACTION__BAG_AND_TAG,
                },
                'Putaway_Prep'=> {
                    suffix      => ' - Putaway Prep',
                    rep_type_id => $DELIVERY_ACTION__PUTAWAY_PREP,
                },
                'Putaway'=> {
                    suffix      => ' - Putaway',
                    rep_type_id => $DELIVERY_ACTION__PUTAWAY,
                },
            },
        },
        'Returns'       => {
            title       => 'Returns',
            content     => 'reporting/distribution/report_view.tt',
            search_option => {
                allow_multiple_channels => 1,
            },
            total       => sub { returns_summary_list(@_) },
            operator    => sub { returns_operator_list(@_) },
            type_map    => {
                'Booked_In' => {
                    suffix      => ' - Booked In',
                    rep_type_id => [ $RETURN_ITEM_STATUS__BOOKED_IN ],
                },
                'QC'    => {
                    suffix      => ' - QC',
                    rep_type_id => [ $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION,$RETURN_ITEM_STATUS__PASSED_QC ],
                },
                'Putaway_Prep'=> {
                    suffix      => ' - Putaway Prep',
                    rep_type_id => [ $RETURN_ITEM_STATUS__PUTAWAY_PREP ],
                },
                'Putaway'=> {
                    suffix      => ' - Putaway',
                    rep_type_id => [ $RETURN_ITEM_STATUS__PUT_AWAY ],
                },
            },
        },
    );
}

1;
