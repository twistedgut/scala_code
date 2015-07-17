use utf8;
package XTracker::Schema::Result::Public::StockConsistency;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.stock_consistency");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "stock_consistency_id_seq",
  },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "web_quantity",
  { data_type => "integer", is_nullable => 0 },
  "xt_quantity",
  { data_type => "integer", is_nullable => 0 },
  "reported",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "stock_consistency_variant_id_key",
  ["variant_id", "channel_id"],
);
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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:VLEkx/JI7X1qhDSGzBnaOA

use Try::Tiny;
use XTracker::Constants qw{ :application };
use XTracker::Constants::FromDB qw{ :pws_action };

=head1 NAME

XTracker::Schema::Result::Public::StockConsistency

=head1 METHODS

=head2 adjust_discrepancy( [{stock_manager = $stock_manager, notes => $notes}] )

Adjust the website's stock level to match XT for this discrepancy, which is
then deleted. If you don't pass a $stock_manager object one will be created. Be
aware that this sub B<will> call a commit (or rollback) in case of failure on
the stock manager, so any ongoing transactions will end when calling this
method. You can also pass an optional value for I<notes>, which will be used to
populate the similarly named column of the I<log_pws_stock> table.

=cut

sub adjust_discrepancy {
    my ( $self, $args ) = @_;

    my $schema = $self->result_source->schema;

    # Different behaviour when object passed/created re: rollback/commit?
    my $stock_manager = $args->{stock_manager} || $self->channel->stock_manager;

    try {
        my $guard = $schema->txn_scope_guard;

        $stock_manager->stock_update(
            variant_id      => $self->variant_id,
            quantity_change => $self->delta,
            updated_by      => $args->{notes},
            pws_action_id   => $PWS_ACTION__AUTO_DASH_RESYNC_PWS_INVENTORY,
            notes           => $args->{notes},
        );
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
