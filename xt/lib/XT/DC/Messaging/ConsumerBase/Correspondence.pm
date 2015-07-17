package XT::DC::Messaging::ConsumerBase::Correspondence;
use NAP::policy "tt", 'class';
extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';

use XTracker::Constants::FromDB qw(:sms_correspondence_status);
use XT::DC::Messaging::Spec::SMSCorrespondence;

=head1 NAME

XT::DC::Messaging::ConsumerBase::Correspondence - base class for Correspondence

=head1 DESCRIPTION

This base class exists so that we can have muiltiple controllers, one for each
method of Correspondence which exist on different queues without needing to duplicate any code.

=head2 SMSResponse

=cut

sub base_route {
    return {
        SMSResponse => {
            code => \&SMSResponse,
            spec => XT::DC::Messaging::Spec::SMSCorrespondence->SMSResponse(),
        },
    };
}

# how many attempts and the amount of seconds to wait between each
# before failing if with a Valid Id a 'sms_correspondence' record
# couldn't be found

has sms_retry_count => (
    is => 'ro',
    isa => 'Int',
    default => 1,
);

has sms_retry_secs => (
    is => 'ro',
    isa => 'Int',
    default => 0,
);

sub SMSResponse {
    ## no critic(ProhibitDeepNests)
    my ( $self, $message, $header )  = @_;

    my $schema  = $self->model('Schema');

    # expected statuses and their XT equivents
    my %statuses    = (
            SENT    => {
                    xt_status   => $SMS_CORRESPONDENCE_STATUS__SUCCESS,
                    success     => 1,
                },
            FAILED  => {
                    xt_status   => $SMS_CORRESPONDENCE_STATUS__FAIL,
                    success     => 0,
                },
        );
    my $result  = uc( $message->{result} );

    my $retry_attempts = $self->sms_retry_count;
    my $retry_wait = $self->sms_retry_secs;

    # if the 'result' is known
    if ( exists( $statuses{ $result } ) ) {

        # check if the Id is in a recognisable format
        if ( $message->{id} =~ m/^CSM-(?<id>\d+)$/ ) {
            my $id      = $+{id};
            my $status  = $statuses{ $result };
            my $success = $status->{success};
            my $found   = 0;

            # loop round trying to find the record in case there is a race condition
            # with the record not being created yet because it's still in a transaction
            ATTEMPT:
            foreach my $attempt ( 1..$retry_attempts ) {
                my $sms_rec = $schema->resultset('Public::SmsCorrespondence')->find( $id );
                if ( $sms_rec ) {
                    $found  = 1;
                    # don't update the SMS rec if it's already been flagged as a 'Success'
                    if ( !$sms_rec->is_success ) {
                        if ( !$success ) {
                            $sms_rec->failure_code( $message->{reason} );
                        }
                        $sms_rec->update_status( $status->{xt_status} );
                        # shouldn't send Notification if status is NOT Failed
                        $sms_rec->send_failure_alert;
                    }
                    else {
                        if ( !$success ) {
                            # log a warning if SMS rec already a 'Success' and the latest Status isn't
                            $self->log->warn( "Status for 'sms_correspondence' rec, Id: " . $sms_rec->id. ", already 'Success' new Status for Result: '$result' will be ignored" );
                        }
                    }
                    if ( $attempt > 1 ) {
                        # if it took more than one attempt then log it
                        $self->log->info( "Found 'sms_correspondence' rec for Id: " . $sms_rec->id . ", but only after: $attempt attempt(s)" );
                    }
                    last ATTEMPT;       # found the record
                }
                else {
                    # if this was the last attempt then no need to do the following
                    if ( $attempt != $retry_attempts ) {
                        $self->log->warn( "With Id: '$id', Couldn't find 'sms_correspondence' record yet, about to try attempt: " . ( $attempt + 1 ) . "/$retry_attempts, after a $retry_wait second wait" );
                        sleep( $retry_wait )        if ( $retry_wait );
                    }
                }
            }
            if ( !$found ) {
                # couldn't find the 'sms_correspondence' record
                $self->log->error( "With a Valid Id: '$id', Couldn't find a 'sms_correspondence' record after $retry_attempts attempts" );
            }
        }
        else {
            # not using an Expected Id format so wouldn't find a 'sms_correspondence', is fine but log it any-way
            $self->log->warn( "ID: '$message->{id}' not in the expected format to find a 'sms_correspondence' record" );
        }
    }
    else {
        $self->log->logcroak( "Found an Invalid 'result' value: '$message->{result}' didn't know what to do!" );
    }

    return;
}
