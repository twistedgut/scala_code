use utf8;
package XTracker::Schema::Result::Shipping::DeliveryDateRestrictionLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("shipping.delivery_date_restriction_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipping.delivery_date_restriction_log_id_seq",
  },
  "delivery_date_restriction_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "datetime",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "new_is_restricted",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "change_reason",
  { data_type => "text", is_nullable => 1 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "delivery_date_restriction",
  "XTracker::Schema::Result::Shipping::DeliveryDateRestriction",
  { id => "delivery_date_restriction_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qjIwxH3LcUwyR1mzDm8Ftw

# You can replace this text with custom code or comments, and it will be preserved on regeneration

use Memoize;
use XT::Data::DateStamp;

# These are memoized to avoid looking up the same static data all over
# again. This takes the time for 500 rows (which is an option in the
# UI) from 4.5s => 1.5s

sub as_data {
    my $self = shift;

    my $restriction_row = $self->delivery_date_restriction;

    my $schema = $restriction_row->result_source->schema;
    my $shipping_charge = _get_shipping_charge(
        $schema,
        $restriction_row->shipping_charge_id,
    );
    my $restriction_type_name = _get_restriction_type_name(
        $schema,
        $restriction_row->restriction_type_id,
    );
    my $operator_name = _get_operator_name($schema, $self->operator_id);

    return {
        id               => $self->id,
        change_time      => $self->datetime . "",
        operator         => $operator_name,
        change_reason    => $self->change_reason,
        restricted_date  => XT::Data::DateStamp->from_datetime(
            $restriction_row->date,
        ),
        shipping_charge  => $shipping_charge,
        restriction_type => $restriction_type_name,
        is_restricted    => $self->new_is_restricted ? "Yes" : "No",
    };
}

memoize("_get_shipping_charge");
sub _get_shipping_charge {
    my ($schema, $shipping_charge_id) = @_;

    my $shipping_charge_row = $schema->resultset("Public::ShippingCharge")->find(
        $shipping_charge_id,
    );
    my $channel_row = $shipping_charge_row->channel;

    my ($channel_name) = $channel_row->web_name =~ /^(\w{1,3})/;
    $channel_name ||= "N/A";

    my $shipping_charge =
        "$channel_name-"
        . $shipping_charge_row->description
        . "-"
        . $shipping_charge_row->sku;

    return $shipping_charge;
}

memoize("_get_operator_name");
sub _get_operator_name {
    my ($schema, $operator_id) = @_;
    return $schema->resultset("Public::Operator")->find($operator_id)->name;
}

memoize("_get_restriction_type_name");
sub _get_restriction_type_name {
    my ($schema, $restriction_type_id) = @_;
    return $schema->resultset("Shipping::DeliveryDateRestrictionType")->find(
        $restriction_type_id,
    )->name;
}

1;
