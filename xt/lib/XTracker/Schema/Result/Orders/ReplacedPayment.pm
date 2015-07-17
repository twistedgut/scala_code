use utf8;
package XTracker::Schema::Result::Orders::ReplacedPayment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("orders.replaced_payment");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "orders.replaced_payment_id_seq",
  },
  "orders_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "psp_ref",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "preauth_ref",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "settle_ref",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "fulfilled",
  { data_type => "boolean", is_nullable => 0 },
  "valid",
  { data_type => "boolean", is_nullable => 0 },
  "payment_method_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date_replaced",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "log_replaced_payment_fulfilled_changes",
  "XTracker::Schema::Result::Orders::LogReplacedPaymentFulfilledChange",
  { "foreign.replaced_payment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_replaced_payment_preauth_cancellations",
  "XTracker::Schema::Result::Orders::LogReplacedPaymentPreauthCancellation",
  { "foreign.replaced_payment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_replaced_payment_valid_changes",
  "XTracker::Schema::Result::Orders::LogReplacedPaymentValidChange",
  { "foreign.replaced_payment_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "orders",
  "XTracker::Schema::Result::Public::Orders",
  { id => "orders_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "payment_method",
  "XTracker::Schema::Result::Orders::PaymentMethod",
  { id => "payment_method_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CZUfYWOrNOb8hCKXH7DbIA


=head1 METHODS

=head2 payment_method_name

    $string = $self->payment_method_name;

Returns the name of the Payment Method for the Replaced Payment.

=cut

sub payment_method_name {
    my $self = shift;
    return $self->payment_method->payment_method;
}

1;
