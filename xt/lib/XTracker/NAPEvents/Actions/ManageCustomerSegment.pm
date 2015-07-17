package XTracker::NAPEvents::Actions::ManageCustomerSegment;

use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Logfile               qw( xt_logger );
use XTracker::Error;
use XTracker::Navigation            qw( build_sidenav );
use XTracker::Database::Channel     qw( get_channels );
use XTracker::Database::Utilities       qw( :DEFAULT );
use XT::JQ::DC;

use Data::Dumper;

my $logger = xt_logger(__PACKAGE__);

sub handler {

    my $handler = XTracker::Handler->new( shift );

    my $schema = $handler->schema;

    my $action = $handler->{param_of}{action_name} // '';

    my $segment_rs    = $schema->resultset('Public::MarketingCustomerSegment');
    my $segment;
    my $channel_id;
    my $redirect_to     = "/NAPEvents/InTheBox/CustomerSegment";


    if ( $handler->{param_of}{segment_id} ) {
        my $err;
        try {
            $segment  = $segment_rs->find( $handler->{param_of}{segment_id} );
            $channel_id = $segment->channel_id;
            my $channel_rs = $schema->resultset('Public::Channel')->find($channel_id);
            $handler->{data}{channel_name} = $channel_rs->name;
            $handler->{data}{sales_channel} = $channel_rs->name;
            $handler->{data}{show_channel} = $channel_id;
            $handler->{data}{auto_show_channel} = $channel_id;
            $err = 0;
        }
        catch {
            xt_warn( "Couldn't find a Customer Segment: " . $_ );
            $err = 1;
        };
        return $handler->redirect_to( $redirect_to ) if $err;
    }

    my $promotion;
    my $create_redirect;
    given ( $action ) {
        when ( 'disable' ) {
            _enable_disable_segment( $handler, $segment, $action );
        }
        when ( 'enable' ) {
            _enable_disable_segment( $handler, $segment, $action );
        }
        when ( 'edit') {
            _edit_segment( $handler, $segment );
        }
        when( 'override') {
            _override_segment( $handler, $segment );
        }
        default {
            $segment  = _create_customer_segment( $handler );
            $channel_id = $handler->{param_of}{segment_channel_id};

            if( $segment) {
                $channel_id = $segment->channel_id;
                my $channel_rs = $schema->resultset('Public::Channel')->find($channel_id);
                $handler->{data}{channel_name} = $channel_rs->name;
                $handler->{data}{sales_channel} = $channel_rs->name;
                $handler->{data}{show_channel} = $channel_id;
                $handler->{data}{auto_show_channel} = $channel_id;
                $handler->{data}{customer_segment} = $segment;
            } else {
                $create_redirect = "/Create?";
            }

        }
    }

    if($create_redirect) {
        # Redirect to create page
        $redirect_to    .= $create_redirect;
    } elsif ( $segment && ($action eq 'disable' || $action eq 'enable')) {
        # Redirect to summary page
        $redirect_to    .= "?show_channel=" . $channel_id if ($channel_id);
    } else {
        # Redirect to edit page
        $redirect_to    .="/Edit?";
        $redirect_to    .= "show_channel=" . $channel_id;
        $redirect_to    .= "&segment_id=".$segment->id if $segment;
        $redirect_to    .= "&action=edit";
    }

    return $handler->redirect_to( $redirect_to );
}


sub _enable_disable_segment {
    my ( $handler, $segment, $action )    = @_;

    try {
        # by default Enable
        my $state   = 1;
        my $msg     = 'enabled';
        if ( $action eq 'disable' ) {
            $state  = 0;
            $msg    = 'disabled';
        }

        $handler->schema->txn_do( sub {
            $segment->update ( { enabled => $state } );

            $segment->create_related( 'marketing_customer_segment_logs', {
                        operator_id     => $handler->operator_id,
                        enabled_state   => $state,
                } );

            xt_success( "Customer Segment was ${msg} succesfully" );
        } );
    }
    catch {
        $logger->warn( "Enable/Disable: " .$_ );
        xt_warn('Invalid Customer Segment Id: '. $_ );
    };

    return;
}

sub _override_segment {
    my( $handler, $segment) = @_;
    try {
        $handler->schema->txn_do( sub {
            $segment->update ( { job_queue_flag => 'false' } );
            xt_success( "Job Queue is cancelled succesfully" );
        } );
    }
    catch {
        $logger->warn( "Override Job Queue: " .$_ );
        xt_warn('Invalid Customer Segment Id: '. $_ );
    };

    return;




}
sub _edit_segment {
    my ( $handler, $segment )     = @_;

    my $action = 'add';

    #check which button was clicked - Add/ Delete/ Clear all
    if( $handler->{param_of}{edit_segment_button_action} ) {
        $action = lc( $handler->{param_of}{edit_segment_button_action} );
    }

    try {

        if( $action eq 'clear_all') {

            # Delete all customers from Segment
            _reset_customer_segment( $handler, $segment );
        } elsif( $action eq 'delete') {

            # Delete customers from Segment
            _create_jq_request( $handler, $segment, 'delete' );
        } else {

            # Add customers to Segment
            _create_jq_request( $handler, $segment, 'add' );
        } #end of else
    }
    catch {
        $logger->warn( "Edit: " . $_ );
        xt_warn( 'Invalid Customer Segment Id '. $_ );
    };

    return;
}

