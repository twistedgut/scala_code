package XT::JQ::DC::Receive::Upload::DoUpload;
# I tried using NAP::policy here, but it made
# doupload.t fail due to some too-early binding
# and namespace cleaning and I'm-not-sure-what
#
# -- dakkar
use Moose;
use namespace::clean -except => 'meta';

use Moose::Util::TypeConstraints;
use MooseX::Types::Moose        qw( Str Int ArrayRef );
use MooseX::Types::Structured   qw( Dict Optional );

extends 'XT::JQ::Worker';

use XTracker::Comms::DataTransfer   qw( :upload_transfer :transfer_handles :transfer :pws_visibility set_xt_product_status toggle_the_sprocs );

use XTracker::Database;
use XTracker::Database::Product     qw( get_products_info_for_upload set_upload_date );
use XTracker::Database::Operator    qw( get_operator_by_id );
use XTracker::Database::Channel     qw( get_channels );

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :upload_transfer_status :upload_transfer_log_action );

use XTracker::Config::Local         qw( config_var config_section_slurp fulcrum_hostname use_optimised_upload );
use XTracker::Logfile               qw( xt_logger );
use XTracker::EmailFunctions        qw( send_email );
use XTracker::Utilities             qw( :err_translations );

use XT::JQ::DC;

use Time::HiRes                     qw( usleep );
use XTracker::WebContent::StockManagement;
use DateTime;
with 'XTracker::Role::WithAMQMessageFactory';

has payload => (
    is => 'ro',
    isa => Dict[
        operator_id => Int,
        channel_id  => Int,
        upload_id   => Int,
        due_date    => Str,
        pid_count   => Int,
        pids        => ArrayRef[
            Dict[
                pid => Int,
                colour_variations => Optional[ArrayRef[Int]],
            ]
        ],
        environment => enum([ qw( live staging ) ])
    ],
    required => 1
);

has logger => (
    is => 'rw',
    default => sub { return xt_logger('XTracker::Comms::DataTransfer'); }
);


sub do_the_task {
    my ( $self, $job )  = @_;

    my $status;

    # get basics about the system we're on
    $self->data->{xt_instance}  = config_var("XTracker","instance");
    $self->data->{xt_dc_name}   = config_var("DistributionCentre","name");

    my $dbh = $self->schema->storage->dbh;
    $self->data->{operator} = get_operator_by_id( $dbh, $self->payload->{operator_id} );
    $self->data->{channels} = get_channels( $dbh );

    # get all products passed in the payload
    $self->data->{prods}    = get_products_info_for_upload( $dbh, $self->_pids_from_payload() );

    # store colour variation info in 'data'
    $self->data->{colour_variations} = [ grep { $_->{colour_variations} }
                                         @{$self->payload->{pids}}
                                       ]; # only keep the ones with colour variations


    # if channel id can't be found then assume job is for the other side of the pond
    if ( !exists $self->data->{channels}{ $self->payload->{channel_id} } ) {
        return ();
    }

    if ( _validate_pids( $self, $job ) ) {
        _do_the_upload( $self, $job );
    }
    else {
        _process_message( $self, $job );
    }

    return ();
}

sub check_job_payload { () }

# convenience method to return a listref of all the pids in the upload without the colour_variation data
sub _pids_from_payload {
    my $self = shift;
    return [ map { $_->{pid} } @{$self->payload->{pids}} ];
}

=head2 _do_the_upload

    usage       : _do_the_upload( $self, $job );
    description : This uploads the products for an upload list to the
                  appropriate web-site.
    parameters  : The pointer to the worker where the payload can be accessed
                  and the pointer to the job which is being processed.
    returns     : Nothing.

=cut

