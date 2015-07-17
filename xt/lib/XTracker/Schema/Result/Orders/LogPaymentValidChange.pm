use utf8;
package XTracker::Schema::Result::Orders::LogPaymentValidChange;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("orders.log_payment_valid_change");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "orders.log_payment_valid_change_id_seq",
  },
  "payment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date_changed",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "new_state",
  { data_type => "boolean", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "payment",
  "XTracker::Schema::Result::Orders::Payment",
  { id => "payment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mt7/rTyz2QLZa4PLhw/cog


=head1 METHODS

=head2 copy_to_replaced_payment_log

    my $replaced_log_obj = $self->copy_to_replaced_payment_log( $replaced_payment_obj );

Will copy the record to the Replaced Payment version of the Log record
which is 'orders.log_replaced_payment_valid_change'.

=cut

sub copy_to_replaced_payment_log {
    my ( $self, $replaced_payment ) = @_;

    my $replaced_log = $replaced_payment->create_related( 'log_replaced_payment_valid_changes', {
        map { $_ => $self->$_ }
            qw(
                date_changed
                new_state
            )
    } );

    return $replaced_log->discard_changes;
}

1;
