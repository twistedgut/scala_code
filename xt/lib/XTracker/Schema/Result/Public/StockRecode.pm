use utf8;
package XTracker::Schema::Result::Public::StockRecode;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.stock_recode");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "stock_recode_id_seq",
  },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "quantity",
  { data_type => "integer", is_nullable => 0 },
  "complete",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "container",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "notes",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "putaway_prep_groups",
  "XTracker::Schema::Result::Public::PutawayPrepGroup",
  { "foreign.recode_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:twLE6TBhcX776tG+xfFi5g

# Make sure "container" is transformed into instance of
# NAP::DC::Barcode::Container on the way from database
# and stringified on the way back to DB
#
use NAP::DC::Barcode::Container;
__PACKAGE__->inflate_column('container', {
    inflate => sub { NAP::DC::Barcode::Container->new_from_id(shift) },
    deflate => sub { shift->as_id },
});

=head2 get_client

Return the associated client

=cut
sub get_client {
    my ($self) = @_;
    return $self->variant()->get_client();
}

1;
