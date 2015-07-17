use utf8;
package XTracker::Schema::Result::Public::PreOrderRefund;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.pre_order_refund");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "pre_order_refund_id_seq",
  },
  "pre_order_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pre_order_refund_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "sent_to_psp",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "pre_order",
  "XTracker::Schema::Result::Public::PreOrder",
  { id => "pre_order_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "pre_order_refund_failed_logs",
  "XTracker::Schema::Result::Public::PreOrderRefundFailedLog",
  { "foreign.pre_order_refund_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_refund_items",
  "XTracker::Schema::Result::Public::PreOrderRefundItem",
  { "foreign.pre_order_refund_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "pre_order_refund_status",
  "XTracker::Schema::Result::Public::PreOrderRefundStatus",
  { id => "pre_order_refund_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "pre_order_refund_status_logs",
  "XTracker::Schema::Result::Public::PreOrderRefundStatusLog",
  { "foreign.pre_order_refund_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:A77rJLrWNqhX+JYlmoLd1Q


use Carp;

use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw( :pre_order_refund_status );
use XTracker::Utilities                 qw( summarise_stack_trace_error );
use XTracker::Logfile                   qw( xt_logger );

use Moose;
with 'XTracker::Schema::Role::WithStatus' => {
         column => 'pre_order_refund_status_id',
         statuses => {
                failed => $PRE_ORDER_REFUND_STATUS__FAILED,
               pending => $PRE_ORDER_REFUND_STATUS__PENDING,
             cancelled => $PRE_ORDER_REFUND_STATUS__CANCELLED,
              complete => $PRE_ORDER_REFUND_STATUS__COMPLETE,
         },
    };

=head2 Status Methods

Various Methods that will return TRUE or FALSE based on the Status of the Record:

    $boolean    = $self->is_refundable;

=cut

sub is_refundable   {
    my $self    = shift;

    # note reversed sense of test --------------------------+---+
    #                                                       |   |
    #                                                       v   v
    return ( $self->is_cancelled || $self->is_complete ) ? 0 : 1 ;
}

=head2 update_status

    $self->update_status( $status_id, $operator_id );

Will update the Status of the Pre Order Refund and Log the change in 'pre_order_refund_status_log'.

Will default to 'Application' operator id NO $operator_id is passed.

=cut

sub update_status {
    my ( $self, $status_id, $operator_id )  = @_;

    # default to the Application Operator
    $operator_id    //= $APPLICATION_OPERATOR_ID;

    # update the Status
    $self->update( { pre_order_refund_status_id => $status_id } );

    # now Log it
    $self->create_related( 'pre_order_refund_status_logs', {
                                        pre_order_refund_status_id  => $status_id,
                                        operator_id                 => $operator_id,
                                } );

    return;
}


=head2 total_value

    my $number  = $self->total_value;

Returns the Value of the Refund by Adding together all of the Pre-Order Refund Items.

=cut

sub total_value {
    return shift->pre_order_refund_items->total_value;
}


=head2 set_sent_to_psp_flag

    $self->set_sent_to_psp_flag();

This will set the 'sent_to_psp' flag on the 'pre_order_refund' table to TRUE.

=cut

sub set_sent_to_psp_flag {
    my $self    = shift;
    $self->update( { sent_to_psp => 1 } );
    return;
}

=head2 clear_sent_to_psp_flag

    $self->clear_sent_to_psp_flag();

This will set the 'sent_to_psp' flag on the 'pre_order_refund' table to FALSE.

=cut

sub clear_sent_to_psp_flag {
    my $self    = shift;
    $self->update( { sent_to_psp => 0 } );
    return;
}

=head2 mark_as_failed_via_psp

    $pre_order_refund_failed_log_obj    = $self->mark_as_failed_via_psp( $failure_message, $operator_id );

This will update the Status of the 'pre_order_refund' record to be 'Failed' and also create a
'pre_order_refund_failed_log' record with the supplied 'Failure Message'. You can pass an optional
Operator Id otherwise this will default to the Application Operator. This method assumes the Refund Failed
because of PSP issues and it will use the current 'preauth_ref' value on the 'pre_order_payment' record
to populate the corresponding field on the 'pre_order_refund_failed_log' record.

This will create a 'pre_order_refund_failed_log' for every call but it won't update the Status
of the 'pre_order_refund' record to 'Failed' if that is it's Current Status and so therfore there
won't be excessive 'pre_order_refund_status_log' records.

=cut

sub mark_as_failed_via_psp {
    my ( $self, $message, $operator_id )    = @_;

    croak "No Failure Message Passed to 'mark_as_failed_via_psp' method in '" . __PACKAGE__ . "'"       if ( !$message );

    $operator_id    //= $APPLICATION_OPERATOR_ID;

    if ( !$self->is_failed ) {
        # only update the Status when $self ISN'T Failed
        $self->update_status( $PRE_ORDER_REFUND_STATUS__FAILED, $operator_id );
    }

    # get the Payment Record to get the Pre-Auth Value
    my $payment     = $self->pre_order
                            ->pre_order_payment;

    my $failed_log  = $self->create_related( 'pre_order_refund_failed_logs', {
                                                            preauth_ref_used    => $payment->preauth_ref,
                                                            failure_message     => $message,
                                                            operator_id         => $operator_id,
                                                    } );

    return $failed_log;
}

=head2 refund_to_customer

    $boolean    = $self->refund_to_customer( {
                                                operator_id     => $operator_id,    # optional will default to Application User
                                                dbh_override    => $dbh,            # optional Auto-Committed enabled DBH used
                                                                                    # to set the 'sent_to_psp' field
                                            } );

Will Refund the Amount for this 'pre_order_refund' record back to the Customer via the PSP. It
requires the record to be in a Status that is Refundable and also that the 'sent_to_psp' field
is set to FALSE.

This method will set the record's 'sent_to_psp' field to TRUE using a seperate Database Handler
which will commit the change immediately. If you want to use your own DBH to save this method
connecting everytime it'self the pass in the arguments a Auto-Commit enabled DBH in the
'dbh_override' argument.

If the refund is succesful then it will set the Status to be 'Complete' and return TRUE,
if it fails then it will set the status to be 'Failed' and create a 'pre_order_refund_failed_log' record.

=cut

sub refund_to_customer {
    my ( $self, $args ) = @_;

    my $retval  = 0;

    # if the Status is not in a Refundable state or the 'sent_to_psp' flag is TRUE
    return $retval      if ( !$self->discard_changes->is_refundable || $self->sent_to_psp );

    if ( $self->total_value <= 0 ) {
        my $error_msg = "Invalid amount given for creation of refund :". $self->total_value ." for PreOrder Id: ".$self->pre_order->id;
        xt_logger->warn($error_msg);
        croak $error_msg;
    }

    my $operator_id = $args->{operator_id} // $APPLICATION_OPERATOR_ID;

    # update 'sent_to_psp' flag and then check that it has been
    $self->_isolated_update_sent_to_psp( 1, $args->{dbh_override} );
    if ( !$self->sent_to_psp ) {
        croak "'sent_to_psp' flag STILL FALSE, has refund record been committed before calling method 'refund_to_customer'"
                . " or is 'dbh_override' argument not Auto-Commit Enabled, in '" . __PACKAGE__ . "'";
    }

    # get the payment record to do the refund with
    my $payment = $self->pre_order
                            ->pre_order_payment;

    eval {
        $payment->psp_refund_the_amount( $self->total_value );
    };
    if ( my $err = $@ ) {
        # there has been a Failure
        $self->mark_as_failed_via_psp( summarise_stack_trace_error( $err ), $operator_id );
        $retval = 0;
    }
    else {
        # it worked
        $self->update_status( $PRE_ORDER_REFUND_STATUS__COMPLETE, $operator_id );
        $retval = 1;
    }

    return $retval;
}

=head2 most_recent_failed_log

    $pre_order_refund_failed_log    = $self->most_recent_failed_log;

This returns the most recent 'pre_order_refund_failed_log' that has been created.

=cut

sub most_recent_failed_log {
    my $self    = shift;

    return $self->pre_order_refund_failed_logs->order_by_id_desc->first;
}


# this will update the 'sent_to_psp' flag in
# an independant DB update
sub _isolated_update_sent_to_psp {
    my ( $self, $sent_to_psp, $dbh_override )   = @_;

    croak '_isolated_update_sent_to_psp: Requires $sent_to_psp.'        unless $sent_to_psp;

    # Get a new database connection (using readonly for auto-commit), if
    # an override has not been supplied.
    my $dbh_new = $dbh_override
               || XTracker::Database::xtracker_schema_no_singleton()->storage->dbh;

    # update the flag
    my $sql = "UPDATE pre_order_refund SET sent_to_psp = " . ( $sent_to_psp ? 'TRUE' : 'FALSE' ) . " WHERE id = " . $self->id;
    my $sth = $dbh_new->prepare( $sql );
    $sth->execute();

    # Close the database connection if no override was passed in.
    $dbh_new->disconnect    unless $dbh_override;

    # re-fresh the current object
    return $self->discard_changes;
}

1;