sub _create_customer_segment {
    my $handler     = shift;

    my $segment;

    #create new customer segment
    return try {

        my $segment_name  = $handler->{param_of}{customer_segment_name};
        my $channel_id    = $handler->{param_of}{segment_channel_id};
        my $segment_rs    = $handler->schema->resultset('Public::MarketingCustomerSegment');

        # is the given customer_segment name is unique ?
        my $flag =  $segment_rs->is_unique($segment_name, $channel_id);
        if( $flag ) {
            $handler->schema->txn_do( sub {
                $segment  = $segment_rs->create({
                                name            => $segment_name,
                                channel_id      => $channel_id,
                                operator_id     => $handler->operator_id,
                            });
                $logger->debug( 'New database record created #' . $segment->id );
                xt_success( 'Customer Segment was created succesfully' );
            } );
            return $segment;
        } else {
            xt_warn( "Customer Segment Name is already in use. Create unique Customer segment Name");
            return 0;

        }
    }
    catch {
        $logger->warn( "Create: " . $_ );
        xt_warn( "Cannot Create Customer Segment : " . $_ );
        return 0;
    };
}

sub _reset_customer_segment {
    my $handler = shift;
    my $segment = shift;

    my $payload = {
        customer_segment_id => $segment->id,
        current_user        => $handler->operator_id,
        customer_list       => [],
        action_name         => 'delete_all',
    };

    my $job_rq = XT::JQ::DC->new({ funcname => 'Receive::NAPEvents::CustomerSegment' });
    $job_rq->set_payload( $payload );

    my $result = $job_rq->send_job();
    $logger->info(
        "Request to delete all customer from ". $segment->name. " customer_segment( ".$segment->id. " ) : "
        . 'new job-id='
        . $result->jobid
        . "\n"
    );

    $segment->update({
        job_queue_flag   => 'true',
        date_of_last_jq  => \'now()',
    });

    $segment->create_related( 'marketing_customer_segment_logs', {
        operator_id     => $handler->operator_id,
   });

    xt_info("Successfully sent a job queue request to delete all Customer from Customer Segment.");

}



sub _create_jq_request {
    my $handler = shift;
    my $segment = shift;
    my $action  = shift;

   if ($handler->{param_of}{add_customer_list}) {
        # Collect all the customer_nr ids
        my @customer_list = ();
        my @invalid_customer_list = ();
        my %customer_hash;
        my %invalid_customer_hash;
        foreach my $customer_id (split(/[\n\s,]+/,  $handler->{param_of}{add_customer_list})) {
            if (is_valid_database_id($customer_id)) {
                $customer_hash{$customer_id} = 1;
            }
            else {
                $invalid_customer_hash{ $customer_id } = 1;
            }
        }

        @customer_list = keys( %customer_hash );
        @invalid_customer_list = keys( %invalid_customer_hash );
        my $payload     = {
            customer_segment_id => $segment->id,
            current_user        => $handler->operator_id,
            customer_list       => \@customer_list,
            action_name         => $action,
        };

        my $message_str = 'attach';
        my $message     = 'to';
        if($action eq 'delete' ) {
            $message_str = 'delete';
            $message     = 'from';
        }

        if(scalar(@customer_list) > 100000) {
            xt_warn("Too many Customer Numbers to process. Maximum we can process is 100,000 but you gave us ".scalar(@customer_list). ". ");
            return 0;
        } elsif( scalar(@customer_list) > 0) {
            my $job_rq = XT::JQ::DC->new({ funcname => 'Receive::NAPEvents::CustomerSegment' });
            $job_rq->set_payload( $payload );
            my $result = $job_rq->send_job();


            $logger->info(
                  "Request to ".$message_str. " customer_list ".$message ." ". $segment->name. " customer_segment( ".$segment->id. " ) : "
                  . 'new job-id='
                  . $result->jobid
                  . "\n"
            );
            $segment->update({
                job_queue_flag   => 'true',
                date_of_last_jq  => \'now()',
            });

            $segment->create_related( 'marketing_customer_segment_logs', {
                    operator_id     => $handler->operator_id,
            });
        }

        if( scalar(@invalid_customer_list) > 0 ){
            xt_warn("Number of Invalid Customer Numbers Excluded: ". scalar(@invalid_customer_list));
        }

        if( scalar(@customer_list) > 0 ) {
            xt_info("Successfully sent a job queue request to ".$message_str. " ".scalar(@customer_list). " Customer(s) ". $message . " Customer Segment.");
       }

    }
}

1;
