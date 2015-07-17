use utf8;
package XTracker::Schema::Result::Public::Department;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.department");
__PACKAGE__->add_columns(
  "id",
  { data_type => "smallint", is_nullable => 0 },
  "department",
  { data_type => "varchar", is_nullable => 0, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("uniqddepartment", ["department"]);
__PACKAGE__->has_many(
  "correspondence_templates",
  "XTracker::Schema::Result::Public::CorrespondenceTemplate",
  { "foreign.department_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "operators",
  "XTracker::Schema::Result::Public::Operator",
  { "foreign.department_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "renumeration_reasons",
  "XTracker::Schema::Result::Public::RenumerationReason",
  { "foreign.department_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:OC8qx9AGppnN7ER7bV94bw

# code does ->find(..., { key => "department" }), but that can't be
# the actual constraint name, since that is also used for the index
# name, which clashes with the table name (indexes and tables are both
# relations, so share a namespace)
__PACKAGE__->add_unique_constraint("department", ["department"]);

use XTracker::Database::Department      qw( is_department_in_customer_care_group );


=head2 is_in_customer_care_group

    $boolean    = $department->is_in_customer_care_group

Checks to see whether the Department Id is part of the Customer Care Group of Departments it uses the function from 'XTracker::Database::Department' called 'is_department_in_customer_care_group' to get the value, passing through any additional parameters as well should they be needed in the future.

=cut

sub is_in_customer_care_group {
    my $self    = shift;

    return is_department_in_customer_care_group( $self->id, @_ );
}

1;
