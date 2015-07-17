use utf8;
package XTracker::Schema::Result::Public::ReservationConsistency;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.reservation_consistency");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "reservation_consistency_id_seq",
  },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "customer_number",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "web_quantity",
  { data_type => "integer", is_nullable => 0 },
  "xt_quantity",
  { data_type => "integer", is_nullable => 0 },
  "reported",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yPgaWNApeq54J/r6eD/Pkw

use Try::Tiny;

=head1 NAME

XTracker::Schema::Result::Public::ReservationConsistency

=head1 METHODS

=head2 adjust_discrepancy( [$stock_manager] )

Adjust and delete the stock discrepancy for this row. If you don't pass a
$stock_manager object one will be created. Be aware that this sub B<will> call
a commit (or rollback) in case of failure on the stock manager.

=cut

sub adjust_discrepancy {
    my ( $self, $stock_manager ) = @_;

    # Different behaviour when object passed/created re: rollback/commit?
    $stock_manager ||= $self->channel->stock_manager;

    my $variant = $self->variant;
    try {
        my $guard = $self->result_source->schema->txn_scope_guard;

        $stock_manager->update_reservation_quantity(
            $variant->sku, $self->customer_number, $self->delta
        );
        $variant->create_related('log_pws_reservation_corrections', {
            channel_id      => $self->channel_id,
            pws_customer_id => $self->customer_number,
            xt_quantity     => $self->xt_quantity,
            pws_quantity    => $self->web_quantity,
        });
        $self->delete;

        $stock_manager->commit;
        $guard->commit;
    }
    catch {
        $stock_manager->rollback;
        die "$_\n";
    };
    return;
}

=head2 delta

Returns B<xt_quantity> - B<web_quantity>.

=cut

sub delta { $_[0]->xt_quantity - $_[0]->web_quantity; }

1;
