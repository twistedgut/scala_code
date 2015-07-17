package XTracker::Stock::RTV::ListRMA;

use strict;
use warnings;
use Carp;

use Hash::Util                          qw( lock_hash );

use XTracker::Handler;
use XTracker::Constants::FromDB         qw( :rma_request_status :rma_request_detail_status :stock_process_type :stock_process_status );
use XTracker::Database::RTV             qw( :rma_request :rtv_shipment :rtv_document :validate :rtv_stock update_rtv_status
                                            list_countries get_operator_details get_parent_id is_nonfaulty create_rtv_stock_process );
use XTracker::Utilities                 qw( :edit :string );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    my $RTV_CONSTANTS_REF = {
        RMA_STAT_NEW            => $RMA_REQUEST_STATUS__NEW,
        RMA_STAT_REQUESTED      => $RMA_REQUEST_STATUS__RMA_REQUESTED,
        RMA_STAT_RECEIVED       => $RMA_REQUEST_STATUS__RMA_RECEIVED,
        RMA_STAT_PROCESSING     => $RMA_REQUEST_STATUS__RTV_PROCESSING,
        RMA_DET_STAT_NEW        => $RMA_REQUEST_DETAIL_STATUS__NEW,
        RMA_DET_STAT_DEAD       => $RMA_REQUEST_DETAIL_STATUS__SENT_TO_DEAD_STOCK,
        RMA_DET_STAT_MAIN       => $RMA_REQUEST_DETAIL_STATUS__SENT_TO_MAIN_STOCK,
    };
    lock_hash(%$RTV_CONSTANTS_REF);

    $handler->{data}{section}               = 'RTV';
    $handler->{data}{subsection}            = 'List RMA';
    $handler->{data}{subsubsection}         = 'View List';
    $handler->{data}{content}               = 'rtv/list_rma.tt';
    $handler->{data}{tt_process_block}      = 'rma_request_list';
    $handler->{data}{rtv_constants}         = $RTV_CONSTANTS_REF;
    $handler->{data}{operator_details}      = get_operator_details( { dbh => $handler->{dbh}, operator_id => $handler->{data}{operator_id} } );
    $handler->{data}{filter_msgs}           = [];

    # get rma request id from url
    $handler->{data}{rma_request_id} = $handler->{param_of}{rma_request_id} // '';

    # show rma email
    if ( $handler->{data}{rma_request_id} =~ m{\A\d+\z}xms && $handler->{param_of}{submit_show_rma_email} ) {

        ## create RMA request document (.pdf)
        my ($doc_name, $rma_request_details_ref)
            = create_rma_request_document({
                dbh             => $handler->{dbh},
                rma_request_id  => $handler->{data}{rma_request_id},
                operator_id     => $handler->{data}{operator_id},
        });

        ## display RMA request email form
        $handler->{data}{tt_process_block}    = 'rma_request_email';
        $handler->{data}{subsubsection}       = 'Email';
        $handler->{data}{doc_name}            = $doc_name;
        $handler->{data}{rma_request_details} = $rma_request_details_ref;
        $handler->{data}{sales_channel}       = $handler->{data}{rma_request_details}->[0]{sales_channel};

    }
    # show RMA request details
    elsif ( $handler->{data}{rma_request_id} =~ m{\A\d+\z}xms  ) {

        $handler->{data}{tt_process_block}  = 'rma_request';
        $handler->{data}{subsubsection}     = 'View Request';
        $handler->{data}{is_nonfaulty}      = is_nonfaulty( { dbh => $handler->{dbh}, type => 'rma_request_id', id => $handler->{data}{rma_request_id} } );

        # fetch request details
        $handler->{data}{rma_request_details} = list_rma_request_details( { dbh => $handler->{dbh}, type => 'rma_request_id', id => $handler->{data}{rma_request_id} } );

        # set sales channel
        $handler->{data}{sales_channel} = $handler->{data}{rma_request_details}->[0]{sales_channel};

        # get designer out of request details
        my $designer_id = $handler->{data}{rma_request_details}->[0]{designer_id};

        # fetch designer_addresses
        $handler->{data}{designer_addresses}  = list_designer_addresses( { dbh => $handler->{dbh}, designer_id => $designer_id, list_format => 'select_list' } );
        $handler->{data}{country_list}        = list_countries( { dbh => $handler->{dbh} } );

        # fetch designer carriers
        $handler->{data}{designer_carriers} = list_designer_carriers( { dbh => $handler->{dbh}, designer_id => $designer_id } );

        # fetch rtv carriers
        $handler->{data}{rtv_carriers} = list_rtv_carriers( { dbh => $handler->{dbh} } );

        # fetch comment log entries
        $handler->{data}{rma_request_notes} = list_rma_request_notes( { dbh => $handler->{dbh}, rma_request_id => $handler->{data}{rma_request_id} } );

        # Add sidenav 'Back'
        if ( $handler->session_stash->{last_listrma_rtv_search_params} ) {
             my $uri = URI->new($handler->{data}{uri});
             $uri->query_form($handler->session_stash->{last_listrma_rtv_search_params});
             push @{$handler->{data}{sidenav}[0]{None}}, {
                title => 'Back&nbsp;to&nbsp;List',
                url => $uri,
             };
        }

    }
    # show full list
    else {
        unless ( $handler->{data}{datalite} ) {

            my %search_params = %{$handler->{param_of}};
            my @sort_keys = qw{order_by asc_desc};
            @{$handler->{data}{columnsort}}{@sort_keys} = delete @search_params{@sort_keys};
            my $uri = URI->new($handler->{data}{uri});
            $uri->query_form(%search_params);

            $handler->session_stash->{last_listrma_rtv_search_params}
                = \%{$handler->{param_of}};

            # Pass search parameters (for auto-filling form) and URI (for ordering
            # cols) back to template
            $handler->{data}{search_params} = \%search_params;
            $handler->{data}{search_uri} = $uri;

            $handler->{data}{rma_request_designers} = list_rma_request_designers( { dbh => $handler->{dbh} } );
            $handler->{data}{rma_request_statuses}  = list_rma_request_statuses( { dbh => $handler->{dbh} } );

            # fetch list of RMA requests, based on specified search criteria
            $handler->{data}{rma_request_list}      = _list_rma_requests_filtered({
                dbh                 => $handler->{dbh},
                params              => $handler->{param_of},
                rtv_constants_ref   => $RTV_CONSTANTS_REF,
                columnsort_ref      => $handler->{data}{columnsort},
                filter_msgs_ref     => $handler->{data}{filter_msgs},
                handler             => $handler
            });
        }

    }

    return $handler->process_template( undef );
}

