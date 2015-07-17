package XT::JQ::DC::Receive::Upload::RelatedProducts;

use Moose;

use Moose::Util::TypeConstraints;
use MooseX::Types::Moose            qw( Str Int ArrayRef );
use MooseX::Types::Structured       qw( Dict Optional );

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';

use XTracker::Comms::DataTransfer   qw( :upload_transfer :transfer_handles :transfer toggle_the_sprocs );
use XTracker::Comms::FCP qw( create_fcp_related_product ensure_fcp_related_products_fully_connected );

use XTracker::Database::Product     qw( get_products_info_for_upload );
use XTracker::Database::Operator    qw( get_operator_by_id );
use XTracker::Database::Channel     qw( get_channels );

use XTracker::Constants             qw( :application );

use XTracker::Config::Local         qw( config_var );
use XTracker::Logfile               qw( xt_logger );
use XTracker::EmailFunctions        qw( send_email );
use XTracker::Utilities             qw( :err_translations );

use Time::HiRes                     qw( usleep );
use List::MoreUtils;


has payload => (
    is => 'ro',
    isa => Dict[
        operator_id         => Int,
        channel_id          => Int,
        upload_id           => Int,
        due_date            => Str,
        environment         => enum([ qw( live staging ) ]),
        pids                => ArrayRef[Int],
        colour_variations   => Optional[ArrayRef[
            Dict[
                pid => Int,
                colour_variations => ArrayRef[Int],
            ]
        ]],
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

    $self->data->{operator}     = get_operator_by_id( $self->dbh, $self->payload->{operator_id} );
    $self->data->{channels}     = get_channels( $self->dbh );


    # if channel id can't be found then assume job is for the other side of the pond
    if ( !exists $self->data->{channels}{ $self->payload->{channel_id} } ) {
        return ();
    }

    # map colour variations into a hash keyed on pid. More useful that way
    if ($self->payload->{colour_variations}){
        $self->data->{colour_variations} = { map {$_->{pid} => $_->{colour_variations}} @{$self->payload->{colour_variations}} };
    }


    _do_the_transfer( $self, $job );

    return ();
}

sub check_job_payload { () }


### Subroutine : _do_the_transfer                                 ###
# usage        : _do_the_transfer( $self, $job );                   #
# description  : This transfers the related products for an upload  #
#                to the appropriate web-site.                       #
# parameters   : The pointer to the worker where the payload can be #
#                accessed and the pointer to the job which is being #
#                processed.                                         #
# returns      : Nothing.                                           #

sub _do_the_transfer {
    my ( $self, $job )  = @_;

    my $source          = "xt_" . lc($self->data->{xt_instance});
    my $sink            = "pws_" . lc($self->data->{xt_instance});
    my $channel         = $self->data->{channels}{ $self->payload->{channel_id} };
    my $web_dbh;

    my $log_msg         = "";
    my $dsp_spacer_start= "\n" . '>' x 80 . "\n";   #
    my $dsp_spacer_end  = "\n" . '<' x 80 . "\n";   # for log display
    my $dsp_spacer      = "\n" . '~' x 80 . "\n";   #

    # list of errors that can happen when uploading data to the PWS which mean the PID can be retried
    my %exceptions  = (
        'Deadlock'              => 'retry',
        'Lock wait'             => 'retry',
        'server has gone away'  => 'retry',
    );

    my $stopped_sprocs  = 0;


    # get transfer DB handle
    eval {
        $web_dbh    = get_transfer_db_handles( { source_type => 'transaction', environment => $self->payload->{environment}, channel => $channel->{config_section} } );
    };
    if ( $@ ) {
        $job->failed( $@ );
        return;
    }

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

    my $err_trans   = load_err_translations( $self->dbh, 'Receive::Upload::RelatedProducts' );

    # prepare to transfer related products
    my @pids_touse      = @{ $self->payload->{pids} };
    my @pids_succeeded;
    my @pids_failed;
    my %pid_errors;
    my $colour_variations = $self->data->{colour_variations} ? $self->data->{colour_variations} : {};
    my $cid = $self->payload->{channel_id};

    my %pid_retries;
    my $max_retries     = 3;
    my $error_flag      = 0;


    $log_msg     = "$dsp_spacer_start\n";
    $log_msg    .= "Upload Id: " . $self->payload->{upload_id} . "\n";
    $log_msg    .= "Upload Date: " . $self->payload->{due_date} . "\n";
    $log_msg    .= "Sales Channel: " . $cid . " - " . $channel->{name} . "\n";
    $log_msg    .= scalar(@pids_touse) . " products, ";
    $log_msg    .= "source: $source\nsink: $sink (environment: " . $self->payload->{environment} . ")\n";
    $log_msg    .= "$dsp_spacer\n";
    $log_msg    .= "Beginning Related Products transfer: upload_id " . $self->payload->{upload_id} . "\n\n";
    $self->logger->info( $log_msg );

    # begin transfer
    while ( my $product_id = shift @pids_touse ) {

        $self->logger->info(">>>>> Product $product_id\n");

        if ( exists ( $pid_retries{ $product_id } ) ) {
            if ( $pid_retries{ $product_id } > $max_retries ) {
                push @pids_failed, $product_id;
                push @{ $pid_errors{$product_id} }, 'Exceeded Max Retries';
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

        eval {

            transfer_product_data({
                dbh_ref             => $web_dbh,
                product_ids         => $product_id,
                transfer_categories => 'related_product',
                sql_action_ref      => { related_product => {insert => 1} },
                channel_id          => $cid,
            });
            my $schema = $self->schema;
            # Don't bother doing this for staging environment as it slows down
            # the upload
            if ( $self->payload->{environment} eq 'live' ) {
                # MRPBLK-305 - This code will create links for any products that
                # are already live that need linking to this product
                my $product_channel = $schema->resultset('Public::ProductChannel')
                                            ->search({
                                                product_id => $product_id,
                                                channel_id => $cid,
                                            })->slice(0,0)
                                            ->single;
                my $recommended_products
                    = $product_channel->get_recommended_with_live_products;
                while ( my $recommended_product = $recommended_products->next ) {
                    create_fcp_related_product(
                        $web_dbh->{dbh_sink},
                        { product_id => $recommended_product->product_id,
                        related_product_id => $recommended_product->recommended_product_id,
                        type_id => 'Recommended',
                        position => $recommended_product->slot,
                        sort_order => $recommended_product->sort_order, },
                    );
                }
            }

            if ($colour_variations->{$product_id}) {
                # Has some colour variations

                # Make sure we have included "this" product ID in the set
                # of products to link
                my @colour_variation_product_ids = List::MoreUtils::uniq(
                    $product_id, @{ $colour_variations->{$product_id} }
                );

                # There have to be at least two products before any links
                # can be made
                if (scalar @colour_variation_product_ids >= 2) {
                    ensure_fcp_related_products_fully_connected(
                        dbh         => $web_dbh->{dbh_sink},
                        product_ids => \@colour_variation_product_ids,
                        type_id     => 'COLOUR'
                    );
                }
            }

            if ( $web_dbh->{dbh_sink}->commit() ) {
                $self->logger->info("Product data transfer (related products) committed: $product_id\n\n");
            }

            push @pids_succeeded, $product_id;

        };
        if ( my $err = $@ ) {
            $web_dbh->{dbh_sink}->rollback();

            my $action  = "";

            # see if error is a known exception
            foreach my $exception ( keys %exceptions ) {
                if ( $err =~ /$exception/ ) {
                    $action = $exceptions{$exception};
                    last;
                }
            }

            # if the error is not fatal then retry the PID
            if ( $action eq "retry" ) {
                push @pids_succeeded, $product_id;
                $pid_retries{ $product_id } = 0         if ( !exists $pid_retries{ $product_id } );
                push @{ $pid_errors{ $product_id } }, translate_error( $err_trans, $err );
                $self->logger->info("Scheduled for Retry: $product_id");
            }
            else {
                $self->logger->info("Product data transfer (related products) ** Rolled Back **: $product_id\n\n");
                $self->logger->debug("Error! Product: $product_id - $err\n");

                push @pids_failed, $product_id;
                push @{ $pid_errors{ $product_id } }, translate_error( $err_trans, $err );
                $error_flag = 1;
            }
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

    $self->logger->info("Related Products transfer done: upload_date " . $self->payload->{due_date} . "; Upload Id " . $self->payload->{upload_id} . "\n\n");

    $log_msg     = "\nRelated Products transfer succeeded for " . scalar(@pids_succeeded) . " of " . scalar(@{ $self->payload->{pids} });
    $log_msg    .= ":-\n@{ [ join( ', ', @pids_succeeded ) ] }"         if ( scalar(@pids_succeeded) );
    $log_msg    .= "\nRelated Products transfer failed for " . scalar(@pids_failed) . " of " . scalar(@{ $self->payload->{pids} });
    $log_msg    .= ":-\n@{ [ join( ', ', @pids_failed ) ] }"            if ( scalar(@pids_failed) );
    $log_msg    .= "\n\n";
    $self->logger->info( $log_msg );

    if ( $error_flag ) {
        $self->data->{complete_errors}{pids_succeeded}  = \@pids_succeeded;
        $self->data->{complete_errors}{pids_failed}     = \@pids_failed;
        $self->data->{complete_errors}{pid_errors}      = \%pid_errors;
    }
    else {
        $self->data->{completed}{pids_succeeded}        = \@pids_succeeded;
    }

    _process_message( $self, $job );

    $log_msg    = $error_flag ? "Uh-oh!  Looks like there were errors." : "*** END ***";
    $self->logger->info("$log_msg$dsp_spacer_end\n\n");
}


### Subroutine : _process_message                                 ###
# usage        : _process_message( $self, $job );                   #
# description  : This processes the messages that need to be sent   #
#                to the operator who instigated the UpLoad and      #
#                Fulcrum to tell them the status of the UpLoad.     #
#                It will process messages for Fatal Errors, Partial #
#                Completion and Complete Completion of the UpLoad.  #
# parameters   : The pointer to the worker where the payload can be #
#                accessed and the pointer to the job which is being #
#                processed.                                         #
# returns      : Nothing.                                           #

sub _process_message {
    my ( $self, $job )  = @_;

    my %message         = (
            recipient_id        => $self->payload->{operator_id},
            sender_id           => $APPLICATION_OPERATOR_ID
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

    my $subject_suffix  = ' Upload Id '.$upload_id.', Due '.$due_date.' for '.$sales_channel.' '.$dc_instance.' @ '.$dc_name;


    # transfer completed but with errors
    if ( exists $self->data->{complete_errors} ) {
        $message{subject}   = 'Related Products transfer Succeeded with ERRORS:' . $subject_suffix;

        $msg_text   =<<MSG
The Related Products transfer has run and completed but there were problems with some products which were not transferred.

MSG
;

        if ( scalar(@{ $self->data->{complete_errors}{pids_failed} }) ) {
            $msg_text   .= "The following PIDs were NOT transferred: (" . scalar(@{ $self->data->{complete_errors}{pids_failed} }) . " pids)\n";
            $msg_text   .= join(
                q{}, map {
                    "$_:\nE: "
                  . join( "E: ", @{ $self->data->{complete_errors}{pid_errors}{$_} } )
                } @{ $self->data->{complete_errors}{pids_failed} }
            );
            $msg_sep    = "\n";
        }

        $msg_text   .= $msg_sep;
        $msg_text   .= "The following PIDs WERE transferred: (" . scalar(@{ $self->data->{complete_errors}{pids_succeeded} }) . " pids)\n";
        if ( scalar(@{ $self->data->{complete_errors}{pids_succeeded} }) ) {
            $msg_text   .= join( "\n", @{ $self->data->{complete_errors}{pids_succeeded} } );
        }
    }

    # transfer completed and with no errors
    if ( exists $self->data->{completed} ) {
        $message{subject}   = 'Related Products transfer Completed:' . $subject_suffix;

        $msg_text   =<<MSG
The Related Products transfer has run and completed with no errors.

MSG
;
        $msg_text   .= "The following PIDs have been transferred: (" . scalar(@{ $self->data->{completed}{pids_succeeded} }) . " pids)\n";
        if ( scalar(@{ $self->data->{completed}{pids_succeeded} }) ) {
            $msg_text   .= join( "\n", @{ $self->data->{completed}{pids_succeeded} } );
        }
    }


    $msg_text   =<<MSG
Upload Id     : $upload_id, Due: $due_date @ $dc_name
Sales Channel : $sales_channel $dc_instance
Environment   : $environment

$msg_text
MSG
;
    $msg_text       =~ s/[\n]/<br\/>/g;
    $message{body}  = $msg_text;


    # send a message to the operator who instigated the upload
    $job_rq = XT::JQ::DC->new({ funcname => 'Send::Operator::Message' });
    $payload= [ \%message ];
    $job_rq->set_payload( $payload );
    $job_rq->send_job();

    # send an email to the operator who instigated the upload if address known
    if ( $self->data->{operator}{email_address} ne "" ) {
        my $email_msg   = "";
        my $action      = ( exists $self->data->{completed} ? "" : "\n\n*** ACTION NEEDS TO BE TAKEN ***" );
        my $subject     = ( exists $self->data->{completed} ? $message{subject} : $message{subject}." - "."*** ACTION NEEDS TO BE TAKEN ***" );

        $email_msg  =<<EMAIL_MSG
Upload Id     : $upload_id, Due: $due_date @ $dc_name
Sales Channel : $sales_channel $dc_instance
Environment   : $environment

$message{subject}$action

To see more details please log into Fulcrum and look at your messages.

Click here: http://fulcrum.net-a-porter.com/my/messages



If the above link doesn't work then follow these steps to see your messages:

- Login to Fulcrum
- Click on 'My' main menu option
- Select 'Messages' from the drop down menu

You should now see your messages.
EMAIL_MSG
;

        send_email( lc("xt-upload.".$self->data->{xt_instance}.".$dc_name\@net-a-porter.com"), "", $self->data->{operator}{email_address}, $subject, $email_msg );
    }

}


1;


=head1 NAME

XT::JQ::DC::Receive::Upload::RelatedProducts

=head1 DESCRIPTION

This job is requested by Receive::Upload::DoUpload when
it has completed the Upload. It uploads to the web-site
Related Products for the PIDs provided.

{
    operator_id => 908,
    channel_id  => 1,
    upload_id   => 345,
    due_date    => "2009-12-25",
    environment => 'live',
    pids        => [ 123456, 234567, 122342 ],
    colour_variations => [ { pid => $pid1, colour_variations => [$pid1, $pid2] }
                            ... ]
}
