use utf8;
package XTracker::Schema::Result::WebContent::Instance;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("web_content.instance");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "web_content.instance_id_seq",
  },
  "page_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "label",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "created_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "last_updated",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "last_updated_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "contents",
  "XTracker::Schema::Result::WebContent::Content",
  { "foreign.instance_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "operator_created",
  "XTracker::Schema::Result::Public::Operator",
  { id => "created_by" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator_updated",
  "XTracker::Schema::Result::Public::Operator",
  { id => "last_updated_by" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "page",
  "XTracker::Schema::Result::WebContent::Page",
  { id => "page_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "published_logs",
  "XTracker::Schema::Result::WebContent::PublishedLog",
  { "foreign.instance_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::WebContent::InstanceStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RONQ1z+YGuuXV0uS1y2kyQ

use XTracker::Constants::FromDB qw{ :page_instance_status };

=head2 is_published

Returns a true value if the instance is published.

=cut

sub is_published {
    return $_[0]->status_id == $WEB_CONTENT_INSTANCE_STATUS__PUBLISH;
}

=head2 is_draft

Returns a true value if the instance is a draft.

=cut

sub is_draft {
    return $_[0]->status_id == $WEB_CONTENT_INSTANCE_STATUS__DRAFT;
}

=head2 is_archived

Returns a true value if the instance is archived.

=cut

sub is_archived {
    return $_[0]->status_id == $WEB_CONTENT_INSTANCE_STATUS__ARCHIVED;
}

1;