sub _do_the_upload {
    my ( $self, $job )  = @_;

    my $source      = "xt_" . lc($self->data->{xt_instance});
    my $sink        = "pws_" . lc($self->data->{xt_instance});
    my $channel     = $self->data->{channels}{ $self->payload->{channel_id} };
    my $environment = ( defined $self->payload->{environment} ? $self->payload->{environment} : 'live' );

    my $web_dbh;

    # list of errors that can happen when uploading data to the PWS which mean the PID can be retried
    my %exceptions  = (
            'Deadlock'              => 'retry',
            'Lock wait'             => 'retry',
            'server has gone away'  => 'retry',
        );

    my $log_msg         = "";
    my $dsp_spacer_start= "\n" . '>' x 80 . "\n";   #
    my $dsp_spacer_end  = "\n" . '<' x 80 . "\n";   # for log display
    my $dsp_spacer      = "\n" . '~' x 80 . "\n";   #

    my $transfer_status = $UPLOAD_TRANSFER_STATUS__UNKNOWN;

    my $stopped_sprocs  = 0;


    my $schema = $self->schema;
    my $dbh = $schema->storage->dbh;
    # get transfer DB handle
    eval {
        $web_dbh = get_transfer_db_handles({
            dbh_source  => $dbh,
            environment => $environment,
            channel     => $channel->{config_section},
        });
    };
    if ( $@ ) {
        $job->failed( $@ );
        return;
    }

    # The stock manager is required for one of the XTracker::Database::Reservation
    # methods called later
    my $stock_manager = XTracker::WebContent::StockManagement->new_stock_manager({
        schema => $schema,
        channel_id => $self->payload->{channel_id},
    });
    # override the 'ro' setting for the '_web_dbh' attribute, do this rather than
    # change the setting on the Class because this should be an exception and shouldn't
    # break the integrity of the Class used elsewhere in the App. for this example
    # especially as the Upload process done this way should be deprecated - hopefully!
    $stock_manager->meta->get_attribute('_web_dbh')->set_value( $stock_manager, $web_dbh->{dbh_sink} );

    # Stop the SPROCS on the WEB DB from running
    eval {
        if ( $stopped_sprocs = toggle_the_sprocs( $web_dbh, 'off', \%exceptions ) ) {
            $web_dbh->{dbh_sink}->commit();
        }
        else {
            die "FAILED to Update";
        }
    };
    if ( my $err = $@ ) {
        # if it fails will continue anyway it still might work
        $web_dbh->{dbh_sink}->rollback();
        $stopped_sprocs = 0;
        $self->logger->info("Stop the SPROCS: FAILED\n".$err);
    }
    else {
        $self->logger->info("Stop the SPROCS: SUCCEEDED\n");
    }

    my $err_trans   = load_err_translations( $dbh, 'Receive::Upload::DoUpload' );

    # create upload transfer record
    my $transfer_id = insert_upload_transfer({
        dbh         => $dbh,
        upload_date => $self->payload->{due_date},
        operator_id => $APPLICATION_OPERATOR_ID,
        source      => $source,
        sink        => $sink,
        environment => $environment,
        channel_id  => $self->payload->{channel_id},
        upload_id   => $self->payload->{upload_id}
    });

    # Use a separate dbh for logging
    my $db_log_ref  = {
        operator_id => $APPLICATION_OPERATOR_ID,
        transfer_id => $transfer_id,
        dbh_log     => XTracker::Database::db_connection({
            name => 'xtracker', autocommit => 1, connect_object => 'DBI',
        }),
    };

    my $status_ref  = {
        attempted   => 0,
        succeeded   => [],
        failed      => [],
        error_msg   => {}
    };


    $log_msg     = "$dsp_spacer_start\n";
    $log_msg    .= "Upload Id: " . $self->payload->{upload_id} . "\n";
    $log_msg    .= "Upload Date: " . $self->payload->{due_date} . "\n";
    $log_msg    .= "Sales Channel: " . $self->payload->{channel_id} . " - " . $channel->{name} . "\n";
    $log_msg    .= scalar(@{ $self->data->{pids_touse} }) . " products, ";
    $log_msg    .= "source: $source\nsink: $sink (environment: $environment)\n";
    $log_msg    .= "$dsp_spacer\n";
    $log_msg    .= "Beginning transfer: transfer_id $transfer_id\n\n";
    $self->logger->info( $log_msg );


    # get ready to upload

    my @pids_toupload   = @{ $self->data->{pids_touse} };
    my @pids_uploaded;

    my %pid_retries;
    my $max_retries     = 3;
    my $error_flag      = 0;

    my $amq = $self->msg_factory;

    # If the business is NAP then we use the optimized aka "reduced" upload
    use XTracker::Database::Channel 'get_channel';

    my $business_shortname = get_channel($dbh,$self->payload->{channel_id})->{config_section};
    my $use_optimized_upload = use_optimised_upload($business_shortname);

    $self->logger->info("Using optimized upload: ".($use_optimized_upload ? "Yes" : "No"));

    # begin uploading
    while ( my $product_id = shift @pids_toupload ) {

        $self->logger->info(">>>>> Product $product_id\n");

        if ( exists ( $pid_retries{ $product_id } ) ) {
            if ( $pid_retries{ $product_id } > $max_retries ) {
                push @{ $status_ref->{failed} }, $product_id;
                push @{ $status_ref->{error_msg}{ $product_id } }, "Exceeded Max Retries\n";
                $self->logger->info("Exceeded Max Retries for Product $product_id\n");
                $error_flag = 1;
                next;
            }
            else {
                $pid_retries{ $product_id }++;
                $self->logger->info("Retrying (" . $pid_retries{ $product_id } . ") Product $product_id\n");
            }
        }

        usleep(100000);

        ## transfer product data (general: catalogue_product catalogue_attribute catalogue_sku catalogue_pricing catalogue_markdown)

        my $transfer_categories;

        ## If we are using the optimized upload, then we need to trim the amount of categories to upload to the bare minimum
        if ($use_optimized_upload) {
            $transfer_categories = [ "catalogue_product", "catalogue_sku" ];
        } else {
            $transfer_categories = [
                'catalogue_product',    'catalogue_attribute',
                'navigation_attribute', 'list_attribute',
                'catalogue_sku',        'catalogue_pricing',
                'catalogue_markdown'
            ];
        }

        eval {
            $status_ref->{attempted}++;

            my $guard = $schema->txn_scope_guard;

            transfer_product_data({
                    dbh_ref             => $web_dbh,
                    channel_id          => $self->payload->{channel_id},
                    product_ids         => $product_id,
                    skip_navcat         => 1,
                    transfer_categories => $transfer_categories,
                    sql_action_ref      => {map {$_ => {insert => 1}} @$transfer_categories},
                    db_log_ref          => $db_log_ref,
            });

            ## transfer product inventory
            transfer_product_inventory({
                    dbh_ref         => $web_dbh,
                    channel_id      => $self->payload->{channel_id},
                    product_ids     => $product_id,
                    sql_action_ref  => { saleable_inventory => {insert => 1} },
                    db_log_ref      => $db_log_ref,
            });

            if ($web_dbh->{sink_environment} eq 'live') {

                ## transfer product reservations
                transfer_product_reservations({
                    dbh_ref         => $web_dbh,
                    channel_id      => $self->payload->{channel_id},
                    product_ids     => $product_id,
                    db_log_ref      => $db_log_ref,
                    stock_manager   => $stock_manager,
                });

                ## transfer product shipping restrictions

                ## UPOP-46 - This information needs to be sent to WebDB.
                #  Once the new shipment service is created on Product Service,
                #  this transfer category can be removed
                #unless($use_optimized_upload){
                transfer_product_data({
                    dbh_ref             => $web_dbh,
                    channel_id          => $self->payload->{channel_id},
                    product_ids         => $product_id,
                    skip_navcat => 1,
                    transfer_categories => ['catalogue_ship_restriction'],
                    sql_action_ref      => { catalogue_ship_restriction => {insert => 1} },
                });
                #}

                ## set status (live)
                set_xt_product_status( { dbh => $dbh, product_ids => $product_id, live => 1, channel_id => $self->payload->{channel_id} } );

                # Only send messages updating IWS's URL for the product if
                # we're pushing to live
                my $product = $schema->resultset('Public::Product')->find($product_id);
                $amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::PidUpdate', $product );

                # Update PRLs too
                $product->send_sku_update_to_prls({'amq'=>$amq});
            }
            else {
                $self->logger->info("Product reservation transfer skipped - sink_environment is $web_dbh->{sink_environment}\n\n");

                ## set visibility
                set_pws_visibility( { dbh => $web_dbh->{dbh_sink}, product_ids => $product_id, type => 'product', visible => 1 } );
                set_pws_visibility( { dbh => $web_dbh->{dbh_sink}, product_ids => $product_id, type => 'pricing', visible => 1 } );

                ## set status (staging)
                set_xt_product_status( { dbh => $dbh, product_ids => $product_id, staging => 1, channel_id => $self->payload->{channel_id} } );
            }

            $web_dbh->{dbh_sink}->commit();
            $stock_manager->commit();
            $guard->commit;
        };
        if ( my $err = $@ ) {

            $stock_manager->rollback();
            $web_dbh->{dbh_sink}->rollback();

            my $action  = "";

            foreach my $exception ( keys %exceptions ) {
                if ( $err =~ /$exception/ ) {
                    $action = $exceptions{$exception};
                    last;
                }
            }

            if ( $action eq "retry" ) {
                push @pids_toupload, $product_id;
                $pid_retries{ $product_id } = 0         if ( !exists $pid_retries{ $product_id } );
                push @{ $status_ref->{error_msg}{ $product_id } }, translate_error( $err_trans, $err );
                $self->logger->info("Scheduled for Retry: $product_id");
            }
            else {
                push @{ $status_ref->{failed} }, $product_id;

                push @{ $status_ref->{error_msg}{ $product_id } }, translate_error( $err_trans, $err );

                $self->logger->info("Product data transfer ** Rolled Back **: $product_id\n\n");

                $self->logger->error("Error! Product: $product_id - $err\n");

                $error_flag = 1;
            }
        }
        else {
            push @{ $status_ref->{succeeded} }, $product_id;
            $self->logger->info("Product data transfer committed: $product_id\n\n");
        }
    } continue {
        $self->logger->info("Product $product_id <<<<<\n\n");
    }

    # if the SPROCS were stopped in the first place then start them again
    if ( $stopped_sprocs ) {
        eval {
            if ( toggle_the_sprocs( $web_dbh, 'on', \%exceptions ) ) {
                $web_dbh->{dbh_sink}->commit();
            }
            else {
                die "FAILED to Update";
            }
        };
        if ( my $err = $@ ) {
            $web_dbh->{dbh_sink}->rollback();
            $self->logger->info("Start the SPROCS: FAILED\n".$err);
        }
        else {
            $self->logger->info("Start the SPROCS: SUCCEEDED\n");
        }
    }

    $web_dbh->{dbh_sink}->disconnect();

    $self->logger->info("Transfer done: upload_date " . $self->payload->{due_date} . "; transfer_id " . $transfer_id . "\n\n");

    # Promote the products to live in the product service
    if (@{ $status_ref->{succeeded} }
            && !config_var('ProductService','disabled')) {
            # need to update product service.
            # how depends on live or not
            if ( $environment eq 'live' ) {

                # We want to notify about the succesful PIDs and the live PIDs
                # The assumption is that the live PIDs were part of a part-failed
                # upload. They would not have been noticed by the product service
                # so we re-send them now.
                my @pids;

                push @pids,@{ $status_ref->{succeeded} }
                    if ( scalar(@{ $status_ref->{succeeded} }) );

                push @pids,@{ $self->data->{pids_live} }
                    if ( scalar(@{ $self->data->{pids_live} }) );

                # live: promote to live and remove any preorder tag
                $amq->transform_and_send( 'XT::DC::Messaging::Producer::ProductService::Upload', {
                    channel_id  => $self->payload->{channel_id},
                    pids        => \@pids,
                    upload_date => $self->payload->{due_date},
                    upload_timestamp => DateTime->now->iso8601,
                    remove_product_tags => [ 'preorder' ],
                } );
            }
    }

    # Turn off the pre_order flag in XT once product is uploaded to live
    if ( @{$self->data->{pids_touse}} && $environment eq 'live' ) {
        foreach my $pid ( @{$self->data->{pids_touse}} ) {
            # Get product attribute row for $pid
            my $product_attribute = $schema->resultset('Public::ProductAttribute')->search(
                {
                    product_id => $pid,
                }
            );

            $product_attribute->update({ pre_order => 0 });
        }
    }

    ## build status message and summary data
    my $transfer_summary_ref    = {
                            transfer_id     => $transfer_id,
                            summary_records => [ {
                                category            => 'general',
                                num_pids_attempted  => scalar(@{ $self->data->{pids_touse} }),
                                num_pids_succeeded  => scalar(@{ $status_ref->{succeeded} }),
                                num_pids_failed     => scalar(@{ $status_ref->{failed} })
                            } ]
                        };

    $log_msg     = "\nData transfer (general) succeeded for " . scalar(@{ $status_ref->{succeeded} }) . " of " . scalar(@{ $self->data->{pids_touse} });
    $log_msg    .= ":-\n@{ [ join( ', ', @{ $status_ref->{succeeded} } ) ] }"       if ( scalar(@{ $status_ref->{succeeded} }) );
    $log_msg    .= "\nData transfer (general) failed for " . scalar(@{ $status_ref->{failed} }) . " of " . scalar(@{ $self->data->{pids_touse} });
    $log_msg    .= ":-\n@{ [ join( ', ', @{ $status_ref->{failed} } ) ] }"          if ( scalar(@{ $status_ref->{failed} }) );
    $log_msg    .= "\n\n";
    $self->logger->info( $log_msg );


    # set transfer status and set-up data hash for messages back to operator & Fulcrum
    if ( $error_flag ) {
        $transfer_status    = $UPLOAD_TRANSFER_STATUS__COMPLETED_WITH_ERRORS;
        $self->data->{complete_errors}{pids_loaded} = $status_ref->{succeeded};
        $self->data->{complete_errors}{pids_failed} = $status_ref->{failed};
        $self->data->{complete_errors}{pid_errors}  = $status_ref->{error_msg};
    }
    else {
        $transfer_status    = $UPLOAD_TRANSFER_STATUS__COMPLETED_SUCCESSFULLY;
        $self->data->{completed}{pids_loaded}       = $status_ref->{succeeded};
    }

    # update transfer and insert a summary record
    set_upload_transfer_status({
        dbh         => $dbh,
        transfer_id => $transfer_id,
        status_id   => $transfer_status
    });

    insert_upload_transfer_summary({
        dbh                 => $dbh,
        summary_data_ref    => $transfer_summary_ref
    });

    # send messages to operator & Fulcrum
    _process_message( $self, $job );


    # create job requests for Related Products & What's New if appropriate
    my $job_rq;
    my $payload;

    if ( !$use_optimized_upload #Only process the related products when not using the optimised upload
         && ( scalar( @{ $status_ref->{succeeded} } )
              || scalar( @{ $self->data->{pids_live} } ) )
       ){
        my @pids;

        push @pids,@{ $status_ref->{succeeded} }            if ( scalar(@{ $status_ref->{succeeded} }) );
        push @pids,@{ $self->data->{pids_live} }            if ( scalar(@{ $self->data->{pids_live} }) );

        $job_rq = XT::JQ::DC->new({ funcname => 'Receive::Upload::RelatedProducts' });
        $payload= {
                operator_id => $self->payload->{operator_id},
                channel_id  => $self->payload->{channel_id},
                upload_id   => $self->payload->{upload_id},
                due_date    => $self->payload->{due_date},
                environment => $environment,
                pids        => \@pids
            };
        # Add colour variation data as it is no longer stored in XTracker
        $payload->{colour_variations} = $self->data->{colour_variations}
            if scalar @{$self->data->{colour_variations}};

        # TODO: We actually don't need to store 'wear it with' related product info in XTracker either
        # Should refactor this and then delete the 'recommended_product' table and associated tables;

        $job_rq->set_payload( $payload );
        my $result  = $job_rq->send_job();

        $self->logger->info("Related Products Job Created, Job Id: " . $result->jobid . "\n");
    }

    if ( ( $transfer_status == $UPLOAD_TRANSFER_STATUS__COMPLETED_SUCCESSFULLY ) || ( $environment eq "staging" ) ) {

        my $status = ( $environment eq "staging" )  ? 'WhatsNewStaging' : 'WhatsNewLive' ;

        $job_rq = XT::JQ::DC->new({ funcname => 'Send::Upload::Status' });
        $payload= {
                upload_id   => $self->payload->{upload_id},
                operator_id => $self->payload->{operator_id},
                channel_id  => $self->payload->{channel_id},
                due_date    => $self->payload->{due_date},
                environment => $environment,
                status      => $status,
            };
        $job_rq->set_payload( $payload );
        my $result  = $job_rq->send_job();

        $self->logger->info("WhatsNew Job Created, Job Id: " . $result->jobid . "\n");
    }

    # If pids failed log the errors, to help diagnose upload issues.
    if ( $self->data->{complete_errors}{pids_failed}
            && ref($self->data->{complete_errors}{pids_failed}) eq "ARRAY"
            && @{ $self->data->{complete_errors}{pids_failed} } ) {

        my $pids_failed = join(',', @{ $self->data->{complete_errors}{pids_failed} });

        my $upload_list_error = sprintf(
            "Upload Error (Upload List ID: %d ) - The following PIDs were NOT uploaded: ( %s )",
            $self->payload->{upload_id}, $pids_failed
        );

        $self->logger->error($upload_list_error);

        foreach my $pid_failed ( @{ $self->data->{complete_errors}{pids_failed} } ) {
            # Multiple error messages for a product are allowed
            my $pid_errors = join(", ", @{$self->data->{complete_errors}{pid_errors}{$pid_failed} } );

            my $log_pid_failed = sprintf(
                "Product %d failed to upload - %s",
                $pid_failed, $pid_errors
            );

            $self->logger->error($log_pid_failed);
        }
    }

    $log_msg = $error_flag ? "Uh-oh!  Looks like there were errors." : "*** END ***";

    $self->logger->info("$log_msg$dsp_spacer_end\n\n");
}

