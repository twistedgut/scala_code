package XTracker::Sample::ReviewRequests;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Config::Local             qw( samples_email :Samples );
use XTracker::Constants::FromDB         qw( :authorisation_level :sample_request_det_status );
use XTracker::Constants::Regex          ':sku';
use XTracker::Database::Profile         qw( get_operator );
use XTracker::Database::SampleRequest   qw( :ManageRequests list_request_conf_dets list_sample_receivers list_sample_requesters get_date );
use XTracker::Utilities                 qw( get_date_db );
use XTracker::Database::Channel         qw( get_channels  );

sub handler {
    my $handler = XTracker::Handler->new( shift );
    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    ## get sample request types
    my $sample_request_types_ref = list_sample_request_types( { dbh => $dbh } );

    $handler->{data}{content}              = 'stocktracker/sample/reviewrequests.tt';
    $handler->{data}{section}              = 'Sample';
    $handler->{data}{subsection}           = undef;
    $handler->{data}{subsubsection}        = undef;
    $handler->{data}{tt_process_block}     = undef;
    $handler->{data}{current_date}         = get_date_db( { dbh => $dbh } );
    $handler->{data}{sample_request_types} = $sample_request_types_ref;


    $handler->{data}{CAN_MANAGE}    = 0;
    if ( $handler->auth_level == $AUTHORISATION_LEVEL__MANAGER ) {
        $handler->{data}{CAN_MANAGE}    = 1;
    }

    ## get sample request header and receiver address details
    if ($handler->{param_of}{request_id}) {

        my $sample_request_header_ref = get_sample_request_header({
            dbh  => $dbh,
            type => 'sample_request_id',
            id   => $handler->{param_of}{request_id}
        })->[0];

        my @receiver_address;
        foreach ( qw|address_line_1 address_line_2 address_line_3 towncity county country postcode| ) {
            push @receiver_address, $sample_request_header_ref->{$_}        if $sample_request_header_ref->{$_};
        }

        $handler->{data}{receiver_address}      = \@receiver_address;
        $handler->{data}{sample_request_header} = $sample_request_header_ref;
        $handler->{data}{sales_channel}         = $sample_request_header_ref->{sales_channel};
    }

    CASE: {
        ## display request list
        if ( !$handler->{param_of}{action} ) {
            $handler->{data}{receivers}         = list_sample_receivers( { dbh => $dbh, include_do_not_use => 1 } );
            $handler->{data}{requesters}        = list_sample_requesters( { dbh => $dbh } );
            $handler->{data}{channel_list}      = get_channels( $dbh );
            $handler->{data}{subsection}        = 'Review Requests';
            $handler->{data}{subsubsection}     = 'List';
            $handler->{data}{tt_process_block}  = 'sample_request_list';

            if ( $handler->{param_of}{submit_search} ) {

                # We have performed a search, let's tell the template so it
                # knows it needs to display the search result table
                $handler->{data}{params_passed}{submit_search} = 1;

                ## fetch columnsort values from cookie
                my $columnsort_ref = $handler->get_cookies('ColumnSort')
                    ->get_sort_data($handler->{data}{tt_process_block});

                $handler->{data}{columnsort} = $columnsort_ref;

                # check if we need to get the search params from a search cookie
                if ( exists($handler->{param_of}{cookie_search}) ) {
                    # read the search cookie if it exists
                    my $cookie_search = $handler->get_cookies('Search')
                        ->get_search_cookie($handler->{data}{tt_process_block});

                    # are there any params in the cookie
                    if ( defined $cookie_search ) {
                        # merge the params from the cookie into the 'param_of' HASH as if they have just been submitted
                        $handler->{param_of} = { %{$handler->{param_of} } , %{$cookie_search} };
                    }
                }

                my @search_params = ("?submit_search=1");
                my %search_args = ( is_completed => 0 );

                # set-up default search arguments
                my %args = ( columnsort => $columnsort_ref );

                # An empty string here means we don't search by this param
                if ( exists $handler->{param_of}{is_completed} ) {
                    if ( length $handler->{param_of}{is_completed} ) {
                        $search_args{is_completed} = $handler->{param_of}{is_completed};
                        push @search_params, "is_completed=$handler->{param_of}{is_completed}";
                    }
                }

                ## get sample request list - Ref. search
                if ( exists $handler->{param_of}{txt_request_id} &&
                    $handler->{param_of}{txt_request_id} =~ m/^\d+$/ ) {

                    $search_args{sample_request_id} = $handler->{param_of}{txt_request_id};
                    push @search_params, "txt_request_id=$handler->{param_of}{txt_request_id}";
                }

                ## get sample request list - SKU search
                if ( exists $handler->{param_of}{txt_SKU} &&
                    (my ($pid,$sid) = $handler->{param_of}{txt_SKU} =~ $SKU_REGEX) ) {

                    $search_args{SKU} = [$pid,$sid];
                    push @search_params, "txt_SKU=$handler->{param_of}{txt_SKU}";
                }

                ## get sample request list - Receiver search
                if ( exists $handler->{param_of}{ddl_receiver_id} &&
                    $handler->{param_of}{ddl_receiver_id} =~ m/^[1-9]\d*$/ ) {

                    $search_args{sample_receiver_id} = $handler->{param_of}{ddl_receiver_id};
                    push @search_params, "ddl_receiver_id=$handler->{param_of}{ddl_receiver_id}";
                }

                ## get sample request list - Requester search
                if ( exists $handler->{param_of}{ddl_requester_id} &&
                    $handler->{param_of}{ddl_requester_id} =~ m/^[1-9]\d*$/ ) {

                    $search_args{requester_id} = $handler->{param_of}{ddl_requester_id};
                    push @search_params, "ddl_requester_id=$handler->{param_of}{ddl_requester_id}";
                }

                ## get sample request list - Type Search
                if ( exists $handler->{param_of}{ddl_request_type_id} &&
                    $handler->{param_of}{ddl_request_type_id} =~ m/^[1-9]\d*$/ ) {

                    $search_args{sample_request_type_id} = $handler->{param_of}{ddl_request_type_id};
                    push @search_params, "ddl_request_type_id=$handler->{param_of}{ddl_request_type_id}";
                }

                ## get sample request list - Channel Search
                if ( exists $handler->{param_of}{ddl_channel_id} &&
                    $handler->{param_of}{ddl_channel_id} =~ m/^[1-9]\d*$/ ) {

                    $search_args{channel_id} = $handler->{param_of}{ddl_channel_id};
                    push @search_params, "ddl_channel_id=$handler->{param_of}{ddl_channel_id}";

                }

                # store the search in a cookie for future use
                $handler->get_cookies('Search')->create_search_cookie(
                    $handler->{data}{tt_process_block}, join q{&}, @search_params
                );

                # pass in the parameters to the TT so they can be re-displayed in the search form
                $handler->{data}{params_passed} = $handler->{param_of};

                $handler->{data}{sample_request_list} = list_sample_requests(
                    $dbh, { %args, args => \%search_args }
                );
                $handler->{data}{sort_search_params} = join q{&}, @search_params;

            }
            else {
                # delete the cookie as the search is now the default
                $handler->get_cookies('Search')
                    ->expire_cookie($handler->{data}{tt_process_block});
                $handler->get_cookies('ColumnSort')
                    ->expire_cookie($handler->{data}{tt_process_block});
            }
            last CASE;
        }
        else {
            ## Set up sidenav for when a request id has been picked
            $handler->{data}{sidenav} = [{ 'None' => [{
                title => 'Back to Request List',
                url => '/Sample/ReviewRequests?cookie_search=1',
            }]}];
        }
        ## Display Press Bookout Confirmation in a popup window
        if ( lc($handler->{param_of}{action}) eq 'conf_bookout'
          && $handler->{param_of}{conf_request_type} eq 'Press'
          && $handler->{param_of}{request_conf_id} ) {

            my $channels = get_channels( $dbh );

            $handler->{data}{press_bookout_conf_dets} = list_request_conf_dets({
                dbh  => $dbh,
                type => 'sample_request_conf_id',
                id   => $handler->{param_of}{request_conf_id},
            });
            my $channel_id          = $handler->{data}{press_bookout_conf_dets}[0]{channel_id};

            my @samples_address = samples_addr();
            my $samples_tel     = samples_tel();
            my $samples_fax     = samples_fax();
            my %conf_email_addr = ( samples_email => samples_email($channels->{$channel_id}{config_section}) );


            $handler->{data}{channel_info}     = $channels->{$channel_id};
            $handler->{data}{channel}          = $schema->resultset('Public::Channel')->find($channel_id);
            $handler->{data}{samples_address}  = \@samples_address;
            $handler->{data}{samples_tel}      = $samples_tel;
            $handler->{data}{samples_fax}      = $samples_fax;
            $handler->{data}{orig}             = $handler->{param_of}{orig} eq 'm' ? 'ManageRequests' : 'ReviewRequests';
            $handler->{data}{samples_email}    = $conf_email_addr{samples_email};
            $handler->{data}{template_type}    = 'blank';
            $handler->{data}{content}          = 'sample/press_bookout_conf.tt';
            $handler->{data}{tt_process_block} = 'press_bookout_conf';

            last CASE;
        }
        ## Normal look at a Sample Request or handle Confirmation of a Sample Cart having been created
        if (
            (
                lc($handler->{param_of}{action}) eq 'drilldown'
             || lc($handler->{param_of}{action}) eq 'conf_request'
            ) && $handler->{param_of}{request_id}
        ) {

            ## get sample request details
            $handler->{data}{sample_request_dets} = list_sample_request_dets({
                dbh            => $dbh,
                type           => 'sample_request_id',
                id             => $handler->{param_of}{request_id},
                get_status_log => 1
            });

            ## If come from SampleTransfer then get all params and display link back
            if ( $handler->{referer} =~ m{/Sample/SampleTransfer} ) {
                my $suffix  = "?";
                foreach ( keys %{ $handler->{param_of} } ) {
                    next if ( $_ eq "action" || $_ eq "request_id" );
                    $suffix .= $_."=".$handler->{param_of}{$_}."&";
                }
                $suffix =~ s/\&$//;

                push @{ $handler->{data}{sidenav}[0]{None} },{
                    title => 'Sample Transfer List',
                    url   => '/Sample/SampleTransfer'.$suffix
                };
            }

            ## get sample confirmations
            if ( $handler->{data}{sample_request_header}{type} eq "Press" ) {
                $handler->{data}{bookout_conf_dets} = list_request_conf_dets({
                    dbh  => $dbh,
                    type => 'sample_request_id',
                    id   => $handler->{param_of}{request_id},
                });
                if ( @{$handler->{data}{bookout_conf_dets}} ) {
                    push @{ $handler->{data}{sidenav} },
                        { 'Request Ref. '.$handler->{data}{sample_request_header}{sample_request_ref} => [
                            {
                                title   => 'Show Confirmations',
                                url     => '#confs'
                            }
                        ]};
                }
            }

            # if cart has just been created then show appropriate headings
            if ( lc($handler->{param_of}{action}) eq 'conf_request' ) {
                $handler->{data}{subsection}    = 'Sample Request Confirmation';
                $handler->{data}{subsubsection} = "Ref. $handler->{data}{sample_request_header}{sample_request_ref}";
            }
            else {
                $handler->{data}{subsection}    = 'Review Requests';
                $handler->{data}{subsubsection} = "Items - Request $handler->{data}{sample_request_header}{sample_request_ref}";
            }
            $handler->{data}{tt_process_block} = 'sample_request';

            ## get refs to bookout and returned dates
            my $date_booked_ref = get_date( { offset_days => 0 } );
            my $date_return_ref = get_date( { offset_days => 8 } );

            $handler->{data}{date_booked} = $date_booked_ref;
            $handler->{data}{date_return} = $date_return_ref;

            last CASE;
        }
        ## view request confirmation list
        if ( lc($handler->{param_of}{action}) eq 'conflist'
          && $handler->{param_of}{request_id}
        ) {

            my %args = (
                dbh  => $dbh,
                type => 'sample_request_id',
                id   => $handler->{param_of}{request_id}
            );

            my $xtra_nav= [{
                title => 'Show All Items',
                url   => '/Sample/ReviewRequests?action=drilldown&request_id='
                       . $handler->{param_of}{request_id}
            }];

            # if just a single confirmation has been requested change args to only look for one
            if ( exists($handler->{param_of}{request_conf_id}) ) {
                %args = (
                    dbh  => $dbh,
                    type => 'sample_request_conf_id',
                    id   => $handler->{param_of}{request_conf_id}
                );
                push @{ $xtra_nav }, {
                    title => 'Show All Confirmations',
                    url   => '/Sample/ReviewRequests?action=conflist&request_id='
                           . $handler->{param_of}{request_id}
                };
            }

            push @{ $handler->{data}{sidenav} }, {
                'Request Ref. '.$handler->{data}{sample_request_header}{sample_request_ref} => $xtra_nav
            };

            $handler->{data}{bookout_conf_dets} = list_request_conf_dets( \%args );
            $handler->{data}{subsubsection}     = "Confirmation List - Request $handler->{data}{sample_request_header}{sample_request_ref}";
            $handler->{data}{tt_process_block}  = 'confirmation_list_block';

            last CASE;
        }
    };

    return $handler->process_template;
}

1;
