use utf8;
package XTracker::Schema::Result::Printer::Location;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("printer.location");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "printer.location_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "section_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("location_name_key", ["name"]);
__PACKAGE__->has_many(
  "printers",
  "XTracker::Schema::Result::Printer::Printer",
  { "foreign.location_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "section",
  "XTracker::Schema::Result::Printer::Section",
  { id => "section_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mKTRSc0t+2r8+/tYO3IsWg

=haed2 printer_for_type($printer_type) : $printer_row

Return a single printer row at this location for the given type.

=cut

sub printer_for_type {
    my ( $self, $type ) = @_;
    return $self->search_related('printers',
        { 'type.name' => $type },
        { join => 'type' },
    )->single;
}

1;
