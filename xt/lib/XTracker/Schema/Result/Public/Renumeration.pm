use utf8;
package XTracker::Schema::Result::Public::Renumeration;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.renumeration");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "renumeration_id_seq",
  },
  "shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "invoice_nr",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "renumeration_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "renumeration_class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "renumeration_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipping",
  {
    data_type => "numeric",
    default_value => "0.000",
    is_nullable => 0,
    size => [10, 3],
  },
  "misc_refund",
  {
    data_type => "numeric",
    default_value => "0.000",
    is_nullable => 0,
    size => [10, 3],
  },
  "alt_customer_nr",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "gift_credit",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 0,
    size => [10, 3],
  },
  "store_credit",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 0,
    size => [10, 3],
  },
  "currency_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "sent_to_psp",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "gift_voucher",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 0,
    size => [10, 3],
  },
  "renumeration_reason_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->might_have(
  "card_refund",
  "XTracker::Schema::Result::Public::CardRefund",
  { "foreign.invoice_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "currency",
  "XTracker::Schema::Result::Public::Currency",
  { id => "currency_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "link_return_renumerations",
  "XTracker::Schema::Result::Public::LinkReturnRenumeration",
  { "foreign.renumeration_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "renumeration_change_logs",
  "XTracker::Schema::Result::Public::RenumerationChangeLog",
  { "foreign.renumeration_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "renumeration_class",
  "XTracker::Schema::Result::Public::RenumerationClass",
  { id => "renumeration_class_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "renumeration_items",
  "XTracker::Schema::Result::Public::RenumerationItem",
  { "foreign.renumeration_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "renumeration_reason",
  "XTracker::Schema::Result::Public::RenumerationReason",
  { id => "renumeration_reason_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "renumeration_status",
  "XTracker::Schema::Result::Public::RenumerationStatus",
  { id => "renumeration_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "renumeration_status_logs",
  "XTracker::Schema::Result::Public::RenumerationStatusLog",
  { "foreign.renumeration_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "renumeration_tenders",
  "XTracker::Schema::Result::Public::RenumerationTender",
  { "foreign.renumeration_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "renumeration_type",
  "XTracker::Schema::Result::Public::RenumerationType",
  { id => "renumeration_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "shipment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->many_to_many("returns", "link_return_renumerations", "return");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xpO3zem5qTfPIXC69LBkYA

=head1 NAME

XTracker::Schema::Result::Public::Renumeration

=cut

use Moose;
with 'XTracker::Schema::Role::Hierarchy';

__PACKAGE__->might_have(
  "link_return_renumeration",
  "XTracker::Schema::Result::Public::LinkReturnRenumeration",
  { "foreign.renumeration_id" => "self.id" },
);

sub return {
    my $lrr = $_[0]->link_return_renumeration;
    return unless $lrr;
    return $lrr->return;
}

__PACKAGE__->many_to_many('tenders' => 'renumeration_tenders', 'tender');

use XTracker::Constants::FromDB qw{
    :renumeration_class
    :renumeration_status
    :renumeration_type
    :shipment_type
    :shipment_status
    :correspondence_templates
};

use XTracker::Config::Local qw(
    customercare_email
    get_namespace_names_for_psp
);

use XTracker::Constants qw( $APPLICATION_OPERATOR_ID );

use XTracker::EmailFunctions;


use XTracker::Database;
use XTracker::Database::Channel qw(get_channel_details);
use XTracker::Database::Return qw( get_return_info );
use XTracker::Database::Shipment qw( get_shipment_info );
use XTracker::Database::Invoice qw(
    adjust_existing_renum_tenders
    create_renum_tenders_for_order_tenders
    generate_invoice_number
    get_invoice_return
    update_sent_to_psp
    get_invoice_info
    get_invoice_item_info
);

use XTracker::Document::Invoice;
use XTracker::Error;
use XTracker::Logfile   qw( xt_logger );
use XTracker::PrintFunctions;
use XTracker::Vertex qw( :ALL );

use XTracker::Utilities qw(
    ucfirst_roman_characters
);

use Encode::Encoder qw(encoder);
use Try::Tiny;

=head1 NAME

XTracker::Schema::Result::Public::Renumeration

=head1 METHODS

=head2 is_cancelled

Returns a true value if the remuneration is B<Cancelled>.

=cut

sub is_cancelled {
    $_[0]->renumeration_status_id == $RENUMERATION_STATUS__CANCELLED;
}

=head2 is_complete

Returns a true value if the remuneration is B<Completed>.

=cut

sub is_completed {
    $_[0]->renumeration_status_id == $RENUMERATION_STATUS__COMPLETED;
}

=head2 is_printed

Returns a true value if the remuneration is B<Printed>.

=cut

sub is_printed {
    shift->renumeration_status_id == $RENUMERATION_STATUS__PRINTED;
}

=head2 is_pending

Returns a true value if the remuneration is B<Pending>.

=cut

sub is_pending {
    $_[0]->renumeration_status_id == $RENUMERATION_STATUS__PENDING;
}

=head2 is_awaiting_authorisation

Returns a true value if the renumeration is B<Awaiting Authorisation>

=cut

sub is_awaiting_authorisation {
    $_[0]->renumeration_status_id == $RENUMERATION_STATUS__AWAITING_AUTHORISATION;
}

sub for_return {
    $_[0]->renumeration_class_id == $RENUMERATION_CLASS__RETURN;
}

=head2 is_order_class

Returns a true value if the renumeration class is Order

=cut

sub is_order_class {
    shift->renumeration_class_id == $RENUMERATION_CLASS__ORDER;
}

=head2 for_gratuity

    $boolean = $self->for_gratuity;

Will Return TRUE or FALSE depending on whether the
Class of the Renumeration is 'Gratuity'.

=cut

sub for_gratuity {
    my $self    = shift;
    return ( $self->renumeration_class_id == $RENUMERATION_CLASS__GRATUITY ? 1 : 0 );
}

=head2 update_status

Update the status of the renumeration and log the change

param - $status_id : The new status id
param - $operator_id : The identifier for the user making the change

=cut

sub update_status {
    my ($self, $status_id, $operator_id) = @_;

    $self->result_source->schema->txn_do( sub {
        $self->update( { renumeration_status_id => $status_id } );

        $self->add_to_renumeration_status_logs({
            renumeration_status_id => $status_id,
            operator_id            => $operator_id,
        });
    });
    return $self;
}


=head2 split_me

    $self->split_me( $return_item_resultset );

This will split Renumeration Items for the current record that match the
Shipment Item Id on the passed in Return Items resultset off onto a new
Renumeration and then remove them from their original.

It will NOT split anything if ANY of the following are TRUE:

    * The current Renumeration is NOT in 'Pending' or 'Awaiting Authorisation' status.
    * The Renumeration contains ANY Items that are NOT in the list passed in (no point
      in splitting off any items if the current Renumeration only has all or some of
      those items).
    * The Renumeration contains NONE of the items that were passed in.

If a split is made for 'Passed QC' items then the 'shipping' and 'misc_refund' values
are copied to the NEW Renumeration and ZERO'd out on the original.

=cut

sub split_me {
    my ( $record, $return_item_rs ) = @_;

    # if the Renumeration is NOT in the correct Status then return
    return      unless ( $record->is_pending || $record->is_awaiting_authorisation );

    my $renumeration_item_rs = $record->renumeration_items;

    # check if the Renumeration has any Items that are not the
    # same as the the Return Items passed in, if it doesn't
    # then there's no point in splitting any items off
    my %shipment_item_ids       = map { $_->shipment_item_id => $_ } $return_item_rs->all;
    my $num_items_not_in_list   = $renumeration_item_rs->search( {
        shipment_item_id => { 'NOT IN' => [ keys %shipment_item_ids ] }
    } )->count;
    return          if ( !$num_items_not_in_list );

    # Renumeration Items to Split Off
    my @renumeration_items  = $renumeration_item_rs->search( {
        shipment_item_id => { 'IN' => [ keys %shipment_item_ids ] }
    } )->all;
    # no point going any further if there aren't any items to loop over
    return          if ( !@renumeration_items );

    # get a list of the renumeration tenders associated with the invoice
    # and get them in the reverse order in which they were applied, as
    # we are going to use these when creating renumeration tenders
    # for the new invoice. Yes order by rank ASC is the reverse.
    my @order_tenders;
    my $renum_tenders   = $record->renumeration_tenders
                                    ->search( {}, { join => 'tender', order_by => 'tender.rank ASC' } );
    if ( $renum_tenders ) {
        while ( my $renum_tender = $renum_tenders->next ) {
            push @order_tenders, $renum_tender->tender;
        }
    }

    # get the Return the '$return_item_rs' is for and any Exchange Shipment
    my $return            = $return_item_rs->reset->first->return;
    my $exchange_shipment = $return->exchange_shipment;
    # set a flag that indicates that it is possible to turn
    # the original or new Renumeration into a Charge if the
    # resulting Totals are negative.
    my $can_make_a_charge = (
             $exchange_shipment
        && ( $record->is_card_refund || $record->is_store_credit )
        ? 1
        : 0
    );

    my $schema  = $record->result_source->schema;
    my $split_renumeration_id;

    my $logger = xt_logger();
    # use this in log entries
    my $rma_number = $return->rma_number;

    # Loop through items in renumeration
    foreach my $renumeration_item ( @renumeration_items ) {
        # If they have not already been split do it
        if ( !$split_renumeration_id ) {

            # Get the Return Item for this Renumeration Item's Shipment Item Id.
            # we need its Status and Return Id all of which should be the same
            # for all the other Return Items so we only need to get it this once.
            my $return_item = $shipment_item_ids{ $renumeration_item->shipment_item_id };

            # set flag to split off Shipping Costs/Charges if Return Items passed in
            # are 'Passed QC', the Shipping Refund is in the 'shipping' field and
            # any shipping charges are in the 'misc_refund' field
            my $split_off_shipping_flag = ( $return_item->is_passed_qc ? 1 : 0 );

            $split_renumeration_id
                = $schema->resultset('Public::Renumeration')->create({
                    shipment_id             => $record->shipment_id,
                    invoice_nr              => q{},
                    renumeration_type_id    => $record->renumeration_type_id,
                    renumeration_class_id   => $record->renumeration_class_id,
                    renumeration_status_id  => $record->renumeration_status_id,
                    alt_customer_nr         => $record->alt_customer_nr,
                    currency_id             => $record->currency_id,
                    shipping                => ( $split_off_shipping_flag ? $record->shipping : 0.000 ),
                    misc_refund             => ( $split_off_shipping_flag ? $record->misc_refund : 0.000 ),
            })->id;

            if ( $split_off_shipping_flag && ( $record->shipping || $record->misc_refund ) ) {
                # if either of these columns has a value then
                # ZERO them both as the originals will be on
                # the NEW Renumeration created above
                $record->update( { shipping => 0.000, misc_refund => 0.000 } );
            }

            # Create a new return<->renumeration link
            $schema->resultset('Public::LinkReturnRenumeration')->create(
                {
                    return_id       => $return_item->return_id,
                    renumeration_id => $split_renumeration_id,
                }
            );
        }

        # Place the renumeration item in the newly created renumeration
        $renumeration_item->update(
            { renumeration_id => $split_renumeration_id, }
        );
    }

    if ( $split_renumeration_id ) {
        # get the new total for the original invoice
        my $orig_inv_new_total = $record->simple_sum_total_of_invoice;

        # start by assuming that this can be done
        my $can_adjust_tenders = 1;

        # if the new Total is less than zero then
        # the Renumeration should become a Charge
        if ( $orig_inv_new_total < 0 ) {
            if ( $can_make_a_charge ) {
                _post__split_me__convert_to_debit( "For RMA '${rma_number}', Original Invoice", $record, $exchange_shipment->discard_changes );
                $can_adjust_tenders = 0;    # don't adjust tenders as there is no need now it's a Charge
            }
            else {
                $logger->warn(
                    "For RMA '${rma_number}' - Found Negative Total after 'split_me' but can't change Original Renumeration to 'Card Debit': " .
                    "Renumeration Id: " . $record->id .
                    ", Shipment Id: " . $record->shipment_id
                );
            }
        }

        # adjust existing renumeration tenders to reflect the new total
        adjust_existing_renum_tenders( $record, $orig_inv_new_total )
                                if ( $can_adjust_tenders );

        # get the total for the new invoice
        my $new_invoice       = $schema->resultset('Public::Renumeration')->find( $split_renumeration_id );
        my $new_invoice_total = $new_invoice->simple_sum_total_of_invoice;

        if ( $new_invoice_total < 0 ) {
            if ( $can_make_a_charge ) {
                _post__split_me__convert_to_debit( "For RMA '${rma_number}', New Invoice", $new_invoice, $exchange_shipment->discard_changes );
                @order_tenders = ();        # don't create any renumeration tenders now the New Invoice is a Charge
            }
            else {
                $logger->warn(
                    "For RMA '${rma_number}' - Found Negative Total after 'split_me' but can't change New Renumeration to 'Card Debit': " .
                    "Renumeration Id: " . $new_invoice->id .
                    ", Shipment Id: " . $new_invoice->shipment_id
                );
            }
        }

        # create new renumeration tenders for the new invoice
        if ( @order_tenders ) {
            create_renum_tenders_for_order_tenders( $new_invoice, \@order_tenders );
        }
    }

    return;
}

# private method that will turn a Renumeration
# into a 'Card Debit', this is called at the end
# of the call to the 'split_me' method
sub _post__split_me__convert_to_debit {
    my ( $log_prefix, $renumeration, $exchange_shipment ) = @_;

    my $logger = xt_logger();

    if ( !$exchange_shipment->is_exchange ) {
        $logger->logcroak( $log_prefix . ", Shipment passed in is not an 'Exchange': " . $exchange_shipment->id );
    }

    my $current_type = $renumeration->renumeration_type->type;

    # make all the values flip their signs by multiplying them by -1
    $renumeration->update( {
        renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT,
        shipping    => $renumeration->shipping    * -1,
        misc_refund => $renumeration->misc_refund * -1,
    } );

    # make all the item values flip their signs by multiplying them by -1
    my @items = $renumeration->renumeration_items->all;
    foreach my $item ( @items ) {
        $item->update( {
            unit_price => $item->unit_price * -1,
            tax        => $item->tax        * -1,
            duty       => $item->duty       * -1,
        } );
    }

    # for Charges it doesn't make sense to have any 'renumeration_tender' records
    $renumeration->delete_related('renumeration_tenders');

    # if the current status of the Exchange Shipment is 'Return Hold'
    # then update it to 'Exchange Hold' now there is a Charge for it
    my $changed_exchange_shipment_status = 0;
    if ( $exchange_shipment->is_on_return_hold ) {
        $exchange_shipment->update_status(
            $SHIPMENT_STATUS__EXCHANGE_HOLD,
            $APPLICATION_OPERATOR_ID,
        );
        $changed_exchange_shipment_status = 1;
    }

    # log what has happened
    $logger->info(
        "${log_prefix} - Found Negative Total after 'split_me' and have changed Renumeration Type to 'Card Debit' from '${current_type}': " .
        "Renumeration Id: " . $renumeration->id .
        ", Shipment Id: " . $renumeration->shipment_id .
        (
            $changed_exchange_shipment_status
            ? ", also changed Exchange Shipment Status to 'Exchange Hold', Exchange Shipment Id: " . $exchange_shipment->id
            : ""
        ),
    );

    return;
}


sub completion_date {
    my ($self) = @_;

    my $log = $self->renumeration_status_logs->search({
      renumeration_status_id => $RENUMERATION_STATUS__COMPLETED
    })->first;

    return $log->date if $log;
}

=head2 total_value

This sub returns the sum of the renumeration's renumeration_items' unit_price,
tax and duty.

=cut

sub total_value {
    my ($self) = @_;

    my $rs = $self->renumeration_items;

    return ( $rs->get_column('unit_price')->sum || 0 )
         + ( $rs->get_column('tax')->sum || 0 )
         + ( $rs->get_column('duty')->sum || 0 );
}

=head2 grand_total

This sub sums gift_credit, shipping, store_credit and misc_refund columns to
the value returned by C<$self->grand_total>.

=head3 Note

'misc_refund' can be positive or negative.

=cut

sub grand_total {
    return $_[0]->total_value
         + $_[0]->shipping
         + $_[0]->misc_refund
         - abs($_[0]->gift_credit)
         - abs($_[0]->store_credit)
         - abs($_[0]->gift_voucher);
}

=head2 simple_sum_total_of_invoice

    $decimal = $self->simple_sum_total_of_invoice;

This just adds up all the values for the renumeration including the
sum of all the renumeration items. It doesn't attempt convert
negative values to positive or assume that some values should
be negative, it just adds up everything.

=cut

sub simple_sum_total_of_invoice {
    my $self = shift;

    return
        $self->total_value      # gets the total of all the Items
      + $self->shipping
      + $self->misc_refund
      + $self->gift_credit
      + $self->store_credit
      + $self->gift_voucher;
}

# Wow this needs some refactoring
sub generate_invoice {
    my ( $self, $print_args ) = @_;

    my $printer = $print_args->{printer};
    my $copies  = $print_args->{copies};

    eval {
      my $shipment = $self->shipment;
      my $invoice  = XTracker::Document::Invoice
          ->new( shipment => $shipment );

      create_document( $invoice->basename, $invoice->template_path, $invoice->gather_data );

      # We can return unless we want to print stuff ( and log it )
      return unless $printer;

      my $printer_info = get_printer_by_name( $printer );
      if ( %{$printer_info||{}} ) {
          # if it's a Gift shipment and the 'no_print_if_gift' argument
          # has been passed then don't actually print the file as
          # for Gift shipments the Invoice was just being thrown away
          if ( $shipment->gift && $print_args->{no_print_if_gift} ) {
              # Will still need to log the invoice though so put a
              # message in the printer used section to indicate what happened
              $printer_info->{name}   = 'Generated NOT Printed';
          }
          else {
              print_document( $invoice->basename, $printer_info->{lp_name}, $copies );
          }

          $invoice->log_document($printer_info->{name});
      }
    };

    if ( my $error = $@ ) {
        die "Couldn't create document: $@";
    }
    return;
}

sub get_invoice_date {
    my ( $self ) = @_;
    my $rsl = $self->renumeration_status_logs
                ->search(
                    {renumeration_status_id => $RENUMERATION_STATUS__COMPLETED}
                )->slice(0,0)
                ->single;

    return $rsl->date if $rsl;
    return;
}

=head2 is_card_refund

Returns a true value if the renumeration_type of object is 'Card Refund'.
Returns 0 on false to allow 'IF's in template.

=cut

sub is_card_refund {
    return 1 if $_[0]->renumeration_type_id == $RENUMERATION_TYPE__CARD_REFUND;
    return 0;
}

=head2 is_store_credit

Returns a true value if the renumeration_type of object is 'Store Credit'.
Returns 0 on false to allow 'IF's in template.

=cut

sub is_store_credit {
    return 1 if $_[0]->renumeration_type_id == $RENUMERATION_TYPE__STORE_CREDIT;
    return 0;
}

=head1 B<refund_to_customer>

Processes a refund and marks the renumeration (invoice) as complete.

Accepts a HASH-Ref containing the following parameters:
 * refund_and_complete (required)   - Process
 * message_factory (required)       - A message factory object.
 * operator_id (optional)           - The operator that is performing the update, defaults
                                      to APPLICATION_OPERATOR_ID.
 * dbh_override (optional)          - Provides a new database connection for the repeated
                                      update of sent_to_psp (using a seperate connection).

    refund_to_customer( {
        refund_and_complete => 1,
        message_factory     => $message_factory,
        operator_id         => $operator_id,
        dbh_override        => $dbh,
    } );

=cut

sub refund_to_customer {
    my ( $self, $args ) = @_;

    die "refund_to_customer: Missing required parameter 'refund_and_complete'"
        unless defined $args->{refund_and_complete};

    die "refund_to_customer: Missing required parameter 'message_factory'"
        unless $args->{message_factory};

    my $operator_id = $args->{operator_id} || $APPLICATION_OPERATOR_ID;
    my $schema      = $self->result_source->schema;
    my $dbh         = $schema->storage->dbh;

    # skip if invoice completed or cancelled
    return if (
        ( $self->discard_changes->sent_to_psp && !$args->{no_reset_psp_update} )||
        $self->renumeration_status_id == $RENUMERATION_STATUS__COMPLETED ||
        $self->renumeration_status_id == $RENUMERATION_STATUS__CANCELLED ||
        $self->renumeration_type_id == $RENUMERATION_TYPE__CARD_DEBIT   # can't Refund a Debit, see Bug: CANDO-816
    );

    if ( $self->renumeration_class_id == $RENUMERATION_CLASS__RETURN ) {

        # check to see if the RMA has been cancelled
        $self->check_rma_not_cancelled;

    }

    $self->_isolated_update_sent_to_psp( 1, $args->{dbh_override} )     unless $args->{no_reset_psp_update};

    # Card Refund (processed via Payment Service)
    if ( $args->{refund_and_complete} ) {

        if ($self->renumeration_type_id == $RENUMERATION_TYPE__STORE_CREDIT) {
            # Store Credit - Website credit record.

            $args->{message_factory}->transform_and_send('XT::DC::Messaging::Producer::Order::StoreCreditRefund', { renumeration => $self, operator_id => $operator_id } );

        } elsif ($self->renumeration_type_id == $RENUMERATION_TYPE__CARD_REFUND) {
            # Card Refund - process via PSP service.

            # Check we have an order_shipment (relationship is 'might_have').
            if ( my $order_shipment = $self->shipment->order ) {

                # Get the related payment (if there is one).
                if ( my $payment = $order_shipment->payments->first ) {

                    my $total_amount = $self->total_value
                                     + $self->shipping
                                     + $self->misc_refund
                                     + $self->gift_credit
                                     + $self->store_credit
                                     + $self->gift_voucher;

                    if( $total_amount == 0 ) {
                        my $error_msg = "Cancelled Refund for Order Number:". $self->shipment->order->order_nr ." as $total_amount amount refund is invalid";
                        xt_logger->warn( $error_msg);
                        xt_success($error_msg);
                        $self->update_status( $RENUMERATION_STATUS__CANCELLED, $operator_id );
                        return;
                    } elsif ( $total_amount < 0 ) {
                        xt_logger->warn( "Negative Refund amount: ". $total_amount. " for  Order Number: ". $self->shipment->order->order_nr);
                    }
                    # total like the function 'get_invoice_value' which
                    # doesn't use 'abs' which is what $self->grand_total does
                    $payment->psp_refund( $total_amount, $self->format_items_for_refund );

                } else {

                    die 'Order does not have a payment.';

                }

            } else {

                die 'Shipment does not have an order.';

            }

        } else {
            # Shouldn't get this far so die.

            die 'Unexpected invoice type: '.$self->renumeration_type_id;

        }

    }

    # update invoice as 'completed' and write invoice number back into database.
    $self->update_status( $RENUMERATION_STATUS__COMPLETED, $operator_id );
    $self->update( { invoice_nr => generate_invoice_number( $dbh ) } );

    # refund now complete, perform secondary tasks triggered by completion.

    # release Exchange Shipments if necessary.
    $self->_release_exchange_shipment( $operator_id );

    # process Vertex invoice if required.
    if ( use_vertex_for_invoice($dbh, { invoice_id => $self->id }) ) {

        my $invoice_result = create_vertex_invoice_from_xt_id( $dbh, { invoice_id => $self->id } );

    }

    # Send email to customer.
    $self->_send_completion_email( $dbh, $operator_id );

    return;
}

=head2 format_shipping_as_refund_line_item

Formats the C<shipping> amount to be used when being sent to the PSP as part of a refund. Returns a HashRef containing the following keys:

sku     System Config value for PSPNamespace -> shipping_sku.
name    System Config value for PSPNamespace -> shipping_name.
amount  The value of the C<shipping> column mulitplied by on hundred.

    my $hashref = $self->format_shipping_as_refund_line_item;

=cut

sub format_shipping_as_refund_line_item {
    my $self = shift;

    my $names_for_psp = get_namespace_names_for_psp( $self->result_source->schema );

    return {
        sku     => $names_for_psp->{shipping_sku},
        name    => $names_for_psp->{shipping_name},
        amount  => $self->shipping * 100,
    };

}

=head2 format_items_for_refund

Returns an ArrayRef of HashRefs formatted for the call to the PSP, where
each HashRef contains the keys C<sku>, C<name>, C<amount>, C<vat> and C<tax>.
The data comes from the C<format_shipping_as_refund_line_item> method and the
C<format_as_refund_line_item> method on each associated renumeration item.

    my $arrayref_of_items = $self->format_items_for_refund;

=cut

sub format_items_for_refund {
    my $self = shift;

    # Always add all the renumeration items to the list.
    my @items =
        map { $_->format_as_refund_line_item }
        $self->renumeration_items->order_by_id->all;

    # Only add the shipment item if the shipping charge is greater than zero.
    push( @items, $self->format_shipping_as_refund_line_item )
        if $self->shipping > 0;

    # Return a specific HashRef structure for each item, because this method
    # is authoritive on the format.
    return [
        map {{
            sku     => length( $_->{sku}  ) ? $_->{sku}  : 'UNKNOWN',
            name    => length( $_->{name} ) ? $_->{name} : 'Unknown Product',
            amount  => $_->{amount} || 0,
            vat     => $_->{vat}    || 0,
            tax     => $_->{tax}    || 0,
        }} @items
    ];

}

sub check_rma_not_cancelled {
    my $self = shift;

    # check to see if the RMA for the invoice has been cancelled before completing the Refund
    # if it has then die because we shouldn't be refunding Cancelled Returns

    my $return = $self->return;
    if ( defined $return ) {
        if ( $return->is_cancelled ) {
            die 'RMA (' . $return->rma_number . ') linked to the invoice has been Cancelled, please investigate and then manually Complete or Cancel the Invoice';
        }
    }

    return;
}

# if a Renumeration is part of a Return with an Exchange Shipment
# this private method called from 'refund_to_customer' checks
# to see whether the Exchange Shipment can be released from
# being on 'Exchange Hold'.
sub _release_exchange_shipment {
    my ($self, $operator_id) = @_;

    my $dbh = $self->result_source->schema->storage->dbh;

    # check if return linked to invoice
    my $return_id = get_invoice_return( $dbh, $self->id );

    if ( $return_id > 0 ) {
        # get info for return linked to invoice
        my $return_info = get_return_info( $dbh, $return_id );

        # if return has exchange shipment tied to it check status release if required
        if ( $return_info->{exchange_shipment_id} ) {
            my $schema   = $self->result_source->schema;
            my $shipment = $schema->resultset('Public::Shipment')->find( $return_info->{exchange_shipment_id} );

            # exchange is on exchange hold - check if it can be released
            if ( $shipment->is_on_exchange_hold ) {
                my $return = $schema->resultset('Public::Return')->find( $return_id );

                # get a count of any outstanding Debit renumerations that haven't been Completed yet
                my $outstanding_charges = $return->renumerations
                                                    ->card_debit_type
                                                        ->not_yet_complete
                                                            ->count;
                # check to see if all the Exchange Items have been returned & QC'd
                my $return_data = $return->check_complete;

                if ( !$outstanding_charges && $return_data->{exchange_complete} ) {
                    $shipment->update_status(
                        $SHIPMENT_STATUS__PROCESSING, $operator_id
                    );
                }
                elsif ( !$outstanding_charges ) {
                    # if there aren't any outstanding Debits to be Completed
                    # but the Items haven't Passed QC yet, then set the
                    # Exchange Shipment to 'Return Hold'
                    $shipment->update_status(
                        $SHIPMENT_STATUS__RETURN_HOLD, $operator_id
                    );
                }
                else {
                    # leave as is
                }
            }
        }
    }

    return;

}

sub _isolated_update_sent_to_psp {
    my ( $self, $sent_to_psp, $dbh_override ) = @_;

    die '_isolated_update_sent_to_psp: Requires $sent_to_psp.'
        unless $sent_to_psp;

    # Get a new database connection (using readonly for auto-commit), if
    # an override has not been supplied.
    my $dbh_new = $dbh_override
               || XTracker::Database::xtracker_schema_no_singleton()->storage->dbh;
    update_sent_to_psp( $dbh_new, $self->id, $sent_to_psp );

    # Close the database connection if no override was passed in.
    $dbh_new->disconnect unless $dbh_override;

    # Refresh the current object.
    $self->discard_changes;
}

sub _send_completion_email {
    my ( $self, $dbh, $operator_id ) = @_;

    my $order   = $self->shipment->order;
    return      if ( !$order );     # If Renumeration not for an Order - not likely but just in case

    # use this in a log message should the need arise
    my $order_number;

    try {
        $order_number   = $order->order_nr;

        my $channel_info                = get_channel_details( $dbh, $order->channel->name );
        my $invoice_info                = get_invoice_info( $dbh, $self->id );
        $invoice_info->{total_value}    = sprintf( '%0.2f', ( $self->total_value
                                                                 + $self->shipping
                                                                 + $self->misc_refund
                                                                 + $self->gift_credit
                                                                 + $self->store_credit
                                                                 + $self->gift_voucher ) );
        $invoice_info->{invoice_number} = $self->invoice_nr;

        if ( defined $invoice_info->{alt_customer_nr}
         and $invoice_info->{alt_customer_nr} == 0
        ) {

            my $email_data;
            my @ship_id;

            $email_data->{invoice}                      = $invoice_info;
            $email_data->{invoice_items}                = get_invoice_item_info( $dbh, $invoice_info->{id} );
            $email_data->{invoice_address}{first_name}  = ucfirst_roman_characters( $invoice_info->{first_name} );
            $email_data->{channel}                      = $channel_info;
            $email_data->{invoice}{total}               = $invoice_info->{total_value};
            $email_data->{payment_info}                 = $self->shipment->get_payment_info_for_tt;

            my $schema  = $self->result_source->schema;

            # use a standard placeholder for the Order Number
            $email_data->{order_number} = $order->order_nr;
            my $email_info  = get_and_parse_correspondence_template( $schema, $CORRESPONDENCE_TEMPLATES__CREDIT_FSLASH_DEBIT_COMPLETED, {
                                                                channel     => $order->channel,
                                                                data        => $email_data,
                                                                base_rec    => $self,
                                                            } );
            my $from_email  = customercare_email( $channel_info->{config_section}, {
                schema  => $schema,
                locale  => $order->customer->locale,
            } );

            my $email_sent  = send_customer_email( {
                                            to          => $order->email,
                                            from        => $from_email,
                                            subject     => $email_info->{subject},
                                            content     => $email_info->{content},
                                        } );

            if ($email_sent == 1){
                $self->shipment->log_correspondence( $CORRESPONDENCE_TEMPLATES__CREDIT_FSLASH_DEBIT_COMPLETED, $operator_id );
            }
        }
    }
    catch {
        my $err = $_;

        my $logger = xt_logger();
        $logger->warn(
            "Invoice Id: '" . $self->id . "', " .
            "Error Sending Customer Email for Order: '" . ( $order_number // 'undef' ) . "': ${err}"
        );
    };

    return;
}

=head2 remove_return_items_and_cancel

    $self->remove_return_items_and_cancel( $array_ref_of_return_items, $operator_id );

This will remove from a 'renumeration' all 'renumeration_items' which match the 'shipment_item_id'
of the Return Items passed in. Once all have been removed a 'renumeration_change_log' is created and then
if the Renumeration has no items left, it will be 'Cancelled'.

Also adjusts the 'renumeration_tenders' for the changes made.

=cut

sub remove_return_items_and_cancel {
    my ( $self, $return_items, $operator_id ) = @_;

    return      if ( !$self->for_return || !$self->is_pending );

    # get pre_value
    my $pre_value   = $self->grand_total;

    foreach my $ret_item (@$return_items) {

        my $shipment_item_id    = $ret_item->shipment_item_id;

        # check if the invoice is for the return_item (which was passed in as args)
        if ( $self->link_return_renumeration->return_id == $ret_item->return_id ) {

            # delete renumeration_item
            my $rec = $self->renumeration_items
                        ->search( { shipment_item_id => $shipment_item_id } )
                            ->first;
            $rec->delete        if ( $rec );
        }
    } # end_of_foreach

    my $post_value  = $self->grand_total;

    if ( $post_value != $pre_value ) {
        # add change log
        $self->create_related( 'renumeration_change_logs', {
                        pre_value     => $pre_value,
                        post_value    => $post_value,
                        operator_id   => $operator_id,
                    } );

        # adjust existing renumeration tenders to reflect the new total
        adjust_existing_renum_tenders( $self, ( $post_value > 0.0001 ? $post_value : 0 ) );
    }

    if ( $self->renumeration_items->count() == 0 ) {
        $self->update_status( $RENUMERATION_STATUS__CANCELLED, $operator_id );
    }

    return;
}

=head2 get_reason_for_display

    $string = $self->get_reason_for_display;

This will Return the Renumeration Reason for the Invoice for Display purposes only. This
is to support backward compatibility for Gratuity Invoices created before Reasons existed
and also to support the fact that the 'Class' has been misused on several pages as the
Reason for the Invoice.

If no 'renumeration_reason' can be found then the Class description will be returned.

=cut

sub get_reason_for_display {
    my $self    = shift;

    my $reason  = $self->renumeration_reason;
    return (
        $reason
        ? $reason->reason . ( $reason->enabled ? '' : ' (Disabled)' )
        : $self->renumeration_class->class
    );
}

1;
