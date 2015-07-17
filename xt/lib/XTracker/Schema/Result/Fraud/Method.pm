use utf8;
package XTracker::Schema::Result::Fraud::Method;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.method");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.method_id_seq",
  },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "object_to_use",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "method_to_call",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "method_parameters",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "return_value_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "rule_action_helper_method",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "processing_cost",
  { data_type => "smallint", default_value => 100, is_nullable => 0 },
  "list_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "archived_conditions",
  "XTracker::Schema::Result::Fraud::ArchivedCondition",
  { "foreign.method_id" => "self.id" },
  undef,
);
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
__PACKAGE__->has_many(
  "live_conditions",
  "XTracker::Schema::Result::Fraud::LiveCondition",
  { "foreign.method_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "return_value_type",
  "XTracker::Schema::Result::Fraud::ReturnValueType",
  { id => "return_value_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "staging_conditions",
  "XTracker::Schema::Result::Fraud::StagingCondition",
  { "foreign.method_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yLQ4PJxG+oZ9YIyYFi8Aiw


use XT::FraudRules::Actions::HelperMethod;

sub has_allowable_values {
    my $self = shift;
    if ( $self->rule_action_helper_method ) {
        return 1;
    }
    else {
        return 0;
    }
}

=head2 get_allowable_values_from_helper

    $array_ref  = $self->get_allowable_values_from_helper;

Returns an ArrayRef containing a list of the available values that can be chosen
for the Method.

    [
        {
            id      => Id of the Value
            value   => The Displayable Value
        },
        ...
    ]

=cut

sub get_allowable_values_from_helper {
    my $self    = shift;

    my @values;

    if ( $self->has_allowable_values ) {

        my $helper = XT::FraudRules::Actions::HelperMethod->new(
            schema => $self->result_source->schema,
        );

        if ( $helper->compile( $self->rule_action_helper_method ) ) {
            if ( my $rs = $helper->execute ) {;
                @values = $rs->all;
            }
        }

    }

    return \@values;

}

=head2 get_an_allowable_value_from_helper

    $a_value    = $self->get_an_allowable_value_from_helper( $id_of_value );

Given an Id of a Value will return the Value, returns 'undef' if it can't find it.

=cut

sub get_an_allowable_value_from_helper {
    my ( $self, $id_of_value )  = @_;

    return      if ( !defined $id_of_value );

    my $values  = $self->get_allowable_values_from_helper // [];

    my $retval;
    VALUE:
    foreach my $value ( @{ $values } ) {
        if ( $value->get_column('id') eq $id_of_value ) {
            $retval = $value->get_column('value');
            last VALUE;
        }
    }

    return $retval;
}

=head2 is_boolean

    $boolean    = $self->is_boolean;

Returns TRUE or FALSE depending on whether the Method's Return Value Type is 'boolean'.

=cut

sub is_boolean {
    my $self    = shift;

    return (
        $self->return_value_type->type eq 'boolean'
        ? 1
        : 0
    );
}


1;
