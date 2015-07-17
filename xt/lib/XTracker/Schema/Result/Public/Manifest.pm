use utf8;
package XTracker::Schema::Result::Public::Manifest;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.manifest");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "manifest_id_seq",
  },
  "filename",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "cut_off",
  { data_type => "timestamp", is_nullable => 0 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "carrier_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "carrier",
  "XTracker::Schema::Result::Public::Carrier",
  { id => "carrier_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "link_manifest__channels",
  "XTracker::Schema::Result::Public::LinkManifestChannel",
  { "foreign.manifest_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_manifest__shipments",
  "XTracker::Schema::Result::Public::LinkManifestShipment",
  { "foreign.manifest_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "manifest_status_logs",
  "XTracker::Schema::Result::Public::ManifestStatusLog",
  { "foreign.manifest_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::ManifestStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GqIofR9IyeRaClPuA/LwVw

use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

=head2 update_status

Update the status of this manifest, and log the change

=cut
sub update_status {
    my ($self, $new_status) = @_;

    $self->result_source->schema->txn_do(sub {
        $self->update({ status_id => $new_status });
        $self->log_status($new_status);
    });
}

=head2 log_status

Log a status change for this manifest

param - $status_to_log : The status change that will be logged

=cut
sub log_status {
    my ($self, $status_to_log) = @_;
    $self->manifest_status_logs->create({
        status_id   => $status_to_log,
        operator_id => $self->result_source->schema->operator_id() // $APPLICATION_OPERATOR_ID,
        date        => \'current_timestamp'
    });
}
1;
