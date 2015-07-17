use utf8;
package XTracker::Schema::Result::Voucher::Code;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("voucher.code");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "voucher.code_id_seq",
  },
  "voucher_product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "code",
  { data_type => "text", is_nullable => 0 },
  "assigned",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "stock_order_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "expiry_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "source",
  { data_type => "text", is_nullable => 1 },
  "send_reminder_email",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("voucher_code_unique", ["code"]);
__PACKAGE__->has_many(
  "credit_logs",
  "XTracker::Schema::Result::Voucher::CreditLog",
  { "foreign.code_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_items",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { "foreign.voucher_code_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "stock_order_item",
  "XTracker::Schema::Result::Public::StockOrderItem",
  { id => "stock_order_item_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "tenders",
  "XTracker::Schema::Result::Orders::Tender",
  { "foreign.voucher_code_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "voucher_product",
  "XTracker::Schema::Result::Voucher::Product",
  { id => "voucher_product_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:N4+5rZ3YH3D/+2GWrMINEg

=head1 NAME

XTracker::Schema::Result::Voucher

=head1 METHODS

=head2 activate

Activate the voucher instance - adds the value of the voucher to the
credit_log.

=cut

sub activate {
    my ( $self ) = @_;
    $self->_log( $self->voucher_product->value );
    return $self;
}

=head2 is_active

Returns true if the voucher has credit_log entries (i.e. it has been
activated).

=cut

sub is_active {
    return 1 if $_[0]->credit_logs->count;
    return;
}

=head2 subtract_credit($amount, $shipment_id)

Subtract the given amount from the voucher. Logs a negative of the
abs($amount).

=cut

sub subtract_credit {
    my ( $self, $amount, $shipment_id ) = @_;
    $amount = abs $amount;
    die "The credit to detract is greater than the remaining credit on voucher ${[$self->id]}\n"
        if $amount > $self->remaining_credit;
    $self->_log(-$amount, $shipment_id);
    return $self;
}

=head2 remaining_credit

Return the remaining credit.

=cut

sub remaining_credit {
    return $_[0]->credit_logs->get_column('delta')->sum;
}

sub _log {
    my ( $self, $delta, $shipment_id ) = @_;

    return $self->add_to_credit_logs({
        delta => $delta,
        spent_on_shipment_id => $shipment_id,
    });
}

=head2 assigned_code

Sets the assigned date when the code was assigned to a shipment item and then 'activates' it.

=cut

sub assigned_code {
    my $self    = shift;

    $self->update( { assigned => DateTime->now() } );
    $self->activate;

    return;
}

=head2 order

Returns the order in which this voucher was bought. Returns undef if the
voucher doesn't have an order.

=cut

sub order {
    my ( $self ) = @_;
    my $shipment = $self->shipment_items->related_resultset('shipment')->first;
    return unless $shipment;
    return $shipment->order;
}

=head2 deactivate_code

Clears the 'assigned' field and removes all Credit Logs.

=cut

sub deactivate_code {
    my $self    = shift;

    my @logs    = $self->credit_logs->all;
    foreach my $log ( @logs ) {
        $log->delete;
    }

    $self->update( { assigned => undef } );

    return;
}

1;
