use utf8;
package XTracker::Schema::Result::Orders::LogPaymentFulfilledChange;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("orders.log_payment_fulfilled_change");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "orders.log_payment_fulfilled_change_id_seq",
  },
  "payment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "new_state",
  { data_type => "boolean", is_nullable => 0 },
  "date_changed",
  {
    data_type     => "timestamp with time zone",
    default_value => \"('now'::text)::timestamp(6) with time zone",
    is_nullable   => 0,
  },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "reason_for_change",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "payment",
  "XTracker::Schema::Result::Orders::Payment",
  { id => "payment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DhhOykxeogFlL8w2oQfTpg



=head1 METHODS

=head2 copy_to_replaced_payment_log

    my $replaced_log_obj = $self->copy_to_replaced_payment_log( $replaced_payment_obj );

Will copy the record to the Replaced Payment version of the Log record
which is 'orders.log_replaced_payment_fulfilled_change'.

=cut

sub copy_to_replaced_payment_log {
    my ( $self, $replaced_payment ) = @_;

    my $replaced_log = $replaced_payment->create_related( 'log_replaced_payment_fulfilled_changes', {
        map { $_ => $self->$_ }
            qw(
                new_state
                date_changed
                operator_id
                reason_for_change
            )
    } );

    return $replaced_log;
}


1;
