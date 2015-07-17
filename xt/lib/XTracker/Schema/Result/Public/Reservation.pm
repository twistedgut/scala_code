use utf8;
package XTracker::Schema::Result::Public::Reservation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.reservation");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "reservation_id_seq",
  },
  "ordering_id",
  { data_type => "integer", is_nullable => 0 },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "customer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date_created",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "date_uploaded",
  { data_type => "timestamp", is_nullable => 1 },
  "date_expired",
  { data_type => "timestamp", is_nullable => 1 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "notified",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "date_advance_contact",
  { data_type => "timestamp", is_nullable => 1 },
  "customer_note",
  { data_type => "text", is_nullable => 1 },
  "note",
  { data_type => "text", is_nullable => 1 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "reservation_source_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "reservation_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "commission_cut_off_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "customer",
  "XTracker::Schema::Result::Public::Customer",
  { id => "customer_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "link_shipment_item__reservation_by_pids",
  "XTracker::Schema::Result::Public::LinkShipmentItemReservationByPid",
  { "foreign.reservation_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_shipment_item__reservations",
  "XTracker::Schema::Result::Public::LinkShipmentItemReservation",
  { "foreign.reservation_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "pre_order_items",
  "XTracker::Schema::Result::Public::PreOrderItem",
  { "foreign.reservation_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservation_auto_change_logs",
  "XTracker::Schema::Result::Public::ReservationAutoChangeLog",
  { "foreign.reservation_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservation_logs",
  "XTracker::Schema::Result::Public::ReservationLog",
  { "foreign.reservation_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservation_operator_logs",
  "XTracker::Schema::Result::Public::ReservationOperatorLog",
  { "foreign.reservation_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "reservation_source",
  "XTracker::Schema::Result::Public::ReservationSource",
  { id => "reservation_source_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "reservation_type",
  "XTracker::Schema::Result::Public::ReservationType",
  { id => "reservation_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::ReservationStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:k+iRQdPRWNejgKfztpfy+Q

=head1 NAME

XTracker::Schema::Result::Public::Reservation

=cut

use Moose;
with 'XTracker::Schema::Role::Hierarchy';

__PACKAGE__->load_components('+XTracker::Utilities::DBIC::LocalDate');

use XTracker::Constants::FromDB             qw( :reservation_status :department );
use XTracker::Constants                     qw( :application );
use XTracker::SchemaHelper                  qw( :records );
use XTracker::Database::Reservation         qw( upload_reservation :email );
use XTracker::Utilities                     qw( number_in_list );
use XTracker::Config::Local                 qw( get_reservation_commission_cut_off_date );

use Carp;

=head1 METHODS

=head2 total_balance

Returns total balance of resevations like this one (same variant and customer)

=cut

sub total_balance {
    my $self = shift;

    return $self->result_source->schema->resultset('Public::Reservation')
        ->uploaded
        ->by_variant_id( $self->variant_id )
        ->count;
}

=head2 set_purchased

Set this reservation as purchased

=cut

sub set_purchased {
    my $self = shift;

    # log
    $self->create_related('reservation_logs', {
        reservation_status_id   => $RESERVATION_STATUS__PURCHASED,
        quantity                => -1,
        balance                 => $self->total_balance - 1,
        operator_id             => $APPLICATION_OPERATOR_ID,
        date                    => \'current_timestamp',
    });

    # check if 'ordering_id' is greater than ZERO because
    # Pre-Order Reservations will start off at ZERO
    if ( $self->ordering_id > 0 ) {
        # adjust sibling reservations for this variant
        my $greater_siblings = $self->result_source->resultset->search({
            channel_id  => $self->channel_id,
            variant_id  => $self->variant_id,
            ordering_id => { '>'    => $self->ordering_id },
            id          => { '!='   => $self->id },
        });

        $greater_siblings->update({ordering_id => \'ordering_id - 1'});
    }

    # update status and move to start of ordering
    $self->update({
        status_id   => $RESERVATION_STATUS__PURCHASED,
        ordering_id => 0,
    });
    # set commission_cut_off_date
    $self->set_commission_cut_off_date();

    return 1;
}

=head2 upload_pending

    $boolean    = $reservation->upload_pending( $operator_id, $stock_manager );

This will Upload a Pending Reservation. Will need to pass in 'XTracker::WebContent::StockManagement' object so it can use it's web connection. It will call the function 'upload_reservation' from the 'XTracker::Database::Reservation' module to actually upload the reservation - this can be RE-FACTORED out at a later date.

=cut

sub upload_pending {
    my ( $self, $operator_id, $stock_manager )  = @_;

    croak "'upload_pending' not passed an Operator Id"              if ( !$operator_id );
    croak "'upload_pending' not passed a Stock Manager object"      if ( !$stock_manager );

    if ( $self->status_id != $RESERVATION_STATUS__PENDING ) {
        # if the Status is not 'Pending' then nothing to do
        return 0;
    }

    upload_reservation(
                        $self->result_source->schema->storage->dbh,
                        $stock_manager,
                        {
                            reservation_id  => $self->id,
                            variant_id      => $self->variant_id,
                            operator_id     => $operator_id,
                            customer_id     => $self->customer_id,
                            customer_nr     => $self->customer->is_customer_number,
                            channel_id      => $self->channel_id,
                        },
                    );

    # make sure the record is up to date
    $self->discard_changes;

    return 1;
}

=head2 notify_of_auto_upload

    $hash_ref = $reservation->notify_of_auto_upload( $stock_manager );

This will call functions to generate an email to the Customer notifying them of their Reservation being available on the web-site and also notify the Operator who made the Reservation that the reservation has been Uploaded by using the xTracker internal messaging facility.

Will return a Hash Ref of parameters that can be passed straight through into 'XTracker::EmailFunctions::send_customer_email'.

Reservations for Pre-Orders should do Nothing when this method is called and return 'undef'.

=cut

sub notify_of_auto_upload {
    my ( $self, $operator_id )      = @_;

    croak "'notify_of_auto_upload' not passed an Operator Id"           if ( !$operator_id );

    if ( $self->status_id != $RESERVATION_STATUS__UPLOADED ) {
        # only do this for Uploaded Reservations
        return;
    }

    if ( $self->is_for_pre_order ) {
        # Reservations for Pre-Orders should be Excluded
        return;
    }

    my $schema  = $self->result_source->schema;
    my $dbh     = $schema->storage->dbh;

    # Stuff for the Customer's Email
    my $customer        = $self->customer;
    my $addressee       = (
                            $self->channel->is_on_mrp
                            ? ( $customer->title eq 'Mr' ? 'Mr' : 'Ms' ) . ". " . $customer->last_name
                            : $customer->first_name
                          );
    my $from_email      = get_from_email_address( {
        channel_config  => $self->channel->business->config_section,
        department_id   => $self->operator->department_id,
        schema          => $schema,
        locale          => $customer->locale,
    } );

    # get the parsed email so that it can be sent later on
    my $email_info = build_reservation_notification_email( $dbh,
        # this is to emulate the contents of an 'XTracker::Handler' object
        # if I had more time I would flatten it out but to make sure
        # stuff still works I thought I would just populate it like this
        {
            schema  => $schema,
            dbh     => $dbh,
            param_of    => {
                    channel_id  => $self->channel_id,
                    customer_id => $self->customer_id,
                    operator_id => $self->operator_id,
                    addressee   => $addressee,
                    'inc-'.$self->id => 1,  # inc-reservation_id
                },
            data        => {
                    operator_id     => $self->operator_id,
                    department_id   => $self->operator->department_id,
                    channel         => $self->channel,
                },
        },
    );

    # make up the params required to pass to the 'XTracker::EmailFunctions::send_customer_email()' function
    my $email_params = {
        to          => $customer->email,
        from        => $from_email,
        reply_to    => $from_email,
        subject     => $email_info->{subject},
        content     => $email_info->{content},
        content_type => $email_info->{content_type},
    };

    # make sure the record is up to date
    $self->discard_changes;

    my $product = $self->variant->product;

    # now notify the operator who created the Reservation
    # using xTracker's internal messaging system
    $self->operator->send_message( {
        subject => "Customer Reservation: ".$customer->is_customer_number .
                   " for ". $self->variant->sku .
                   " has been Uploaded",
        message => "Customer: ".$customer->is_customer_number." - ".$customer->first_name." ".$customer->last_name . ',<br/><br/>'
                 . "Reserved item: ".$self->variant->sku." - ".$product->designer->designer . " - "
                                                              .$product->product_attribute->name . '<br/><br/>'
                 . "Has now been uploaded on ".$self->local_date( 'date_uploaded', naughty_local_time_zone => 1 ),
        sender  => $operator_id,
    } );

    return $email_params;
}

=head2 update_operator

    $reservation->update_operator( $operator, $new_operator );

Updates the operator assigned to the reservation to C<$new_operator> and logs the upate against C<$operator>.

=cut

sub update_operator {
    my ( $self, $operator, $new_operator ) = @_;

    return ( 0, 'the reservation is already assigned to the requested operator' )
        if $self->operator_id == $new_operator;

    return ( 0, 'the reservation is cancelled' )
        if $self->status_id == $RESERVATION_STATUS__CANCELLED;

    my ( $can_update_operator, $reason ) = $self->can_update_operator( $operator );

    if ( $can_update_operator ) {

        # Remember the original operator.
        my $old_operator = $self->operator;

        # Update the operator.
        $self->update( { operator_id => $new_operator } );

        # Log the update.
        my $log_entry = $self->reservation_operator_logs->create(
            {
                operator_id             => $operator,
                from_operator_id        => $old_operator->id,
                to_operator_id          => $new_operator,
                reservation_status_id   => $self->status_id,
            }
        );

        # Refresh the row from storage, as create does not do this (created_timestamp is not populated if we don't do this)!
        $log_entry->discard_changes;

        # Send the new operator a message in XT.
        $self->operator->send_message( {
            subject => 'Reservation Re-Assigned',
            message => sprintf(
                'Customer %d (%s %s), reserved item "%s" has been reassigned to you on %s from %s.',
                $self->customer->id,
                $self->customer->first_name,
                $self->customer->last_name,
                $self->variant->product->wms_presentation_name,
                $log_entry->created_timestamp->ymd . ' ' . $log_entry->created_timestamp->hms,
                $old_operator->name,
            ),
            sender  => $operator,
        } );

        return ( 1, '' );

    } else {

        return ( 0, $reason );

    }

}

=head2 can_update_operator

    my $boolean = $reservation->can_update_operator( $operator );

Checks if C<$operator> can update the C<$reservation>, by checking if they are in one of the
following departments:

 * Customer Care
 * Customer Care Manager
 * Personal Shopping
 * Fashion Advisor

If they are in one of the above departments, they're allowed to update reservations.

If they're a Manager in the Department, they can update ANY reservation, even if it's
not owned by themselves.

If they're an Operator in the Department, they can only update the reservation, if
it's their own.

=cut

sub can_update_operator {
    my ( $self, $operator ) = @_;

    $operator = $self->result_source->schema->resultset('Public::Operator')->find( $operator )
        unless ref( $operator ) eq 'XTracker::Schema::Result::Public::Operator';

    if ( $operator ) {

        my $operator_name = $operator->name;

        # Is the operator in one of the allowed departments.
        if ( number_in_list( $operator->department_id,
            $DEPARTMENT__CUSTOMER_CARE, $DEPARTMENT__CUSTOMER_CARE_MANAGER, $DEPARTMENT__PERSONAL_SHOPPING, $DEPARTMENT__FASHION_ADVISOR )
        ) {

            # If they're a manager, they can change any reservation.
            if ( $operator->is_manager( 'Stock Control' => 'Reservation' ) ) {

                return 1, '';

            # If the operator is an 'operator' then they can only change an
            # operator if the reservation is their own.
            } elsif ( $operator->is_operator( 'Stock Control' => 'Reservation' ) ) {

                return $self->operator_id == $operator->id
                    ? ( 1, '' )
                    : ( 0, "the operator '$operator_name' cannot change the operator of reservations they do not own" );

            } else {

                return 0, "the operator '$operator_name' does not have permission to change the operator of this reservation";

            }

        } else {

            return 0, "the operator '$operator_name' must be in one of the following departments: Customer Care, Customer Care Manager, Personal Shopping or Fashion Advisor";

        }

    } else {

        return 0, 'the operator making the change cannot be found';

    }

}

=head2 is_for_pre_order

    $boolean    = $self->is_for_preorder;

Returns TRUE or FALSE depending on whether the Reservation is for a Pre-Order or not.

=cut

sub is_for_pre_order {
    my $self    = shift;
    return ( $self->pre_order_items->count() ? 1 : 0 );
}

=head2 set_commission_cut_off_date

Sets '$reservation->commission_cut_off_date' column for reservation for configured channels.
It does not update the column for PreOrder reservation.

=cut

sub set_commission_cut_off_date {
    my $self = shift;

    # return if reservation is for pre_order
    return if $self->is_for_pre_order;

    my $commission_date = get_reservation_commission_cut_off_date(
            $self->result_source->schema,
            $self->channel_id
    );

    if( $commission_date ) {
        # Rather than using DateTime object directly when updating reservation
        # we are using date string explictly due to TimeZone issue.
        $commission_date = $commission_date->ymd('-'). ' '. $commission_date->hms(':');
        # update reservation
        $self->update( { commission_cut_off_date => $commission_date } );
    }

    return;

}

=head2 is_owned_by_ps_or_fa

    $boolean = $self->is_owned_by_ps_or_fa;

Returns TRUE if Reservation operator is from department Personal Shopper or Fashion Advisor
else returns FALSE.

=cut

sub is_owned_by_ps_or_fa {
    my $self = shift;

    return ( number_in_list( $self->operator->department_id,
          $DEPARTMENT__PERSONAL_SHOPPING, $DEPARTMENT__FASHION_ADVISOR )
        ? 1 : 0 );
}


=head2 can_edit_reservation

    $boolean = $self->can_edit_reservation( $operator );

Checks if C<operator> can edit reservation, by comparing there department with reservation operator
department.

 * Only Personal Shopper/Fashion Advisor can edit each-other reservations
 * no other department is allowed to edit Personal Shopper/Fashion Advisor reservations.

If the above criterion are met, passed in operator can edit the reservation.

=cut

sub can_edit_reservation {
    my $self     = shift;
    my $operator = shift;

    # Get operator obj
    $operator = $self->result_source->schema->resultset('Public::Operator')->find( $operator )
        unless ref( $operator ) =~ m/Public::Operator$/;

    my $operator_dept_id = $operator->department_id;

    # if reservation is not of PS/FA => any department can edit it.
    return 1 unless $self->is_owned_by_ps_or_fa;

    my @allowed_dept = ( $DEPARTMENT__PERSONAL_SHOPPING, $DEPARTMENT__FASHION_ADVISOR );

    if ( number_in_list( $operator_dept_id, @allowed_dept ) )
    {
        return 1;
    }

    return 0;

}

1;
