package XTracker::Sample::Actions::ProcessSampleRequest;

use strict;
use warnings;
use Carp;

use XTracker::Handler;
use XTracker::Constants::FromDB                 qw( :authorisation_level :sample_request_det_status );
use XTracker::Database::SampleRequest   qw( :SampleBooking complete_sample_request change_det_status );
use XTracker::Utilities                 qw( url_encode isdates_ok );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    if ( $handler->auth_level < $AUTHORISATION_LEVEL__MANAGER ) {
        xt_warn("You don't have permission to manage sample requests.");
        return $handler->redirect_to( "/Sample/ReviewRequests" );
    }

    ## set redirect location
    my $ret_loc     = "/Sample/ReviewRequests";

    # specify basic parameters needed to return to Review Requests
    my $ret_params = "?action=drilldown";
    $ret_params .= "&request_id=".$handler->{param_of}{sample_request_id};

    my @display_msgs;
    ## submission from 'Manage Requests' page
    if ( exists( $handler->{param_of}{submit_manage_booking} ) ) {

        my $schema = $handler->schema;
        my $dbh = $schema->storage->dbh;
        my ($bookout_request_det_id_ref, $bookin_request_det_id_ref, $decline_request_det_id_ref, $date_booked, $date_return_due)
            = _extract_booking_params( { postdata => $handler->{param_of} } );

        eval {
            my $doanything = 0;

            my $guard = $schema->txn_scope_guard;
            ## if items are selected to be declined...
            if ( keys %{$decline_request_det_id_ref} ) {

                $doanything = 1;
                my $count   = 0;

                foreach my $request_det_id ( keys %{$decline_request_det_id_ref} ) {
                    ## set det_status and write det_status_log entry
                    change_det_status({
                        dbh                     => $dbh,
                        sample_request_det_id   => $request_det_id,
                        det_status_id           => $SAMPLE_REQUEST_DET_STATUS__DECLINED,
                        loc_from                => undef,
                        loc_to                  => undef,
                        operator_id             => $handler->operator_id,
                    });

                    $count++;
                }

                push @display_msgs, 'Sample Request Item'.(($count > 1) ? 's' : '').' Declined.';
            }

            ## if items are selected for bookout...
            if ( keys %{$bookout_request_det_id_ref} ) {

                $doanything     = 1;
                my @chk_dates;

                push @chk_dates,$date_booked                    if ($date_booked);
                push @chk_dates,$date_return_due                if ($date_return_due);

                die "Invalid Dates Passed.\n" if !isdates_ok(@chk_dates);

                my $count       = 0;

                ## write sample request confirmation header record
                my $sample_request_conf_id =
                    write_request_conf_header( { dbh => $dbh, sample_request_id => $handler->{param_of}{sample_request_id},
                        date_confirmed => $date_booked, date_return_due => $date_return_due, operator_id => $handler->operator_id } );

                ## perform bookout/s
                foreach my $request_det_id ( keys %{$bookout_request_det_id_ref} ) {

                    my $variant_id       = $bookout_request_det_id_ref->{$request_det_id}{variant_id};
                    my $quantity_to_book = $bookout_request_det_id_ref->{$request_det_id}{quantity_to_book};

                    bookout_sample({
                        dbh                     => $dbh,
                        sample_request_det_id   => $request_det_id,
                        variant_id              => $variant_id,
                        quantity_to_book        => $quantity_to_book,
                        date_return_due         => $date_return_due,
                        operator_id             => $handler->operator_id,
                    });

                    ## write sample request confirmation detail record
                    write_request_conf_dets({
                        dbh                     => $dbh,
                        sample_request_conf_id  => $sample_request_conf_id,
                        sample_request_det_id   => $request_det_id,
                        variant_id              => $variant_id,
                        quantity                => $quantity_to_book,
                    });

                    $count++;
                }

                push @display_msgs, "Sample Request Item".(($count > 1) ? 's' : '')." Approved.";

                ## set redirect location for 'Press' requests
                if ( $handler->{param_of}{sample_request_type} eq 'Press' ) {
                    $ret_params     = "?action=conflist";
                    $ret_params     .= "&request_id=".$handler->{param_of}{sample_request_id};
                    $ret_params     .= "&request_conf_id=".$sample_request_conf_id;
                }
            }

            ## if items are selected for bookin...
            if ( keys %{$bookin_request_det_id_ref} ) {

                $doanything     = 1;
                my $count       = 0;

                ## perform bookin/s
                foreach my $request_det_id ( keys %{$bookin_request_det_id_ref} ) {

                    my $variant_id              = $bookin_request_det_id_ref->{$request_det_id}{variant_id};
                    my $quantity_to_book        = $bookin_request_det_id_ref->{$request_det_id}{quantity_to_book};

                    ## get current status details for this sample_request_det line, in order to book back from current location
                    my $det_status_ref          = get_current_det_status( { dbh => $dbh, sample_request_det_id => $request_det_id } );
                    my $old_loc                 = $det_status_ref->{location};

                    bookin_sample({
                        dbh                     => $dbh,
                        sample_request_det_id   => $request_det_id,
                        variant_id              => $variant_id,
                        quantity_to_book        => $quantity_to_book,
                        old_loc                 => $old_loc,
                        operator_id             => $handler->operator_id,
                    });

                    $count++;
                }

                push @display_msgs, "Sample Request Item".(($count > 1) ? 's' : '')." Returned.";
            }

            if (!$doanything) {
                die "You didn't specify anything to be done.\n";
            }
            $guard->commit();
        }; ## END eval

        if ($@) {
            xt_warn($@);
        }
        else {
            ## Attempt to 'complete' request. Keep schtum if it doesn't work - it probably has open lines!
            eval {
                $schema->txn_do(sub{
                    complete_sample_request( { dbh => $dbh, sample_request_id => $handler->{param_of}{sample_request_id} } );
                });
                push @display_msgs, " Sample Request Ref. ".sprintf("%0.5d",$handler->{param_of}{sample_request_id})." now Complete.";
            };

            xt_success(join q{ }, @display_msgs);
        }
    }

    return $handler->redirect_to( $ret_loc.$ret_params );

} ## END sub handler

