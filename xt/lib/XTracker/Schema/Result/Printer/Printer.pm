use utf8;
package XTracker::Schema::Result::Printer::Printer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("printer.printer");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "printer.printer_id_seq",
  },
  "lp_name",
  { data_type => "text", is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "location_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("printer_type_id_location_id_key", ["type_id", "location_id"]);
__PACKAGE__->belongs_to(
  "location",
  "XTracker::Schema::Result::Printer::Location",
  { id => "location_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::Printer::Type",
  { id => "type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Z0cbZfhQ6kZZk3XEAgICXQ

use XT::Data::Printer;
use XT::LP;

=head2 name() : $printer_name

Return a name for the printer

=cut

sub name {
    my $self = shift;
    return join q{ - },
        $self->location->name,
        ${XT::Data::Printer::type_name}{$self->type->name};
}

=head2 print_file($filename, $copies) :

Print the given file.

=cut

sub print_file {
    my ( $self, $filename, $copies ) = @_;
    return XT::LP->print({
        printer  => $self->lp_name,
        filename => $filename,
        copies   => $copies,
    });
}

1;
