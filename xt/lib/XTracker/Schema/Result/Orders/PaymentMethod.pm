use utf8;
package XTracker::Schema::Result::Orders::PaymentMethod;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("orders.payment_method");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "orders.payment_method_id_seq",
  },
  "payment_method",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "payment_method_class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "string_from_psp",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "notify_psp_of_address_change",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "billing_and_shipping_address_always_the_same",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "notify_psp_of_basket_change",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "allow_full_refund_using_only_store_credit",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "allow_full_refund_using_only_payment",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "produce_customer_invoice_at_fulfilment",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "display_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "allow_editing_of_shipping_address_after_settlement",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "allow_goodwill_refund_using_payment",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "cancel_payment_after_force_address_update",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("payment_method_payment_method_key", ["payment_method"]);
__PACKAGE__->add_unique_constraint("payment_method_string_from_psp_key", ["string_from_psp"]);
__PACKAGE__->belongs_to(
  "payment_method_class",
  "XTracker::Schema::Result::Orders::PaymentMethodClass",
  { id => "payment_method_class_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "payments",
  "XTracker::Schema::Result::Orders::Payment",
  { "foreign.payment_method_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "replaced_payments",
  "XTracker::Schema::Result::Orders::ReplacedPayment",
  { "foreign.payment_method_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "third_party_payment_method_status_maps",
  "XTracker::Schema::Result::Orders::ThirdPartyPaymentMethodStatusMap",
  { "foreign.payment_method_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HHJ/IyQ89GtvYXwkZ5Al2w


use Carp;

use XTracker::Constants::FromDB     qw( :orders_payment_method_class );

use Moose;
with 'XTracker::Schema::Role::WithStatus' => {
    column => 'payment_method_class_id',
    statuses => {
        card        => $ORDERS_PAYMENT_METHOD_CLASS__CARD,
        third_party => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
    }
};


=head1 METHODS

=head2 get_internal_third_party_status_for

    $record_obj = $self->get_internal_third_party_status_for( 'THIRD_PARTY_STATUS' );

Given a Third Party Status it will return its Internal Status by using the
'third_party_payment_method_status_map'. Will return 'undef' if the Payment
Method does not have a Third Party PSP class.

=cut

sub get_internal_third_party_status_for {
    my ( $self, $status ) = @_;

    return      if ( !$self->is_third_party );

    croak "No Third Party Status was passed to '" . __PACKAGE__ . "->get_internal_third_party_status_for'"
                if ( !$status );

    my $rec = $self->search_related( 'third_party_payment_method_status_maps', {
        'UPPER(third_party_status)' => uc( $status ),
    } )->first;

    return      if ( !$rec );
    return $rec->internal_status;
}


1;
