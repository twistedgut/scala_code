package XTracker::Stock::RTV::InspectRTV;

use strict;
use warnings;
use Carp;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Constants::FromDB         qw( :stock_process_type :stock_process_status :rtv_action );
use XTracker::Handler;
use XTracker::Database::Logging         qw( :rtv log_stock );
use XTracker::Database::RTV             qw( :rtv_stock :rtv_inspection :rtv_document update_fields get_parent_id create_rtv_stock_process );
use XTracker::Database::Product         qw( get_product_summary );
use XTracker::Utilities                 qw( :edit );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}           = 'RTV';
    $handler->{data}{subsection}        = 'Inspection Request';
    $handler->{data}{subsubsection}     = 'Goods In';
    $handler->{data}{content}           = 'rtv/inspect_rtv.tt';
    $handler->{data}{tt_process_block}  = 'rtv_inspection';
    $handler->{data}{rtv_designers}     = [
        map { +{ designer_id => $_->id, designer => $_->designer } }
        $handler->schema
                ->resultset('Public::Designer')
                ->search(undef, { order_by => 'designer' })
    ];

    # list filters
    $handler->{data}{display_list}  = $handler->{param_of}{display_list}  // 'inspection';
    $handler->{data}{select_origin} = $handler->{param_of}{select_origin} // 'GI';
    $handler->{data}{product_id}    = $handler->{param_of}{product_id}    // '';
    $handler->{data}{channel_id}    = $handler->{param_of}{channel_id}    // '';
    $handler->{data}{sales_channel} = $handler->{param_of}{sales_channel} // '';
    $handler->{data}{display_workstation_drilldown} = $handler->{param_of}{display_workstation_drilldown} // 0;

    # use drilled down to inspection pick level
    if ( $handler->{param_of}{submit_workstation_drilldown} ) {
        $handler->{data}{display_workstation_drilldown}  = 1;
        $handler->{data}{display_list}                   = 0;
    }

    # display inspection/workstation list as appropriate
    if ( $handler->{data}{display_list} ) {

        my $type;
        my $id;

        if ($handler->{data}{display_list} eq 'workstation') {
            $handler->{data}{tt_process_block}    = 'rtv_workstation';
        }

        # check if we need to get the search params from a search cookie
        if ( exists($handler->{param_of}{cookie_search}) ) {
            # read the search cookie if it exists
            my $cookie_search = $handler->get_cookies('Search')
                ->get_search_cookie($handler->{data}{tt_process_block});

            # are there any params in the cookie
            if ( defined $cookie_search ) {
                # merge the params from the cookie into the 'param_of' HASH as if they have just been submitted
                $handler->{param_of}    = { %{$handler->{param_of}} , %{$cookie_search} };
            }
        }

        $handler->{data}{select_designer_id}  = defined $handler->{param_of}{select_designer_id}   ? $handler->{param_of}{select_designer_id}   : '';
        $handler->{data}{select_product_id}   = defined $handler->{param_of}{select_product_id}    ? $handler->{param_of}{select_product_id}    : '';

        if ( $handler->{data}{select_product_id} =~ m{\A\d+\z}xms ) {
            $type   = 'product_id';
            $id     = $handler->{data}{select_product_id};
        }
        elsif ( $handler->{data}{select_designer_id} =~ m{\A\d+\z}xms ) {
            $type   = 'designer_id';
            $id     = $handler->{data}{select_designer_id};
        }
        else {
            $type   = 'all';
        }

        my %origin_map  = ( GI => 'Goods In' );

        ## Add sidenav
        my $sidenav_ref;

        foreach ( sort keys %origin_map ) {
            push @{ $sidenav_ref->[0]{'Request:'} }, { title => "&nbsp;$origin_map{$_}&nbsp;", url => "FaultyGI?select_origin=$_" };
        }

        push @{ $sidenav_ref->[1]{'Workstation:'} }, { title => "&nbsp;RTV&nbsp;Workstation&nbsp;", url => 'FaultyGI?display_list=workstation' };

        $handler->{data}{sidenav} = $sidenav_ref;


        if ($handler->{data}{display_list} eq 'inspection') {

            $handler->{data}{tt_process_block}    = 'rtv_inspection';

            ## fetch columnsort values from cookie
            my $columnsort_ref = $handler->get_cookies('ColumnSort')
                ->get_sort_data($handler->{data}{tt_process_block});
            $handler->{data}{columnsort}        = $columnsort_ref;
            $handler->{data}{origin_map}        = \%origin_map;
            $handler->{data}{subsection}        = 'Inspection Request';
            $handler->{data}{subsubsection}     = "$handler->{data}{origin_map}{$handler->{data}{select_origin}}";

            $handler->{data}{rtv_inspection_stock_list}  = list_rtv_inspection_stock({
                    dbh             => $handler->{dbh},
                    type            => $type,
                    id              => $id,
                    origin          => $handler->{data}{select_origin},
                    columnsort      => $columnsort_ref,
            }) unless $handler->{data}{datalite};

        }
        elsif ($handler->{data}{display_list} eq 'workstation') {

            ## fetch columnsort values from cookie
            my $columnsort_ref = $handler->get_cookies('ColumnSort')
                ->get_sort_data($handler->{data}{tt_process_block});
            $handler->{data}{columnsort}      = $columnsort_ref;
            $handler->{data}{display_list}    = 'workstation';
            $handler->{data}{subsection}      = 'Inspection';
            $handler->{data}{subsubsection}   = 'RTV Workstation';

            $handler->{data}{rtv_workstation_stock_list}  = list_rtv_workstation_stock({
                    dbh             => $handler->{dbh},
                    type            => $type,
                    id              => $id,
                    columnsort      => $columnsort_ref,
            }) unless $handler->{data}{datalite};

        } ## END if ($display_list eq ...)

        if ( $type ne "all" ) {
            $handler->get_cookies('Search')
                ->create_search_cookie($handler->{data}{tt_process_block}, "?select_".$type."=".$id);
        }
        else {
            $handler->get_cookies('Search')
                ->expire_cookie($handler->{data}{tt_process_block});
        }

    }
    # display workstation drilldown page
    elsif ( $handler->{data}{display_workstation_drilldown} and ( $handler->{data}{product_id} =~ m{\A\d+\z}xms ) ) {

        # get common product header
        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

        my $rtv_workstation_product_list_ref = list_rtv_stock({
                dbh                 => $handler->{dbh},
                rtv_stock_type      => 'RTV Workstation',
                type                => 'product_id',
                id                  => $handler->{data}{product_id},
                get_image_names     => 1,
                get_di_fault_data   => 1,
                columnsort_ref      => { order_by => 'product_id', asc_desc => 'ASC' },
                channel_id          => $handler->{data}{channel_id},
        });


        if ( @{$rtv_workstation_product_list_ref} ) {
            $handler->{data}{tt_process_block}                = 'rtv_workstation_decision';
            $handler->{data}{rtv_workstation_product_list}    = $rtv_workstation_product_list_ref;
            $handler->{data}{subsection}                      = 'Inspection Decision';
            $handler->{data}{item_fault_types}                = list_item_fault_types( { dbh => $handler->{dbh} } );
        }

    } ## END if

    return $handler->process_template;
}

1;