=head2 _validate_pids
    usage       : $boolean = _validate_pids( $self, $job );
    description : Validates the PIDs and other parts of the payload to make
                  sure that it OK to proceed with the UpLoad. It returns
                  either a 1 (ok) or 0 (not ok).
    parameters  : The pointer to the worker where the payload can be accessed
                  and the pointer to the job which is being processed.
    returns     : Boolean value either 1 or 0.
=cut

sub _validate_pids {
    my ( $self, $job )  = @_;

    my $fatal_error = 0;
    my @error_msg;

    my @pids_notfound;
    my @wrong_channel;
    my @pids_touse;
    my @pids_live;
    my @pids_wrongdate;
    my @pids_unknown;

    # pointer to info about the PIDs
    my $prods = $self->data->{prods};

    # check for some basic errors with the payload
    if ( !defined $self->data->{operator} ) {
        # can't find operator
        $fatal_error++;
        $self->data->{error}{no_op_id}          = 1;
        push @error_msg, "Unknown Operator Id: ".$self->payload->{operator_id}.".";
    }
    if ( $self->payload->{pid_count} != @{ $self->payload->{pids} } ) {
        # mismatch with the pid count and the actual count of pids passed
        $fatal_error++;
        $self->data->{error}{pidcount_mismatch} = 1;
        push @error_msg,
            "PID Count ("
          . $self->payload->{pid_count}
          . ") does not equal Number of PIDs Passed in Array ("
          . scalar @{ $self->payload->{pids} }
          . ").";
    }

    my $dbh = $self->schema->storage->dbh;
    # go through products and see DC has them and they are in the correct
    # channel, upload date matches and aren't live already
    if ( scalar( keys %$prods ) ) {
        PID:
        foreach my $pid ( @{ $self->_pids_from_payload } ) {
            my $env = $self->payload->{environment};
            my $channel_id = $self->payload->{channel_id};
            # $prods contains details about pids from the database
            my $xt_product = $prods->{$pid};
            my $db_upload_date = $xt_product->{upload_date};


            if (ref($xt_product) eq 'HASH') {

                # Prevent non-transferred products to be pushed to live
                if ( $env eq 'live'
                 and $xt_product->{channel_id} != $channel_id ) {
                    push @wrong_channel, $pid;
                    $fatal_error++;
                    next PID;
                }

                # Get the product's upload date, check if it matches the payload's due date
                my($upload_date_dmy) = $db_upload_date =~ m{(.*) .*};
                if ( defined $db_upload_date
                 and $self->payload->{due_date} eq $upload_date_dmy
                ) {
                    if ( $xt_product->{live} ) {
                        push @pids_live, $pid;
                    }
                    else {
                        push @pids_touse, $pid;
                    }
                    next PID;
                }

                # Product's upload date is not set - set it to the 'due_date' in the payload
                if (!defined $db_upload_date
                    || $db_upload_date eq ""
                    # set the date to that of the payload if it doesn't match
                    # match the one in the db
                    || $self->payload->{due_date} ne $upload_date_dmy
                ) {
                    eval {
                        set_upload_date( $dbh, {
                            date        => $self->payload->{due_date},
                            product_id  => $pid,
                            channel_id  => $xt_product->{channel_id},
                        });
                        if ( $xt_product->{live} ) {
                            push @pids_live, $pid;
                        }
                        else {
                            push @pids_touse, $pid;
                        }
                    };
                    if ( my $err = $@ ) {
                        chomp($err);
                        $self->jq_logger->warn(
                            "$pid - Error updating date: $err\n" );
                        push @pids_wrongdate,
                            "$pid - Error updating date: $err";
                        $fatal_error++;
                    }
                    next PID;
                }

                if( $env eq 'staging' ) {
                    push @pids_touse, $pid;
                    next PID;
                }

                # the test is 3 "if"s above
                $self->jq_logger->warn("$pid - Unknown error\n");
                push @pids_unknown, "$pid - Unknown error";
                $fatal_error++;
                next PID;
            }

            # If we get here the pid wasn't found
            push @pids_notfound, $pid;
            $fatal_error++;
            next PID;
        }
    }
    else {
        # none of the products passed were in the DC
        $fatal_error++;
        push @error_msg, "No PIDs were Found on DC.";
        $self->data->{error}{no_pids_found} = 1;
    }

    # check for transfers in-progress for the specified upload date and sales
    # channel (i.e. make sure two uploads don't kick off at the same time)
    my $upload_transfers_ref = get_upload_transfers({
        dbh => $dbh,
        select_by => {
            fname => 'upload_date',
            value => $self->payload->{due_date},
        }
    });
    if ($self->payload->{environment} eq 'live') {
        foreach my $transfer_ref ( @{ $upload_transfers_ref } ) {
            if ( ($transfer_ref->{transfer_status_id} == $UPLOAD_TRANSFER_STATUS__IN_PROGRESS)
                && ($transfer_ref->{channel_id}         == $self->payload->{channel_id})
                && ($transfer_ref->{environment} eq 'live')
                ) {

                if ( $transfer_ref->{upload_id} == $self->payload->{upload_id} ) {
                    $fatal_error++;
                    push @error_msg,
                        "xTracker indicates that this upload has already been scheduled to run and is still running.";
                    $self->data->{error}{upload_duped} = $transfer_ref->{id};
                }
                else {
                    $fatal_error++;
                    push @error_msg,
                        "xTracker indicates that there is already a transfer in progress for Upload Date "
                      . $self->payload->{due_date}
                      . " (transfer_id $transfer_ref->{id})"
                      . " and Sales Channel: "
                      . $self->data->{channels}{ $self->payload->{channel_id} }{name}
                      . q{.};
                    $self->data->{error}{upload_inprogress} = $transfer_ref->{id};
                }
            }
        }
    }

    if ( $fatal_error ) {
        # can't proceed with UpLoad

        $self->logger->error("ERROR: $fatal_error");

        $self->data->{error}{err_count}         = $fatal_error;
        $self->data->{error}{msg}               = \@error_msg      if ( @error_msg );

        $self->data->{error}{pids_notfound}     = \@pids_notfound  if ( @pids_notfound );
        $self->data->{error}{pids_wrongdate}    = \@pids_wrongdate if ( @pids_wrongdate );
        $self->data->{error}{pids_unknown}      = \@pids_unknown  if ( @pids_unknown);
        $self->data->{error}{pids_wrongchannel} = \@wrong_channel  if ( @wrong_channel );
        $self->data->{error}{pids_touse}        = \@pids_touse     if ( @pids_touse );
        $self->data->{error}{pids_live}         = \@pids_live      if ( @pids_live );

        return 0;
    }
    else {
        # safe to proceed with UpLoad

        $self->logger->debug(
            "No Errors, PIDs already Live: "
          . scalar(@pids_live)
          . ", PIDs to Upload: "
          . scalar(@pids_touse)
        );

        $self->data->{pids_touse} = \@pids_touse;
        $self->data->{pids_live}  = \@pids_live;

        return 1;
    }
}

