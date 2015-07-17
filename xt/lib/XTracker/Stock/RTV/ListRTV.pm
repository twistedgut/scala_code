package XTracker::Stock::RTV::ListRTV;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);
use Hash::Util                  qw( lock_hash );
use URI;
use XTracker::Handler;
use XTracker::Constants::FromDB qw( :rtv_shipment_status :rtv_shipment_detail_status );

use XTracker::Database;
use XTracker::Database::RTV     qw( :rma_request :rtv_shipment :rtv_document :validate update_rtv_status list_countries );
use XTracker::Navigation;
use XTracker::Session;
use XTracker::Utilities qw( :edit :string );
use XTracker::XTemplate;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    my $RTV_CONSTANTS_REF = {
        RTV_SHIP_STAT_AWAITING_DISPATCH => $RTV_SHIPMENT_STATUS__AWAITING_DISPATCH,
        RTV_SHIP_STAT_DISPATCHED        => $RTV_SHIPMENT_STATUS__DISPATCHED,
        RTV_SHIP_DET_STAT_DISPATCHED    => $RTV_SHIPMENT_DETAIL_STATUS__DISPATCHED,
        RTV_SHIP_STAT_HOLD              => $RTV_SHIPMENT_STATUS__HOLD,
    };
    lock_hash(%$RTV_CONSTANTS_REF);

    my %filter_map  = (
        'awaitingdispatch'  => {
                                    filter_uri      => 'AwaitingDispatch',
                                    filter_param    => 'select_status_id',
                                    filter_value    => $RTV_CONSTANTS_REF->{RTV_SHIP_STAT_AWAITING_DISPATCH},
                                    filter_title    => 'Awaiting Dispatch',
                               },
    );
    lock_hash(%filter_map);

    $handler->{data}{section} = 'RTV';
    $handler->{data}{subsection}            = 'List RTV';
    $handler->{data}{subsubsection}         = 'View List';
    $handler->{data}{content}               = 'rtv/list_rtv.tt';
    $handler->{data}{tt_process_block}      = 'rtv_shipment_list';
    $handler->{data}{rtv_constants}         = $RTV_CONSTANTS_REF;
    $handler->{data}{filter_msgs}           = [];

    # quick fix for /RTV/AwaitingDispatch should set filter_name = awaitingdispatch
    my $uri       = $r->parsed_uri;
    my $path_info = $uri->path;
    if ( $path_info =~ m/AwaitingDispatch/) {
        $handler->{param_of}{filter_name} = 'awaitingdispatch';
    }


    # get info from url
    $handler->{data}{rtv_shipment_id}   = $handler->{param_of}{rtv_shipment_id};
    $handler->{data}{rma_request_id}    = $handler->{param_of}{rma_request_id};
    $handler->{data}{airway_bill}       = $handler->{param_of}{airway_bill};
    $handler->{data}{filter}{name}      = $handler->{param_of}{filter_name};

    # remove 'RTVS-' prefix if necessary (i.e. for scanned input)
    $handler->{data}{rtv_shipment_id} //= '';
    $handler->{data}{rtv_shipment_id}   = $handler->{data}{rtv_shipment_id} =~ m{\ARTVS-(\d+)\z}xms ? $1 : $handler->{data}{rtv_shipment_id};

    # Apply filter, if specified
    if ( $handler->{data}{filter}{name} ) {
        my $filter_param                    = $filter_map{ $handler->{data}{filter}{name} }{filter_param};
        $handler->{data}{filter}{uri}       = $filter_map{ $handler->{data}{filter}{name} }{filter_uri};
        $handler->{data}{subsubsection}     = $filter_map{ $handler->{data}{filter}{name} }{filter_title};
        $handler->{param_of}{$filter_param} = $filter_map{ $handler->{data}{filter}{name} }{filter_value};
        $handler->{param_of}{search_select} = 1;
    }

    # view shipment
    if ( $handler->{data}{rtv_shipment_id} =~ m{\A\d+\z}xms ) {

        $handler->{data}{tt_process_block}  = 'rtv_shipment';

        ## Add sidenav 'Back'
        if ( $handler->session_stash->{last_dispatched_rtv_search_params} ) {
            my $uri = URI->new($handler->{data}{uri});
            $uri->query_form($handler->session_stash->{last_dispatched_rtv_search_params});
            push @{$handler->{data}{sidenav}[0]{None}}, {
                title => 'Back&nbsp;to&nbsp;List',
                url   => $uri,
            };
        }

        # fetch RTV shipment details
        $handler->{data}{rtv_shipment_details} = list_rtv_shipment_details( { dbh => $handler->{dbh}, type => 'rtv_shipment_id', id => $handler->{data}{rtv_shipment_id} } );

        if ( scalar @{$handler->{data}{rtv_shipment_details}} ) {
            $handler->{data}{subsubsection} = "View Shipment Details";
            $handler->{data}{sales_channel} = $handler->{data}{rtv_shipment_details}->[0]{sales_channel};
        }

    }
    # show list
    else {

        my %search_params = %{$handler->{param_of}};
        my @sort_keys = qw{order_by asc_desc};
        @{$handler->{data}{columnsort}}{@sort_keys} = delete @search_params{@sort_keys};
        my $uri = URI->new($handler->{data}{uri});
        $uri->query_form(%search_params);

        $handler->session_stash->{last_dispatched_rtv_search_params}
            = \%{$handler->{param_of}};

        # Pass search parameters (for auto-filling form) and URI (for ordering
        # cols) back to template
        $handler->{data}{search_params} = \%search_params;
        $handler->{data}{search_uri} = $uri;

        # fetch list of rma_request designers and statuses
        $handler->{data}{rma_request_designers}   = list_rma_request_designers( { dbh => $handler->{dbh} } );
        $handler->{data}{rtv_shipment_statuses}   = list_rtv_shipment_statuses( { dbh => $handler->{dbh} } );
        # fetch list of RTV shipments, based on specified search criteria
        $handler->{data}{rtv_shipment_list} = _list_rtv_shipments_filtered({
                    dbh                 => $handler->{dbh},
                    rest_ref            => \%search_params,
                    rtv_constants_ref   => $RTV_CONSTANTS_REF,
                    columnsort_ref      => $handler->{data}{columnsort},
                    filter_msgs_ref     => $handler->{data}{filter_msgs},
                    handler             => $handler
        });

    }


    $handler->process_template( undef );

    return OK;
} ## END sub handler



