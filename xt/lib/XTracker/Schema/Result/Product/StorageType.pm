use utf8;
package XTracker::Schema::Result::Product::StorageType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("product.storage_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "product.storage_type_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("storage_type_name_key", ["name"]);
__PACKAGE__->has_many(
  "products",
  "XTracker::Schema::Result::Public::Product",
  { "foreign.storage_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AyusxW6ahGPSjJhslmxASA

use XT::Domain::PRLs;
use XTracker::Constants::FromDB qw/:flow_status/;

{
# yes, we mistyped this in the message spec, now we're stuck with it
my %map=(
    Oversized => 'Oversize',
);
sub iws_name {
    my ($self) = @_;

    my $ret=$self->name;
    if (exists $map{$ret}) {
        return $map{$ret}
    }
    return $ret;
}
}

=head2 main_stock_prl

Returns a PRL name appropriate for a storage type and Main stock status.

=cut

sub main_stock_prl {
    my $self = shift;

    my $main_stock_status_row = $self->result_source->schema->resultset('Flow::Status')
        ->find($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS);

    my $prl_config_part = XT::Domain::PRLs::get_prls_for_storage_type_and_stock_status({
        storage_type => $self->name,
        stock_status => $main_stock_status_row->name,
    });

    return (keys %$prl_config_part)[0];
}

1;
