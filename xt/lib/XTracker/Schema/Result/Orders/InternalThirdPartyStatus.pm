use utf8;
package XTracker::Schema::Result::Orders::InternalThirdPartyStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("orders.internal_third_party_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "orders.internal_third_party_status_id_seq",
  },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("internal_third_party_status_status_key", ["status"]);
__PACKAGE__->has_many(
  "third_party_payment_method_status_maps",
  "XTracker::Schema::Result::Orders::ThirdPartyPaymentMethodStatusMap",
  { "foreign.internal_status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:N35XfhhRKt3bOq/Dh365Qw


use XTracker::Constants::FromDB     qw( :orders_internal_third_party_status );

use Moose;
with 'XTracker::Schema::Role::WithStatus' => {
    column => 'id',
    statuses => {
        pending     => $ORDERS_INTERNAL_THIRD_PARTY_STATUS__PENDING,
        accepted    => $ORDERS_INTERNAL_THIRD_PARTY_STATUS__ACCEPTED,
        rejected    => $ORDERS_INTERNAL_THIRD_PARTY_STATUS__REJECTED,
    }
};

1;
