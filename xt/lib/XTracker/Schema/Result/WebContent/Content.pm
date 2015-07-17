use utf8;
package XTracker::Schema::Result::WebContent::Content;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("web_content.content");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "web_content.content_id_seq",
  },
  "instance_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "field_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "content",
  { data_type => "text", is_nullable => 0 },
  "category_id",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "searchable_product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "page_snippet_id",
  { data_type => "integer", is_nullable => 1 },
  "page_list_id",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("instance_field", ["instance_id", "field_id"]);
__PACKAGE__->belongs_to(
  "field",
  "XTracker::Schema::Result::WebContent::Field",
  { id => "field_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "instance",
  "XTracker::Schema::Result::WebContent::Instance",
  { id => "instance_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "searchable_product",
  "XTracker::Schema::Result::Public::Product",
  { id => "searchable_product_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ze966f4txg6uxKFaDMqN/Q

use XTracker::DB::Factory::CMS;

# TODO: Migrate XTracker::DB::Factory::CMS::set_content into this sub and
# clean up!
sub set_content {
    my ( $self, $args ) = @_;

    my $field_content    = $args->{field_content};
    my $category_id      = $args->{category_id};
    my $field_id         = $args->{field_id};
    my $operator_id      = $args->{operator_id};
    my $live_handle      = $args->{live_handle};
    my $staging_handle   = $args->{staging_handle};

    my $factory = XTracker::DB::Factory::CMS->new(
        { schema => $self->result_source->schema }
    );
    $factory->set_content({
        content_id               => $self->id,
        content                  => $field_content,
        category_id              => $category_id,
        field_id                 => $field_id,
        transfer_dbh_ref         => $live_handle,
        staging_transfer_dbh_ref => $staging_handle,
    });
    $factory->set_instance_last_updated({
        instance_id              => $self->instance_id,
        operator_id              => $operator_id,
        transfer_dbh_ref         => $live_handle,
        staging_transfer_dbh_ref => $staging_handle,
    });
    return $self;
}

1;
