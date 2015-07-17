use utf8;
package XTracker::Schema::Result::Fraud::ListType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.list_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.list_type_id_seq",
  },
  "type",
  { data_type => "varchar", is_nullable => 1, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "archived_lists",
  "XTracker::Schema::Result::Fraud::ArchivedList",
  { "foreign.list_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "live_lists",
  "XTracker::Schema::Result::Fraud::LiveList",
  { "foreign.list_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "methods",
  "XTracker::Schema::Result::Fraud::Method",
  { "foreign.list_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "staging_lists",
  "XTracker::Schema::Result::Fraud::StagingList",
  { "foreign.list_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DTy7xYO0PagrrG2goBz8wQ

=head1 NAME

XTracker::Schema::Result::Fraud::ListType

=head1 DESCRIPTION

Result class for the fraud.list_type table.

=head1 METHODS

=head2 get_values_from_helper_methods

Returns the values provided by the helper methods for each list.

=cut

sub get_values_from_helper_methods {
    my $self = shift;

    my %result = ();

    foreach my $method ( $self->methods->all ) {

        foreach my $value_object ( @{ $method->get_allowable_values_from_helper } ) {

            my $id    = $value_object->get_column('id');
            my $value = $value_object->get_column('value');

            $result{ $id } = $value
                if defined $id && defined $value && $value ne '';

        }

    }

    return \%result;

}

1;
