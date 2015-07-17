use utf8;
package XTracker::Schema::Result::Shipping::DeliveryDateRestriction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("shipping.delivery_date_restriction");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipping.delivery_date_restriction_id_seq",
  },
  "date",
  { data_type => "date", is_nullable => 0 },
  "shipping_charge_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_restricted",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "restriction_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "shipping_delivery_date_restriction_date_shipping_charge_unique",
  ["date", "shipping_charge_id", "restriction_type_id"],
);
__PACKAGE__->has_many(
  "delivery_date_restriction_logs",
  "XTracker::Schema::Result::Shipping::DeliveryDateRestrictionLog",
  { "foreign.delivery_date_restriction_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "restriction_type",
  "XTracker::Schema::Result::Shipping::DeliveryDateRestrictionType",
  { id => "restriction_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipping_charge",
  "XTracker::Schema::Result::Public::ShippingCharge",
  { id => "shipping_charge_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5p/gqWaPPEsaadVb44W2Hg

use Memoize;

=head composite_shipping_charge_ids(@$shipping_charge_ids?) : @$composite_shipping_charge_ids

Take the $shipping_charge_ids and return an array ref with the
composite Shipping Charge ids, grouped by their description.

Default $shipping_charge_ids is the column "shipping_charge_ids" (if
used, this column must have been queried for, e.g. using
restricted_shipping_charge_ids_grouped_by_type_date)

(when/if it becomes necessary to group by some other attribute,
consider adding a shipping_restriction_group_id or similar to the
shipping_charge table)

=cut

sub composite_shipping_charge_ids {
    my ($self, $shipping_charge_ids) = @_;
    $shipping_charge_ids
        //= [ split(/-/, $self->get_column("shipping_charge_ids")) ]
        // die("Programmer error: missing column 'shipping_charge_ids'");

    return _composite_shipping_charge_ids(
        $self->result_source->schema,
        sort @$shipping_charge_ids,
    );
}

memoize("_composite_shipping_charge_ids");
sub _composite_shipping_charge_ids {
    my ($schema, @sorted_shipping_charge_ids) = @_;
    my $shipping_charge_rs = $schema->resultset("Public::ShippingCharge");

    my @composite_ids =
        map { $_->get_column("composite_id") }
        $shipping_charge_rs->search(
            {
                id => { -in => \@sorted_shipping_charge_ids },
            },
            {
                select => [
                    "me.description",
                    \"array_to_string( array_agg(me.id order by me.id), '-' )",
                ],
                as => [
                    "description",
                    "composite_id",
                ],
                group_by => "me.description",
                order_by => "me.description",
            },
        )->all;

    return \@composite_ids;
}

1;
