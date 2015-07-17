package XTracker::Schema::ResultSet::Public::RoutingSchedule;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Carp;

use base 'DBIx::Class::ResultSet';

use DateTime;

use XTracker::Utilities                 qw( number_in_list );
use XTracker::Constants::FromDB         qw(
                                            :routing_schedule_status
                                            :routing_schedule_type
                                        );

=head2 list_schedules

    $array_ref  = $routing_schedule->list_schedules();

This method reads the 'routing_schedule' table for a set of records and combines them in order to present an
ordered list of schedules for a Shipment or RMA so that it can be displayed on the Order View page showing
what actually happened, this could also be used to get the schedule that should be Emailed and/or SMS'd to
the Customer to alert them when their goods will be delievered or collected.

This will not just give a raw dump of the 'routing_schedule' table it will actually combine some records
to produce a sane list to the operator (newest to oldest) detailing of any re-schedules or unsuccesful
deliveries.

Returns an ArrayRef of HashRefs which are representative of 'routing_schedule' records but are not proper
DBIC versions of them.

=cut

sub list_schedules {
    my $self    = shift;

    my $schema  = $self->result_source->schema;

    my $recs    = $self->in_correct_sequence;

    my @success_status  = ( $ROUTING_SCHEDULE_STATUS__SHIPMENT_DELIVERED, $ROUTING_SCHEDULE_STATUS__SHIPMENT_COLLECTED );
    my @fail_status     = ( $ROUTING_SCHEDULE_STATUS__SHIPMENT_UNDELIVERED, $ROUTING_SCHEDULE_STATUS__SHIPMENT_UNCOLLECTED );
    my @skip_if_first   = ( $ROUTING_SCHEDULE_STATUS__SCHEDULED, $ROUTING_SCHEDULE_STATUS__RE_DASH_SCHEDULED );

    # list of fields to overwrite from one record to another
    my @overwrite_flds  = qw( id external_id task_window driver run_number run_order_number task_window_date routing_schedule_status_id notified );

    my @list;
    my $last_rec;

    # when a 'notified' flag is TRUE, store the
    # Status Id, Task Window Date & Task Window Time
    # as a key so that this Hash can be inspected later
    # to make sure duplicate messages aren't sent
    my %has_been_notified;

    RECORD:
    foreach my $rec ( @{ $recs } ) {

        # convert the DBIC rec into a HASH
        my %hash_rec        = $rec->get_columns;
        $hash_rec{success}  = 0;
        $hash_rec{failed}   = 0;
        $hash_rec{resched}  = 0;

        # put the dates back properly as DateTime objects
        $hash_rec{task_window_date} = $rec->task_window_date;
        $hash_rec{date_imported}    = $rec->date_imported;
        $hash_rec{signature_time}   = $rec->signature_time;

        # format the 'task_window'
        $hash_rec{task_window}      = $rec->format_task_window;

        # make up a key used for the %has_been_notified hash
        my $notified_key    = $hash_rec{routing_schedule_status_id} . '_'
                              . ( ref( $hash_rec{task_window_date} ) ? $hash_rec{task_window_date}->ymd('') : '' ) . '_'
                              . ( $hash_rec{task_window} // '' );

        # if this record has been notified then store this in the %has_been_notified hash
        if ( $rec->notified ) {
            $has_been_notified{ $notified_key } = 1;
        }
        # check if the $notified_key has been notified already
        elsif ( exists( $has_been_notified{ $notified_key } ) ) {
            # then set this record to have been notified too
            $hash_rec{notified} = 1;
        }

        if ( !$last_rec ) {
            # if there is no 'last_rec' set
            push @list, \%hash_rec;
            $last_rec   = $list[-1];
            next RECORD     if ( number_in_list( $rec->routing_schedule_status_id, @skip_if_first ) );
        }

        if ( number_in_list( $rec->routing_schedule_status_id, @success_status ) ) {
            # if succesful then update the previous record to indicate as such
            $last_rec->{success}    = 1;

            # now overwrite parts of the previous record
            # with this rec's if they have values
            foreach my $key ( @overwrite_flds, qw( signatory signature_time ) ) {
                $last_rec->{ $key } = $hash_rec{ $key }     if ( defined $hash_rec{ $key } );
            }

            $last_rec   = undef;        # clear out the last rec as it shouldn't be being updated
            next RECORD;
        }

        if ( number_in_list( $rec->routing_schedule_status_id, @fail_status ) ) {
            $last_rec->{failed}     = 1;

            # now overwrite parts of the previous record
            # with this rec's if they have values
            foreach my $key ( @overwrite_flds, qw( undelivered_notes ) ) {
                $last_rec->{ $key } = $hash_rec{ $key }     if ( defined $hash_rec{ $key } );
            }

            $last_rec   = undef;        # clear out the last rec as it shouldn't be being updated
            next RECORD;
        }

        if ( $rec->routing_schedule_status_id == $ROUTING_SCHEDULE_STATUS__RE_DASH_SCHEDULED ) {

            if ( $last_rec->{routing_schedule_status_id} != $ROUTING_SCHEDULE_STATUS__RE_DASH_SCHEDULED ) {
                # if previous record wasn't a Re-Schedule
                # then updated it to be and store a new record
                $last_rec->{resched}    = 1;
                push @list, \%hash_rec;

                $last_rec   = $list[-1];
            }
            else {
                # if the previous record was a Re-Schedule then just update it
                foreach my $key ( @overwrite_flds ) {
                    $last_rec->{ $key } = $hash_rec{ $key }     if ( defined $hash_rec{ $key } );
                }
            }

            next RECORD;
        }

        if ( $rec->routing_schedule_status_id == $ROUTING_SCHEDULE_STATUS__SCHEDULED ) {

            # overwrite parts of the previous record
            # with this rec's if they have values
            foreach my $key ( @overwrite_flds ) {
                $last_rec->{ $key } = $hash_rec{ $key }     if ( defined $hash_rec{ $key } );
            }

            next RECORD;
        }
    }

    # reverse the order of the array so that most recent is first
    return ( @list ? [ reverse @list ] : undef );
}

=head2 in_correct_sequence

    $array_ref  = $routing_schedule->in_correct_sequence();

This returns an Array Ref of DBIC 'routing_schedule' records in the correct Sequence that they should be in, which may not be the order they were created in because of the way Route Monkey output their XML Files.

No records return an empty Array Ref.

The order it sorts the records in is as follows:

    1) External Id          - This uniquely groups schedules together and is an ever increasing number,
                              so when there is an initial failure to Deliver a Shipment and the delivery
                              is Re-Scheduled and Succeeds would be like the following: the initial 'Schedule',
                              'Fail' & 'Re-Schedule' statuses would have the same External Id and the subsequent
                              'Schedule' & 'Success' statuses would share another External Id higher than the first one.

    2) Routing Status Rank  - Each Status has it's own ranking which is used to sort by to make sure that the
                              Statuses are ordered in a logical order within an External Id group, it's based on the presumption
                              that a Schedule status must be first and that a Re-Schedule should be last with Succes or Failure
                              in the middle, so 'Fail, Re-Schedule, Schedule' should come out as 'Schedule, Fail, Re-Schedule'.
                              The Rankings for the Statuses are as follows:
                                    * Scheduled            - 10
                                    * Shipment undelivered - 20
                                    * Shipment uncollected - 20
                                    * Shipment collected   - 20
                                    * Shipment delivered   - 20
                                    * Re-scheduled         - 30

    3) Internal Id          - This is just the Id of the Schedule record in the 'routing_schedule' table and is the last
                              thing to be sorted on. It means that any duplicate 'rank' will then go on the order it
                              was inserted into the table which should be lowest first.

All of the above are sorted in ASCENDING order.

=cut

sub in_correct_sequence {
    my ( $self )    = shift;

    my $alias   = $self->current_source_alias;

    return [
            $self->search(
                { },
                {
                    join        => 'routing_schedule_status',
                    order_by    => {
                                    -asc    => [
                                                "${alias}.external_id",
                                                "routing_schedule_status.rank",
                                                "${alias}.id",
                                            ],
                                },
                } )->all
        ];
}


1;
