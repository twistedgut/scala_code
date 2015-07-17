use utf8;
package XTracker::Schema::Result::WebContent::Page;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("web_content.page");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "web_content.page_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "template_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "page_key",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("page_page_key_key", ["page_key", "channel_id"]);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "designer_attributes",
  "XTracker::Schema::Result::Designer::Attribute",
  { "foreign.page_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "designer_channels",
  "XTracker::Schema::Result::Public::DesignerChannel",
  { "foreign.page_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "instances",
  "XTracker::Schema::Result::WebContent::Instance",
  { "foreign.page_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "product_attributes",
  "XTracker::Schema::Result::Product::Attribute",
  { "foreign.page_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "template",
  "XTracker::Schema::Result::WebContent::Template",
  { id => "template_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::WebContent::Type",
  { id => "type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:I/0z/D8LOFvOMVK8vn6lCQ

use XTracker::DBEncode qw(decode_db encode_db);

__PACKAGE__->load_components('FilterColumn');
__PACKAGE__->filter_column($_ => {
    filter_from_storage => sub { decode_db($_[1]) },
    filter_to_storage => sub { encode_db($_[1]) },
}) for (qw(
    name
));


# NOTE: This *is* the correct relation here, even though we have a few cases
# where this can cause DBIC to complain, namely for designers called '0' and
# 'None' - these are presumably designers used as placeholders set up by
# different people... or something - DJ
__PACKAGE__->might_have(
    'designer_channel' => 'Public::DesignerChannel',
    { 'foreign.page_id'    => 'self.id',
      'foreign.channel_id' => 'self.channel_id', }
);

use XTracker::Constants::FromDB qw{ :page_instance_status };

=head2 published_instance

Returns the current live instance of this page. Returns a row as there should
only ever be one at a time.

=cut

sub published_instance {
    return $_[0]->_get_instances_by_status($WEB_CONTENT_INSTANCE_STATUS__PUBLISH)
                ->slice(0,0)
                ->single;
}

=head2 archived_instances

Returns the archived instances of this page.

=cut

sub archived_instances {
    return $_[0]->_get_instances_by_status($WEB_CONTENT_INSTANCE_STATUS__ARCHIVED);
}

=head2 archived_instances

Returns the draft instances of this page.

=cut

sub draft_instances {
    return $_[0]->_get_instances_by_status($WEB_CONTENT_INSTANCE_STATUS__DRAFT);
}

sub _get_instances_by_status {
    my ( $self, $status_id ) = @_;
    return $self->search_related('instances', { status_id => $status_id } );
}

=head2 is_live

Returns a true value if the page is currently live.

=cut

sub is_live {
    return 1 && $_[0]->published_instance;
}

1;
