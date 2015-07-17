package XTracker::Admin::AJAX::GetJobQueueLists;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use Storable                    qw( thaw );
use Data::Dump                  qw( pp );
use DateTime;

use XTracker::Handler;
use XTracker::Database          qw( :common );
use XTracker::Utilities         qw( url_encode );

use XTracker::DBEncode          qw( encode_it );

use XT::JQ::DC::Queue;


sub handler {

        # get a Handler because it's easier to create JobQ requests
        my $handler     = XTracker::Handler->new(shift);


        my $queue;
        my $schema              = $handler->{schema};
        my $jqschema            = get_database_handle( { name => 'jobqueue_schema' } );

        my $response            = '';           # response string

        my $list_type           = $handler->{param_of}{list_type};

        my $q_status            = _get_queue_status(\$queue);

        CASE: {
                $response       = "{'status':'OK','list_type':'$list_type','jq_status':'$q_status',";
                $response       .= "'list':[";

                if ( $list_type eq "JOB" ) {
                        my $jobs        = $jqschema->resultset('Job')->search( undef, { prefetch => 'func', order_by => 'priority ASC' } );

                        my $job_count   = $jobs->count;

                        while ( my $job = $jobs->next ) {
                                $response       .= "{";
                                $response       .= "'jobid':'".$job->jobid."',";
                                $response       .= "'func_name':'".$job->func->funcname."',";
                                $response       .= "'run_after':'".$job->run_after->datetime."',";
                                $response       .= "'grabbed_until':'". ( $job->grabbed_until ? DateTime->from_epoch(epoch=>$job->grabbed_until)->datetime : 'N/A' ) ."',";
                                $response       .= "'priority':'".$job->priority."',";

                                $response       .= "'args':{";
                                my $arg = thaw($job->arg);
                                foreach ( sort keys %$arg ) {
                                        $response       .= "'$_':";
                                        if ( ref($arg->{$_}) ) {
                                                $response       .= "{'type':'h','value':'" . url_encode(pp($arg->{$_})) . "'},";
                                        }
                                        else {
                                                $response       .= "{'type':'s','value':'" . url_encode($arg->{$_}) . "'},";
                                        }
                                }
                                $response       =~ s/,$//;
                                $response       .= "}";

                                $response       .= "},";
                        }
                        $response       =~ s/,$//;
                        $response       .= "],";

                        $response       .= "'list_fields':['jobid','func_name','run_after','grabbed_until','priority'],";
                        $response       .= "'headers':['Job Id','Function','Run After','Grabbed Until','Priority'],";
                        $response       .= "'title':'Job List ($job_count " . ( $job_count == 1 ? 'job' : 'jobs' ) . ")'";

                        $response       .= "}";

                        last CASE;
                }
                if ( $list_type eq "FAILED" ) {
                        my $jobs        = $jqschema->resultset('FailedJob')->search( {}, { prefetch => 'func', order_by => 'job_id DESC' } );
                        my $job_count   = $jobs->count;

                        while ( my $job = $jobs->next ) {
                                $response       .= "{";
                                $response       .= "'jobid':'".$job->job_id."',";
                                $response       .= "'func_name':'".$job->func->funcname."',";
                                $response       .= "'error':'".$job->error->[0]."',";
                                $response       .= "'reason':'".$job->reason."',";
                                $response       .= "'run_at':'".$job->run_at->datetime."',";

                                my $arg         = $job->arg;

                                $response       .= "'args':{";
                                foreach ( sort keys %$arg ) {
                                        $response       .= "'$_':";
                                        if ( ref($arg->{$_}) ) {
                                                $response       .= "{'type':'h','value':'" . url_encode(pp($arg->{$_})) . "'},";
                                        }
                                        else {
                                                $response       .= "{'type':'s','value':'" . url_encode($arg->{$_}) . "'},";
                                        }
                                }
                                $response       =~ s/,$//;
                                $response       .= "}";

                                $response       .= "},";
                        }
                        $response       =~ s/,$//;
                        $response       .= "],";

                        $response       .= "'list_fields':['jobid','func_name','error','reason','run_at'],";
                        $response       .= "'headers':['Job ID', 'Function', 'Error', 'Reason', 'Run At'],";
                        $response       .= "'title':'Failed Job List ($job_count " . ( $job_count == 1 ? 'job' : 'jobs' ) . ")'";

                        $response       .= "}";

                        last CASE;
                }
                if ( $list_type eq "ERROR" ) {
                        my $errors  = $jqschema->resultset('Error')->search( undef, { prefetch => 'func', order_by => 'jobid DESC' } );

                        while ( my $error = $errors->next ) {
                                $response       .= "{";
                                $response       .= "'jobid':'".$error->jobid."',";
                                $response       .= "'func_name':'".$error->func->funcname."',";
                                $response       .= "'error_time':'".localtime($error->error_time)."',";
                                $response       .= "'msg':'".url_encode($error->message)."'";
                                $response       .= "},";
                        }
                        $response       =~ s/,$//;
                        $response       .= "],";

                        $response       .= "'list_fields':['jobid','func_name','error_time','msg'],";
                        $response       .= "'headers':['Job Id','Function','When','Error Message'],";
                        $response       .= "'widths':['0','0','0','400'],";
                        $response       .= "'title':'Job Error Messages'";

                        $response       .= "}";

                        last CASE;
                }
                if ( $list_type =~ /FUNCMAP_(.*)/ ) {
                        my %ltype       = (
                                        'ALL'           => { title => 'All Functions',
                                                                         cond  => undef,
                                                                },
                                        'SEND'          => { title => 'Send Functions',
                                                                         cond  => {
                                                                                        funcname => { 'like' => '%::Send::%' }
                                                                                },
                                                                },
                                        'RECEIVE'       => { title => 'Receive Functions',
                                                                         cond  => {
                                                                                         funcname => { 'like' => '%::Receive::%' }
                                                                                },
                                                                },
                                        'OTHER'         => { title => 'Other Functions',
                                                                         cond  => {
                                                                                        funcname => { 'not like' => '%::Send::%' },
                                                                                        'me.funcname' => { 'not like' => '%::Receive::%' }
                                                                                }
                                                                }
                                );

                        my $funcs   = $jqschema->resultset('FuncMap')->search( $ltype{$1}{cond}, { order_by => 'funcid' } );

                        my $title       = $ltype{$1}{title};

                        while ( my $func = $funcs->next ) {
                                $response       .= "{";
                                $response       .= "'funcid':'".$func->funcid."',";
                                $response       .= "'func_name':'".$func->funcname."',";
                                $response       .= "'can_use':";
                                eval "use ".$func->funcname; ## no critic(ProhibitStringyEval)
                                if ($@) {
                                        $response       .= "'<img src=\"/images/icons/cross.png\" alt=\"No\" title=\"No\" />',";
                                }
                                else {
                                        $response       .= "'<img src=\"/images/icons/tick.png\" alt=\"Yes\" title=\"Yes\" />',";
                                }
                                $response       .= "'jq_looking_for':";
                                if ( defined $queue ) {
                                        if ( grep { $func->funcname eq $_ } @{ $queue->get_can_do } ) {
                                                $response       .= "'<img src=\"/images/icons/tick.png\" alt=\"Yes\" title=\"Yes\" />'";
                                        }
                                        else {
                                                $response       .= "'<img src=\"/images/icons/cross.png\" alt=\"No\" title=\"No\" />'";
                                        }
                                }
                                else {
                                        $response       .= '"Can\'t Tell"';
                                }
                                $response       .= "},"
                        }
                        $response       =~ s/,$//g;
                        $response       .= "],";

                        $response       .= "'list_fields':['funcid','func_name','can_use','jq_looking_for'],";
                        $response       .= "'headers':['Function Id','Function Name','Can use','JQ is Looking For'],";
                        $response       .= "'title':'".$title."',";
                        $response       .= "'no_refresh':'1'";

                        $response       .= "}";

                        last CASE;
                }
        if ( $list_type eq "LAST50" ) {
            my $exitstatuss = $jqschema->resultset('ExitStatus')->search(
                undef, { _prefetch => 'func', order_by => 'completion_time DESC', 'rows' => '50' } );

            while ( my $exitstatus = $exitstatuss->next ) {
                $response   .= "{";
                $response   .= "'jobid':'".$exitstatus->jobid."',";
                $response   .= "'func_name':'".$exitstatus->func->funcname."',";
                $response   .= "'status':";
                if ( $exitstatus->status == 0 ) {
                    $response   .= "'".url_encode('<img src="/images/icons/bullet_green.png" alt="Job Successful, Status: '.$exitstatus->status.'" title="Job Successful, Status: '.$exitstatus->status.'" />')."',";
                }
                else {
                    $response   .= "'".url_encode('<img src="/images/icons/bullet_red.png" alt="Job Most Likely Failed, Status: '.$exitstatus->status.'" title="Job Most Likely Failed, Status: '.$exitstatus->status.'" />')."',";
                }
                $response   .= "'completed':'". ( $exitstatus->completion_time ? localtime($exitstatus->completion_time) : 'Unknown' ) ."',";
                $response   .= "'delete_time':'". ( $exitstatus->delete_after ? localtime($exitstatus->delete_after) : 'Unknown' ) ."'";
                $response   .= "},";
            }
            $response   =~ s/,$//g;
            $response   .= "],";

            $response   .= "'list_fields':['jobid','status','func_name','completed','delete_time'],";
            $response   .= "'headers':['Job Id','Status','Function Name','When Job Completed','Delete from this List'],";
            $response   .= "'title':'Last 50 Jobs'";

            $response   .= "}";

            last CASE;
        }

                $response       = "{'status':'ERROR','msg':'List Type: ".$list_type." Unknown','jq_status':'$q_status'}";
        };

        $jqschema->storage->disconnect();

        # write out response
        $handler->{r}->content_type( 'text/plain' );
        $handler->{r}->print( encode_it($response) );

    return OK;
}


### Subroutine : _get_queue_status                                  ###
# usage        : $scalar = _get_queue_status();                       #
# description  : Returns the status of the Job Queue. A -1 means that #
#                you can not create a new instance of XT::JQ::DC,     #
#                0 means that the queue isn't running and a positive  #
#                number means the queue is running and that number is #
#                the PID of the Job Queue.                            #
# parameters   : None.                                                #
# returns      : A integer value: -1, 0 or > 0.                       #

sub _get_queue_status {
        my $queue_ptr   = shift;

        my $queue;
        my $retval;

        eval {
                $queue          = XT::JQ::DC->new({ funcname => '' });
                $retval         = $queue->{queue}->is_running;
                $$queue_ptr     = $queue->{queue};
        };
        if ($@) {
                $retval = -1;
        }
        else {
                if ( !defined $retval ) {
                        $retval = 0;
                }
        }

        return $retval;
}


1;