sub _extract_booking_params {
    my $args_ref        = shift;
    my $postdata_ref    = $args_ref->{postdata};

    ## extract bookout/bookin request detail parameters
    my %bookout_request_det_id;
    my %bookin_request_det_id;
    my %decline_request_det_id;

    foreach my $param ( keys %{$postdata_ref} ) {

        my $param_item_request_det_id   = '';
        my $param_item_variant_id       = '';
        my $param_item_quantity         = 0;

        CASE: {
            if ( $param =~ m{\Adecline_(\d+)\z}xms ) {

                $param_item_request_det_id                              = $1;
                $decline_request_det_id{$param_item_request_det_id}     = $param_item_request_det_id;

                last CASE;
            }
            if ( $param =~ m{\Abookout_(\d+)\z}xms ) {

                $param_item_request_det_id                              = $1;
                ( $param_item_variant_id, $param_item_quantity )        = split ( /_/, $postdata_ref->{$param} );
                $bookout_request_det_id{$param_item_request_det_id}     = { variant_id => $param_item_variant_id, quantity_to_book => $param_item_quantity };

                last CASE;
            }
            if ( $param =~ m{\Abookin_(\d+)\z}xms ) {

                $param_item_request_det_id                              = $1;
                ( $param_item_variant_id, $param_item_quantity )        = split ( /_/, $postdata_ref->{$param} );
                $bookin_request_det_id{$param_item_request_det_id}      = { variant_id => $param_item_variant_id, quantity_to_book => $param_item_quantity };

                last CASE;
            }
        };
    }

    my $date_booked = ( $postdata_ref->{out_year} && $postdata_ref->{out_month} && $postdata_ref->{out_day} )
                    ? "$postdata_ref->{out_year}-$postdata_ref->{out_month}-$postdata_ref->{out_day}"
                    : '';

    my $date_return_due = ( $postdata_ref->{return_year} && $postdata_ref->{return_month} && $postdata_ref->{return_day} )
                        ? "$postdata_ref->{return_year}-$postdata_ref->{return_month}-$postdata_ref->{return_day}"
                        : '';

    return ( \%bookout_request_det_id, \%bookin_request_det_id, \%decline_request_det_id, $date_booked, $date_return_due );

} ## END sub _extract_booking_params

1;