=head2 _process_message
    usage       : _process_message( $self, $job );
    description : This processes the messages that need to be sent to the
                  operator who instigated the UpLoad and Fulcrum to tell them
                  the status of the UpLoad.  It will process messages for
                  Fatal Errors, Partial Completion and Complete Completion of
                  the UpLoad.
    parameters  : The pointer to the worker where the payload can be accessed
                  and the pointer to the job which is being processed.
    returns     : Nothing.
=cut

sub _process_message {
    my ( $self, $job )  = @_;

    my %message         = (
            recipient_id        => $self->payload->{operator_id},
            sender_id           => $APPLICATION_OPERATOR_ID
        );

    # Speak to fulcrum in all cases except repetition of failures
    # my $speak_to_fulcrum= ( $self->payload->{environment} eq 'live' ? 1 : 0 );
    my $speak_to_fulcrum= 1;
    my %to_fulcrum      = (
            upload_id           => $self->payload->{upload_id},
        );


    my $msg_text        = "";
    my $msg_sep         = "";
    my $sales_channel   = $self->data->{channels}{ $self->payload->{channel_id} }{name};

    my $job_rq;
    my $payload;

    my $upload_id   = $self->payload->{upload_id};
    my $due_date    = $self->payload->{due_date};
    my $dc_name     = $self->data->{xt_dc_name};
    my $dc_instance = uc($self->data->{xt_instance});
    my $environment = uc($self->payload->{environment});

    my $subject_suffix  = ' Id '.$upload_id.', Due '.$due_date.' for '.$sales_channel.' '.$dc_instance.' @ '.$dc_name;


    # the validate_pids function failed and no products were uploaded
    if ( exists $self->data->{error} ) {

        my %problem_pids    = (
                pids_notfound       => 'The following PIDs were not found on the DC system:',
                pids_wrongdate      => 'The following PIDs were not for the due date:',
                pids_wrongchannel   => 'The following PIDs were not for the sales channel:',
                pids_unknown        => 'An unknown error occurred for these PIDs:',
            );

        $message{subject}   = 'ERROR with Upload:' . $subject_suffix;

        $msg_text   =<<MSG
There has been a problem with this upload and it has NOT been run.

MSG
;
        # output any error messages
        if ( exists $self->data->{error}{msg} ) {
            my $errors  = join( "\n", @{ $self->data->{error}{msg} } );
            $msg_text   .=<<MSG
There have been the following errors:
$errors

MSG
;
        }

        # output any problems with PIDs
        foreach ( sort keys %problem_pids ) {
            if ( exists $self->data->{error}{$_} ) {
                my $pids        = join( "\n", @{ $self->data->{error}{$_} } );
                my $pid_count   = scalar(@{ $self->data->{error}{$_} });
                $msg_text       .=<<MSG
$problem_pids{$_} ($pid_count pids)
$pids

MSG
;
            }
        }

        # set the status so that Fulcrum can take the appropriate action
        $to_fulcrum{status} = 'Failed';

        # don't need to tell Fulcrum that this job has failed if it is a duplicate request
        $speak_to_fulcrum   = 0         if ( (exists $self->data->{error}{upload_duped}) && ($self->data->{error}{err_count} == 1) );
    }

    # upload completed but with errors
    if ( exists $self->data->{complete_errors} ) {
        $message{subject}   = 'Upload Succeeded with ERRORS:' . $subject_suffix;

        $msg_text   =<<MSG
The Upload has run and completed but there were problems with some products which were not uploaded.

MSG
;

        if ( scalar(@{ $self->data->{complete_errors}{pids_failed} }) ) {
            $msg_text   .= "The following PIDs were NOT uploaded: (" . scalar(@{ $self->data->{complete_errors}{pids_failed} }) . " pids)\n";
            $msg_text   .= join(
                q{}, map {
                    "$_:\n Error: "
                  . join( " Error: ", @{ $self->data->{complete_errors}{pid_errors}{$_} } )
                } @{ $self->data->{complete_errors}{pids_failed} }
            );
            $msg_sep    = "\n";
        }

        $msg_text   .= $msg_sep;
        $msg_text   .= "The following PIDs WERE uploaded: (" . scalar(@{ $self->data->{complete_errors}{pids_loaded} }) . " pids)\n";
        if ( scalar(@{ $self->data->{complete_errors}{pids_loaded} }) ) {
            $msg_text   .= join( "\n", @{ $self->data->{complete_errors}{pids_loaded} } );
            $msg_text   .= "\n\n";
            $msg_text   .= "Related Products will now be loaded for these PIDs, you will receive another message shortly when this has finished.\n";
        }

        if ( scalar(@{ $self->data->{pids_live} }) ) {
            $msg_text   .= "\n";
            $msg_text   .= "The following PIDs were skipped as they are already LIVE: (" . scalar(@{ $self->data->{pids_live} }) . " pids)\n";
            $msg_text   .= join( "\n", @{ $self->data->{pids_live} } );
        }

        $to_fulcrum{status}         = 'Part Uploaded';
        $to_fulcrum{completed_pids} = $self->data->{complete_errors}{pids_loaded};
    }

    # upload completed and with no errors
    if ( exists $self->data->{completed} ) {
        $message{subject}   = 'Upload Completed:' . $subject_suffix;

        $msg_text   =<<MSG
The Upload has run and completed with no errors.

MSG
;
        $msg_text   .= "The following PIDs have been uploaded: (" . scalar(@{ $self->data->{completed}{pids_loaded} }) . " pids)\n";
        if ( scalar(@{ $self->data->{completed}{pids_loaded} }) ) {
            $msg_text   .= join( "\n", @{ $self->data->{completed}{pids_loaded} } );
            $msg_text   .= "\n\n";
            $msg_text   .= "Related Products will now be loaded for these PIDs, you will receive another message shortly when this has finished.\n";
        }

        if ( scalar(@{ $self->data->{pids_live} }) ) {
            $msg_text   .= "\n";
            $msg_text   .= "The following PIDs were skipped as they are already LIVE: (" . scalar(@{ $self->data->{pids_live} }) . " pids)\n";
            $msg_text   .= join( "\n", @{ $self->data->{pids_live} } ) . "\n";
        }

        $msg_text   .= "\n";
        $msg_text   .= "The 'What's New' list of products will now be loaded, you will receive a seperate message when this has finished.";

        $to_fulcrum{status}         = 'Complete';
        $to_fulcrum{completed_pids} = $self->data->{completed}{pids_loaded};
    }


    $msg_text   =<<MSG
Upload Id     : $upload_id, Due: $due_date @ $dc_name
Sales Channel : $sales_channel $dc_instance
Environment   : $environment

$msg_text
MSG
;
    $msg_text   =~ s/[\n]/<br\/>/g;
    $message{body}  = $msg_text;


    # send a message to the operator who instigated the upload
    $job_rq = XT::JQ::DC->new({ funcname => 'Send::Operator::Message' });
    $payload= [ \%message ];
    $job_rq->set_payload( $payload );
    $job_rq->send_job();
    my $fulcrum_host = fulcrum_hostname();

    # send an email to the operator who instigated the upload if address known
    if ( ($self->data->{operator}{email_address} // "") ne "" ) {
        my $email_msg   = "";
        my $action      = ( exists $self->data->{completed} ? "" : "\n\n*** ACTION NEEDS TO BE TAKEN ***" );
        my $subject     = ( exists $self->data->{completed} ? $message{subject} : $message{subject}." - "."*** ACTION NEEDS TO BE TAKEN ***" );

        $email_msg  =<<EMAIL_MSG
Upload Id     : $upload_id, Due: $due_date @ $dc_name
Sales Channel : $sales_channel $dc_instance
Environment   : $environment

$message{subject}$action

To see more details please log into Fulcrum and look at your messages.

Click here: http://${fulcrum_host}/my/messages



If the above link doesn't work then follow these steps to see your messages:

- Login to Fulcrum
- Click on 'My' main menu option
- Select 'Messages' from the drop down menu

You should now see your messages.
EMAIL_MSG
;

        send_email( lc("xt-upload.".$self->data->{xt_instance}.".$dc_name\@net-a-porter.com"), "", $self->data->{operator}{email_address}, $subject, $email_msg );
    }

    if ( $speak_to_fulcrum ) {
        # send notification to Fulcrum that the upload has finished and at what status
        if( $self->payload->{environment} eq 'staging' ) {
            $to_fulcrum{status}         = 'Staging';
        }

        $job_rq = XT::JQ::DC->new({ funcname => 'Send::Upload::Status' });
        $payload= \%to_fulcrum;
        $job_rq->set_payload( $payload );
        $job_rq->send_job();
    }
}


1;


=head1 NAME

XT::JQ::DC::Receive::Upload::DoUpload - Received from Fulcrum

=head1 DESCRIPTION

This receives a Go Live for an Upload from Fulcrum and then
uploads the products in the 'pids' array.

{
   operator_id  => $id,
   channel_id   => $id,
   upload_id    => $id,
   due_date     => 'yyyy-mm-dd',
   pid_count    => $int,
   pids         => [ { pid => $pid1, colour_variations => [$pid2, $pid3] }
                     { pid => $pid2},
                     ... ],
   environment  => 'live'
}
