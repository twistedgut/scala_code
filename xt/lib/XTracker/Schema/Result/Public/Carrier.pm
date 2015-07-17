use utf8;
package XTracker::Schema::Result::Public::Carrier;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "InflateColumn::Time");
__PACKAGE__->table("public.carrier");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "carrier_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "tracking_uri",
  { data_type => "text", is_nullable => 1 },
  "last_pickup_daytime",
  { data_type => "time", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "carrier_box_weights",
  "XTracker::Schema::Result::Public::CarrierBoxWeight",
  { "foreign.carrier_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "manifests",
  "XTracker::Schema::Result::Public::Manifest",
  { "foreign.carrier_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "returns_charges",
  "XTracker::Schema::Result::Public::ReturnsCharge",
  { "foreign.carrier_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipping_accounts",
  "XTracker::Schema::Result::Public::ShippingAccount",
  { "foreign.carrier_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9AjwwtXch9lK3fkze7UxnQ

# Audit the last_pickup_daytime column
__PACKAGE__->load_components('AuditLog');
__PACKAGE__->add_audit_recents_rel;
__PACKAGE__->audit_columns(qw/ last_pickup_daytime /);
use DateTime::Format::Duration;
use Carp;

use XTracker::Constants::FromDB qw(
    :carrier
    :manifest_status
);

=head2 get_locking_manifest_rs

Return resultset of manifests that are locking this carrier for a list of possible channels

=cut

sub get_locking_manifest_rs {
  my ($self, $channel_ids) = @_;
  return $self->manifests->search_locking_status->search_by_channel_ids($channel_ids);
}

=head2 get_audit_value_for_last_pickup_daytime

Return a stringified duration based on last_pickup_time for audit purposes

=cut

sub get_audit_value_for_last_pickup_daytime {
    my ($self) = @_;
    my $formatter = DateTime::Format::Duration->new(
        pattern     => '%H:%M',
        normalize   => 1,
    );

    return $formatter->format_duration($self->last_pickup_daytime);
}

1;
