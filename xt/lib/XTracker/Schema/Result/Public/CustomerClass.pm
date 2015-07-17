use utf8;
package XTracker::Schema::Result::Public::CustomerClass;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.customer_class");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "customer_class_id_seq",
  },
  "class",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "is_visible",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("customer_class_class_key", ["class"]);
__PACKAGE__->has_many(
  "customer_categories",
  "XTracker::Schema::Result::Public::CustomerCategory",
  { "foreign.customer_class_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:p3wU4qo0O5QuO6WpgjapiA

use XTracker::Constants::FromDB     qw( :customer_class );
use XTracker::Utilities             qw( number_in_list );

=head2 is_finance_high_priority

Returns TRUE if the Customer Class is regarded as a High Priority by Finance.

=cut

sub is_finance_high_priority {
    my $self    = shift;

    return number_in_list( $self->id,
                                $CUSTOMER_CLASS__EIP,
                                $CUSTOMER_CLASS__IP,
                                $CUSTOMER_CLASS__PR,
                                $CUSTOMER_CLASS__HOT_CONTACT,
                            );
}

1;
