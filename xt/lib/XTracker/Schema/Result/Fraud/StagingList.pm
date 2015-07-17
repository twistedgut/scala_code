use utf8;
package XTracker::Schema::Result::Fraud::StagingList;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.staging_list");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.staging_list_id_seq",
  },
  "list_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 50 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "live_list_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("staging_list_name_key", ["name"]);
__PACKAGE__->belongs_to(
  "list_type",
  "XTracker::Schema::Result::Fraud::ListType",
  { id => "list_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "live_list",
  "XTracker::Schema::Result::Fraud::LiveList",
  { id => "live_list_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "staging_list_items",
  "XTracker::Schema::Result::Fraud::StagingListItem",
  { "foreign.list_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hwg/CdGIjWQDSD5qY0Jqwg

__PACKAGE__->has_many(
  "list_items",
  "XTracker::Schema::Result::Fraud::StagingListItem",
  { "foreign.list_id" => "self.id" },
  {},
);

use Moose;
with 'XTracker::Schema::Role::Result::FraudList';

=head2 is_used

Returns true if the list is used in any of the staging conditions

=cut

sub is_used {
    my $self = shift;

    my $schema = $self->result_source->schema;

    my $count = $schema->resultset('Fraud::StagingCondition')->search_rs( {
        'me.value'                              => $self->id,
        'conditional_operator.is_list_operator' => 1,

    },
    {
        join    => [ 'conditional_operator' ],
    } );

    return $count > 0 ? 1 : 0;
}

1;
