use utf8;
package XTracker::Schema::Result::Public::CancelledItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.cancelled_item");
__PACKAGE__->add_columns(
  "shipment_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "customer_issue_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("shipment_item_id");
__PACKAGE__->belongs_to(
  "customer_issue_type",
  "XTracker::Schema::Result::Public::CustomerIssueType",
  { id => "customer_issue_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment_item",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { id => "shipment_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3UI0gTJS3/9wShh7vmDJnA

use XTracker::Constants::FromDB qw/ :shipment_class :customer_issue_type/;
use DateTime;

sub notes {
    my($self) = @_;
    my $shipment = $self->shipment_item->shipment;

    ### EXCHANGE
    if ($shipment->shipment_class_id == $SHIPMENT_CLASS__EXCHANGE) {
        return "Cancelled Exchange on ". $shipment->id;
    } elsif($self->customer_issue_type_id
        == $CUSTOMER_ISSUE_TYPE__8__SIZE_CHANGE){
        return "Change size on ". $shipment->id;
    }

    #$code .= "Cancel off ".$$row{shipment_id};
    return "Cancel off ". $shipment->id;
}

1;