### Subroutine : _list_rtv_shipments_filtered
# usage        :
# description  :
# parameters   :
#              :
# returns      :
sub _list_rtv_shipments_filtered {

    my ($arg_ref)           = @_;
    my $dbh_read            = $arg_ref->{dbh};
    my $rest_ref            = $arg_ref->{rest_ref};
    my $RTV_CONSTANTS_REF   = $arg_ref->{rtv_constants_ref};
    my $columnsort_ref      = $arg_ref->{columnsort_ref};
    my $filter_msgs_ref     = $arg_ref->{filter_msgs_ref};
    my $handler = $arg_ref->{handler};

    my $select_type;
    my $select_id_start;
    my $select_id_end;
    my $filter_options;

    # check if we need to get the search params from a search cookie
    if ( exists($rest_ref->{cookie_search}) ) {
        # read the search cookie if it exists
        my $cookie_search = $handler->get_cookies('Search')
            ->get_search_cookie($handler->{data}{tt_process_block});

        # are there any params in the cookie
        if ( defined $cookie_search ) {
            # merge the params from the cookie into the 'param_of' HASH as if they have just been submitted
            $rest_ref   = { %{$rest_ref} , %{$cookie_search} };
        }
    }

    ## fetch list of RTV shipments, based on criteria specified
    my $select_designer_id      = defined $rest_ref->{select_designer_id}       ? $rest_ref->{select_designer_id}       : '';
    my $select_status_id        = defined $rest_ref->{select_status_id}         ? $rest_ref->{select_status_id}         : '';
    my $select_rma_request_id   = defined $rest_ref->{select_rma_request_id}    ? $rest_ref->{select_rma_request_id}    : '';
    my $select_rtv_shipment_id  = defined $rest_ref->{select_rtv_shipment_id}   ? $rest_ref->{select_rtv_shipment_id}   : '';
    my $select_airwaybill       = defined $rest_ref->{select_airwaybill}        ? $rest_ref->{select_airwaybill}        : '';
    my $select_sku              = defined $rest_ref->{select_sku}               ? $rest_ref->{select_sku}               : '';
    ## remove 'RTVS-' prefix if necessary (i.e. for scanned input)
    $select_rtv_shipment_id     = $select_rtv_shipment_id =~ m{\ARTVS-(\d+)\z}xms   ? $1 : $select_rtv_shipment_id;

    my $schema = $handler->{schema};
    if ( exists $rest_ref->{search_select}){
        if ( is_valid_format( { value => $select_designer_id, format => 'id' } ) ) {
            $filter_options->{designer_id} = $select_designer_id;
            push @$filter_msgs_ref, 'Designer';
        }
        if ( is_valid_format( { value => $select_status_id, format => 'id' } ) ) {
            $filter_options->{status_id} = $select_status_id;
            push @$filter_msgs_ref, 'Status';
        }
        if ( is_valid_format( { value => $select_rma_request_id, format => 'id' } ) ) {
            $filter_options->{rma_request_id} = $select_rma_request_id;
            push @$filter_msgs_ref, "Request Ref: $select_rma_request_id";
        }
        if ( is_valid_format( { value => $select_rtv_shipment_id, format => 'id' } ) ) {
            $filter_options->{rtv_shipment_id} = $select_rtv_shipment_id;
            push @$filter_msgs_ref, "Shipment ID: $select_rtv_shipment_id";
        }
        if ( is_valid_format( { value => $select_sku, format => 'sku' } ) ) {
            # We should remember that one SKU can map > 1 variant_id
            $filter_options->{variant_id}
                 = [$schema->resultset('Public::Variant')
                            ->search_by_sku($select_sku)
                            ->get_column('id')
                            ->all];
            push @$filter_msgs_ref, "SKU: $select_sku";
        }
        if ( is_valid_format( { value => $select_sku, format => 'int_positive' } ) ) {
            $filter_options->{product_id} = $select_sku;
            push @$filter_msgs_ref, "PID: $select_sku";
        }
        if ( !is_valid_format( { value => $select_airwaybill, format => 'empty_or_whitespace' } ) ) {
            $filter_options->{airway_bill} = $select_airwaybill;
            push @$filter_msgs_ref, "Airwaybill: $select_airwaybill";
        }
    }
    my @no_filter_statuses;
    #no filters sent
    if (! scalar(keys %{$filter_options})) {
        @no_filter_statuses = (  $RTV_SHIPMENT_STATUS__UNKNOWN,
                                    $RTV_SHIPMENT_STATUS__NEW,
                                    $RTV_SHIPMENT_STATUS__PICKING,
                                    $RTV_SHIPMENT_STATUS__PICKED,
                                    $RTV_SHIPMENT_STATUS__PACKING,
                                    $RTV_SHIPMENT_STATUS__AWAITING_DISPATCH);
        $filter_options->{status_id} = \@no_filter_statuses;
    } ## END if
    my $rtv_shipment_list_ref
        = list_rtv_shipments({
            dbh         => $dbh_read,
            params      => $filter_options,
            columnsort  => $columnsort_ref,
        });

    return $rtv_shipment_list_ref;

} ## END sub _list_rtv_shipments_filtered



1;

__END__