sub _list_rma_requests_filtered {

    my ($arg_ref)           = @_;

    my $dbh_read            = $arg_ref->{dbh};
    my $rest_ref            = $arg_ref->{params};
    my $RTV_CONSTANTS_REF   = $arg_ref->{rtv_constants_ref};
    my $columnsort_ref      = $arg_ref->{columnsort_ref};
    my $filter_msgs_ref     = $arg_ref->{filter_msgs_ref};
    my $handler             = $arg_ref->{handler};

    my $select_type;
    my $select_id_start;
    my $select_id_end;


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

    ## fetch list of RMA requests, based on criteria specified
    my $select_designer_id      = defined $rest_ref->{select_designer_id}       ? $rest_ref->{select_designer_id}       : '';
    my $select_status_id        = defined $rest_ref->{select_status_id}         ? $rest_ref->{select_status_id}         : '';
    my $select_rma_request_id   = defined $rest_ref->{select_rma_request_id}    ? $rest_ref->{select_rma_request_id}    : '';
    my $select_product_id       = defined $rest_ref->{select_product_id}        ? $rest_ref->{select_product_id}        : '';
    my $select_sku              = defined $rest_ref->{select_sku}               ? $rest_ref->{select_sku}               : '';
    my $filter_options;
    my $schema = $handler->{schema};

    if ( exists $rest_ref->{search_select}){
        if ( is_valid_format( { value => $select_designer_id, format => 'id' } ) ) {
            $filter_options->{designer_id} = $select_designer_id;
            push @$filter_msgs_ref, 'Designer';
        }
        if (is_valid_format( { value => $select_status_id, format => 'id' } ) ) {
            $filter_options->{rma_request_status_id} = $select_status_id;
            push @$filter_msgs_ref, 'Status';
        }
        if ( is_valid_format( { value => $select_rma_request_id, format => 'id' } )) {
            $filter_options->{rma_request_id} = $select_rma_request_id;
            push @$filter_msgs_ref, "Request Ref: $select_rma_request_id";
        }
        if ( is_valid_format( { value => $select_sku, format => 'sku' } ) ) {
             $filter_options->{variant_id}
                 = [$schema->resultset('Public::Variant')
                            ->search_by_sku($select_sku)
                            ->get_column('id')
                            ->all];

            push @$filter_msgs_ref, "SKU: $select_sku";
        }
        if (is_valid_format( { value => $select_sku, format => 'int_positive' } ) ) {
            $filter_options->{product_id} = $select_sku;
            push @$filter_msgs_ref, "PID: $select_sku";
        }
    }

    my $rma_request_list_ref;
    if (scalar(keys %{$filter_options})) {
       $rma_request_list_ref = list_rma_requests({
                dbh         => $dbh_read,
                params => $filter_options,
                columnsort  => $columnsort_ref,
        });
    }

    return $rma_request_list_ref;

} ## END sub _list_rma_requests_filtered

1;
