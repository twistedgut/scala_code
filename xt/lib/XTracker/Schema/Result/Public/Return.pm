use utf8;
package XTracker::Schema::Result::Public::Return;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.return");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "return_id_seq",
  },
  "shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "rma_number",
  { data_type => "varchar", is_nullable => 0, size => 24 },
  "return_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "exchange_shipment_id",
  { data_type => "integer", is_nullable => 1 },
  "pickup",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "creation_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "expiry_date",
  { data_type => "date", is_nullable => 1 },
  "cancellation_date",
  { data_type => "date", is_nullable => 1 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("return__rma_number_unique", ["rma_number"]);
__PACKAGE__->has_many(
  "link_delivery__returns",
  "XTracker::Schema::Result::Public::LinkDeliveryReturn",
  { "foreign.return_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_return_renumerations",
  "XTracker::Schema::Result::Public::LinkReturnRenumeration",
  { "foreign.return_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_routing_export__returns",
  "XTracker::Schema::Result::Public::LinkRoutingExportReturn",
  { "foreign.return_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_routing_schedule__returns",
  "XTracker::Schema::Result::Public::LinkRoutingScheduleReturn",
  { "foreign.return_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_sms_correspondence__returns",
  "XTracker::Schema::Result::Public::LinkSmsCorrespondenceReturn",
  { "foreign.return_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_email_logs",
  "XTracker::Schema::Result::Public::ReturnEmailLog",
  { "foreign.return_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_items",
  "XTracker::Schema::Result::Public::ReturnItem",
  { "foreign.return_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_notes",
  "XTracker::Schema::Result::Public::ReturnNote",
  { "foreign.return_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "return_status",
  "XTracker::Schema::Result::Public::ReturnStatus",
  { id => "return_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "return_status_logs",
  "XTracker::Schema::Result::Public::ReturnStatusLog",
  { "foreign.return_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "shipment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->many_to_many("renumerations", "link_return_renumerations", "renumeration");
__PACKAGE__->many_to_many(
  "routing_exports",
  "link_routing_export__returns",
  "routing_export",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nGX+IS+t76EifTFS4oACcw

=head1 NAME

XTracker::Schema::Result::Public::Return

=cut

use Moose;
with 'XTracker::Schema::Role::RoutingSchedule',
     'XTracker::Schema::Role::CanUseCSM',
     'XTracker::Schema::Role::Hierarchy';

use XTracker::Config::Local;
use XTracker::Constants::FromDB qw/
    :return_status
    :renumeration_status
    :return_type
    :renumeration_type
/;
use MooseX::Params::Validate;
use MooseX::Types::Common::Numeric qw/PositiveInt/;

__PACKAGE__->has_many(
    'link_return_renumeration' => 'Public::LinkReturnRenumeration',
    { 'foreign.return_id' => 'self.id' },
);

__PACKAGE__->might_have(
    'link_order__shipment' => 'Public::LinkOrderShipment',
    { 'foreign.shipment_id' => 'self.shipment_id' },
    { cascade_delete => 0 },
);
# TODO: Add a FK for this
__PACKAGE__->belongs_to(
  "exchange_shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "exchange_shipment_id" },
);

__PACKAGE__->many_to_many(
    routing_schedules => 'link_routing_schedule__returns' => 'routing_schedule'
);

__PACKAGE__->many_to_many(
    deliveries => 'link_delivery__returns' => 'delivery'
);

sub is_cancelled {
    $_[0]->return_status_id == $RETURN_STATUS__CANCELLED;
}

=head1 METHODS

=head2 set_lost( $operator_id )

Mark a return as C<Lost> and update the logs.

=cut

sub set_lost {
    my ( $self, $operator_id ) = @_;

    return $self->update_status( $RETURN_STATUS__LOST, $operator_id );
}

=head2 set_awaiting_return( $operator_id )

Mark a return as C<Awaiting Return> and update the logs.

=cut

sub set_awaiting_return {
    my ( $self, $operator_id ) = @_;

    return $self->update_status( $RETURN_STATUS__AWAITING_RETURN, $operator_id );
}

=head2 set_complete( $operator_id )

Update the return's status to C<Complete> and log it.

=cut

sub set_complete {
    my ( $self, $operator_id ) = @_;
    return $self->update_status( $RETURN_STATUS__COMPLETE, $operator_id );
}

=head2 is_lost

Returns a true value if the return's status is C<Lost>.

=cut

sub is_lost {
    return shift->return_status_id == $RETURN_STATUS__LOST;
}

=head2 update_status( $status_id, $operator_id )

Update a return to the given status and log the change.

=cut

sub update_status {
    my ( $record, $status_id, $operator_id ) = @_;

    $record->result_source->schema->txn_do(
        sub {
            $record->update( { return_status_id => $status_id } );

            $record->return_status_logs->create(
                {
                    return_id        => $record->id,
                    return_status_id => $status_id,
                    operator_id      => $operator_id,
                }
            );
        }
    );
    return $record;
}

sub logs {
    my ($self) = @_;

    $self->return_status_logs->search_rs(
        {},
        { order_by => { -asc => 'date'},
          prefetch => ['status', 'operator']
        }
    );
}

sub item_logs {
    my ($self) = @_;

    $self->return_items->search_related_rs('return_item_status_logs',
        {},
        { order_by => { -asc => 'date'},
          prefetch => ['status', 'operator']
        }
    );
}

=head2 split_if_needed

    $return->split_if_needed;

This will Split Off 'Passed QC' and/or 'Failed QC Awaiting Decision' Return Items
onto NEW Renumeration records according to the following rules:

    * If there are NO Passed QC or Failed QC AD items then nothing will be split.
    * If the Number of Passed Items is less than the Total Number of Return Items, then
      split off Passed QC items onto a new Renumeration.
    * If the Number of Failed QC Awaiting Decision items is less than the Total Number
      of Return Items minus any Passed QC items, then split off Failed QC AD items
      onto a new Renumeration.

If a split is required then it will split off the items from every Renumeration record
that is linked to the Return.

Please Note:
Total Number of Return Items EXCLUDES any that have been Cancelled or have Statuses past
the QC Stage (page) such as 'Failed QC - Rejected', 'Failed QC - Accepted', 'Put Away' etc.

=cut

sub split_if_needed {
    my ( $record ) = shift;

    # get the Result Sets for the list of either Passed
    # or Failed Return Items that might be split off
    my $passed_qc_rs    = $record->return_items->passed_qc;
    my $failed_qc_rs    = $record->return_items->failed_qc_awaiting_decision;

    # the 'Total Return Items' minus any Items that are beyond the QC Stage
    my $total_items_at_or_before_qc_stage = $record->return_items->active_item_count
                                                - $record->return_items->beyond_qc_stage->count;

    # get the counts of items, including the Total
    # Return Items minus Passed QC and minus Failed QC
    my $total_passed_qc         = $passed_qc_rs->count;
    # this gives the 'Total Return Items' minus any Passed QC Items
    my $total_minus_passed_qc    = $total_items_at_or_before_qc_stage - $total_passed_qc;
    my $total_failed_qc         = $failed_qc_rs->count;
    # this gives the 'Total Return Items' minus any 'Passed QC Items' and minus any 'Failed QC Items'
    my $total_minus_failed_qc    = $total_minus_passed_qc - $total_failed_qc;


    # set flags based on:
    #   Split off Passed QC - There ARE 'Passed QC Items' and
    #                         they DONT'T equal the 'Total Return Items'
    #   Split off Failed QC - There ARE 'Failed QC Items' and they DON'T equal
    #                         the 'Total Return Items' minus any 'Passed QC Items'
    my $split_passed_qc = ( $total_passed_qc > 0 && $total_minus_passed_qc > 0 ? 1 : 0 );
    my $split_failed_qc = ( $total_failed_qc > 0 && $total_minus_failed_qc > 0 ? 1 : 0 );

    # just return if nothing needs splitting off
    return      if ( !$split_passed_qc && !$split_failed_qc );

    # build up a list of Result Sets that need
    # to be Split Off based on the above flags
    my @item_rs_to_split_off;
    push @item_rs_to_split_off, $passed_qc_rs       if ( $split_passed_qc );
    push @item_rs_to_split_off, $failed_qc_rs       if ( $split_failed_qc );

    # Loop through ALL Renumerations for the Return
    my @link_return_renumerations = $record->link_return_renumeration->all;
    foreach my $link_return_renumeration ( @link_return_renumerations ) {
        # for each Renumeration split off each Result Set of Return Items
        foreach my $rs ( @item_rs_to_split_off ) {
            $link_return_renumeration->renumeration->split_me( $rs );
        }
    }

    return;
}

=head2 check_complete

Returns a hashref that with keys for C<is_complete> and C<exchange_complete>.
C<is_complete> is true if all items have undergone QC and C<exchange_complete>
is true if all (if any) exchange items have undergone QC.

=cut

sub check_complete {
    my $self = shift;

    my $is_complete = 1;
    for my $return_item ( $self->return_items->all ) {
        next if $return_item->has_been_qced;
        $is_complete = 0;
        next unless $return_item->is_exchange;
        return { is_complete => 0, exchange_complete => 0 };
    }
    return { is_complete => $is_complete, exchange_complete => 1 };
}

=head2 return_item_from_shipment_item

Give an ShipmentItem (or the id of one) find the matching ReturnItem.

Only returns items which are B<not> cancelled.

=cut

sub return_item_from_shipment_item {
  my ($self, $shipment_item) = @_;

  my $id = ref($shipment_item) ? $shipment_item->id : $shipment_item;

  $self->return_items->search({
    shipment_item_id => $id
  })->not_cancelled->first;
}

=head2 log_correspondence

    $return->log_correspondence( $CORRESPONDENCE_TEMPLATES__??, $operator_id );

This will log a Correspondence Template Id that was sent for a Return along with the Operator Id of who sent the correspondence.

It will create a 'return_email_log' record.

=cut

sub log_correspondence {
    my ( $self, $template_id, $operator_id )    = @_;

    return $self->create_related( 'return_email_logs', {
                                            correspondence_templates_id => $template_id,
                                            operator_id                 => $operator_id,
                                    } );
}

=head2 get_correspondence_logs {

    $result_set = $return->get_correspondence_logs();

Will return all Records from the 'return_email_log' table for this Return.

=cut

sub get_correspondence_logs {
    my $self    = shift;

    return $self->return_email_logs;
}

=head2 reverse_return

Reverse some or all of the items in this return

param - operator_id : Identifier for the operatator that performed this action
param - return_items : Only schema ReturnItems passed will actually be reversed.

=cut

sub reverse_return {
    my ($self, $operator_id, $return_items) = validated_list(\@_,
        operator_id     => { isa => PositiveInt },
        return_items    => { isa => 'ArrayRef' },
    );

    $self->result_source()->schema()->txn_do(sub {
        $self->update_status($RETURN_STATUS__PROCESSING, $operator_id);

        # Only reverse the items that have been requested
        foreach my $return_item ( @$return_items ) {
            $return_item->reverse_item({
                operator_id => $operator_id,
            });
        }

        my @renumerations = $self->renumerations()->search( {
            renumeration_status_id => $RENUMERATION_STATUS__AWAITING_ACTION,
        } )->all;

        foreach my $renumeration (@renumerations) {
            $renumeration->update_status($RENUMERATION_STATUS__PENDING, $operator_id);
        }
    });

    return 1;
}

=head2 exchange_items

Returns all related return items that are 'Exchange' only, i.e.
C<$RETURN_TYPE__EXCHANGE>.

    my $return = $schema->resultset('Public::Return')->find( $id );
    my $exchange_items = $return->exchange_items;

    foreach my $exchange_item ( $exchange_items->all ) {

        # ...

    }

=cut

sub exchange_items {
    my $self = shift;

    $self->return_items->search( {
        return_type_id => $RETURN_TYPE__EXCHANGE,
    } );

}

=head2 get_total_charges_for_exchange_items

Get the totals of all charges relating to exchanged items and return a
HashRef containing C<total_unit_price>, C<total_tax>, C<total_duty> and
C<total_charge>, where C<total_charge> is the combined total.

    my $totals = $schema
        ->resultset('Public::Return')
        ->find( $id )
        ->get_total_charges_for_exchange_items;

    # Individual totals.
    print $totals->{total_unit_price};
    print $totals->{total_tax};
    print $totals->{total_duty};

    # Grand total.
    print $totals->{total_charge};

=cut

sub get_total_charges_for_exchange_items {
    my $self = shift;

    # Initialise the result to
    # be zero for all totals.
    my %result = (
        total_unit_price => 0,
        total_tax        => 0,
        total_duty       => 0,
        total_charge     => 0,
    );

    my $exchange_items = $self
        ->exchange_items
        ->not_cancelled;

    foreach my $exchange_item ( $exchange_items->all ) {

        # Get all the related renumeration items, using the shipment_item_id to
        # match the returns renumerations to the exchanges renumerations.
        my $renumeration_items = $self
            ->renumerations
            ->not_cancelled
            ->search_related( 'renumeration_items', {
                shipment_item_id => $exchange_item->shipment_item_id,
            } );

        foreach my $renumeration_item ( $renumeration_items->all ) {
        # For each of those renumeration items, update the totals.

            $result{total_unit_price} += abs( $renumeration_item->unit_price );
            $result{total_tax}        += abs( $renumeration_item->tax );
            $result{total_duty}       += abs( $renumeration_item->duty );

            # Now update the overall total.
            $result{total_charge} += (
                abs( $renumeration_item->unit_price )
                + abs( $renumeration_item->tax )
                + abs( $renumeration_item->duty )
            );

        }

    }

    return \%result;

}

=head2 get_debit_charges_for_exchange_items

Get the totals of all 'Card Debit' charges relating to exchanged items
and return a HashRef containing C<total_unit_price>, C<total_tax>,
C<total_duty> and C<total_charge>, where C<total_charge> is the combined
total.

    my $totals = $schema
        ->resultset('Public::Return')
        ->find( $id )
        ->get_debit_charges_for_exchange_items;

    # Individual totals.
    print $totals->{total_unit_price};
    print $totals->{total_tax};
    print $totals->{total_duty};

    # Grand total.
    print $totals->{total_charge};

=cut

sub get_debit_charges_for_exchange_items {
    my $self = shift;

    # Initialise the result to
    # be zero for all totals.
    my %result = (
        total_unit_price => 0,
        total_tax        => 0,
        total_duty       => 0,
        total_charge     => 0,
    );

    my $exchange_items = $self
        ->exchange_items
        ->not_cancelled;

    foreach my $exchange_item ( $exchange_items->all ) {

        # Get all the related 'Card Debit' renumeration items, using the
        # shipment_item_id to match the returns renumerations to the exchanges
        # renumerations.
        my $renumeration_items = $self
            ->renumerations
            ->not_cancelled
            ->search( {
                renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT,
            } )
            ->search_related( 'renumeration_items', {
                shipment_item_id => $exchange_item->shipment_item_id,
            } );

        foreach my $renumeration_item ( $renumeration_items->all ) {
        # For each of those renumeration items, update the totals.

            # Update the individual totals.
            $result{total_unit_price} += $renumeration_item->unit_price;
            $result{total_tax}        += $renumeration_item->tax;
            $result{total_duty}       += $renumeration_item->duty;

            # Now update the overall total.
            $result{total_charge} += (
                $renumeration_item->unit_price
                + $renumeration_item->tax
                + $renumeration_item->duty
            );

        }

    }

    return \%result;

}

=head2 has_at_least_one_debit_card_renumeration

Returns either True or False depending on whether there is a 'Card Debit'
Renumeration record linked to the Return.

    my $has_card_debit = $schema
        ->resultset('Public::Return')
        ->find( $id )
        ->has_at_least_one_debit_card_renumeration;

    if ( $has_card_debit ) {

        print "Return has an associated Card Debit\n";

    } else {

        print "Return does not have an associated Card Debit\n";

    }

=cut

sub has_at_least_one_debit_card_renumeration {
    my $self = shift;

    my $renumerations = $self
        ->renumerations
        ->not_cancelled
        ->search( {
            'renumeration.renumeration_type_id' => $RENUMERATION_TYPE__CARD_DEBIT,
        } );

    foreach my $renumeration ( $renumerations->all ) {

        # This is copied from the Public::Renumeration->grand_total
        # method, as we don't want abs[olute] values of gift_credit,
        # store_credit & gift_voucher.
        my $total_value = $renumeration->total_value
            + $renumeration->shipping
            + $renumeration->misc_refund
            - $renumeration->gift_credit
            - $renumeration->store_credit
            - $renumeration->gift_voucher;

        return 1
            if $total_value > 0;

    }

    return 0;
}

1;
