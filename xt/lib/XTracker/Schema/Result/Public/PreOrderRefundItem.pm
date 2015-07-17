use utf8;
package XTracker::Schema::Result::Public::PreOrderRefundItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.pre_order_refund_item");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "pre_order_refund_item_id_seq",
  },
  "pre_order_refund_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pre_order_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "unit_price",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "tax",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "duty",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "pre_order_item",
  "XTracker::Schema::Result::Public::PreOrderItem",
  { id => "pre_order_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "pre_order_refund",
  "XTracker::Schema::Result::Public::PreOrderRefund",
  { id => "pre_order_refund_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5tzAuQpnFG+AQGsBrc1p/g


# You can replace this text with custom code or comments, and it will be preserved on regeneration


=head2 sub_total_value

    my $number  = $self->sub_total_value;

Returns the Value of the Refund Item by Adding tax, duty, and unit_price.

=cut

sub sub_total_value {
    my $self =shift;

    my $sub_total =  ($self->unit_price + $self->tax + $self->duty );

    return $sub_total;
}

1;
