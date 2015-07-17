package XT::Data::Role::StorageInteraction; ## no critic(ProhibitExcessMainComplexity)
# We can't use NAP::policy as it doesn't play nice with parameterized roles
# use NAP::policy 'role', 'tt';

use strict;
use warnings;
use true;
use Try::Tiny;

use MooseX::Role::Parameterized;
use Storable qw/dclone/;

=head1 NAME

XT::Data::Role::StorageInteraction

=head1 DESCRIPTION

Methods for linking data object fields to DBIC accessors

=head1 SEE ALSO

XT::Data::Trait::DBICLinked

=head1 PARAMETERS

=head2 storage_class

The DBIC class name that this data object is linked to

=cut

parameter storage_class => (
   is => 'ro',
   isa => 'Str',
   required => 1,
);

=head2 search_key

The DBIC accessor name we will search against to find the correct DBIC result
object for this instance

=cut

parameter search_key => (
   is => 'ro',
   isa => 'Str',
   required => 1,
);

=head2 search_field

The data object field name containing the value we will search against to find
the correct DBIC result object for this instance

=cut

parameter search_field => (
   is => 'ro',
   isa => 'Str',
   required => 1,
);

role {
    my $p = shift;

=head2 schema

=cut

=head1 ATTRIBUTES

=cut

    has schema => (
        is          => 'ro',
        isa         => 'DBIx::Class::Schema|XTracker::Schema|XT::DC::Messaging::Model::Schema',
        required    => 1,
    );

    has storage_obj => (
        is       => 'ro',
        required => 1,
        lazy     => 1,
        default  => sub { $_[0]->get_storage_object },
    );

=head1 METHODS

=head2 compare_with_storage

Compare each field in the data object that has the trait DBICLinked with what
is stored in the XT database for the linked field. Return an arrayref of
fields that differ.

=cut

    method "compare_with_storage" => sub {
        my $self = shift;

        my @differences = ();

        if ( my $db_object = $self->storage_obj ) {

            #  loop through attributes
          ATTRIBUTE:
            foreach my $attribute ( $self->meta->get_all_attributes ) {

                if ( $attribute->does('XT::Data::Trait::DBICLinked')
                       && $attribute->has_dbic_accessor ) {

                    my $reader = $attribute->get_read_method;
                    my $db_value = undef;
                    my $do_value = $self->$reader;
                    my $db_methods = dclone $attribute->dbic_accessor;

                    my $ref = $db_object;
                    while ( my $method = pop @$db_methods ) {
                        if ( @$db_methods ) {
                            $ref = $ref->$method;
                        } else {
                            $db_value = $ref->$method;
                        }
                    }

                    unless ( defined $db_value || defined $do_value ) {
                        next ATTRIBUTE;
                    }

                    if (( defined $db_value xor defined $do_value )
                          || ( $db_value ne $do_value ) ) {
                        # they differ either in definedness or by value
                        push @differences, $reader;
                    }
                }
            }
        } else {
            # no db object
        }

        return \@differences;
    };

=head2 update_local_storage

For the arrayref of data object fields specified in the input argument
'fields' update the linked database field with the current value of the data
object field. The data object field must have the trait DBICLinked and have a
valid dbic_accessor attribute.

=cut

    method "update_local_storage" => sub {
        my $self = shift;
        my ($args) = @_;

        if ( my $db_object = $self->storage_obj ) {

            my $update_values = undef;

            # Create update structure
            foreach my $field (@{$args->{fields}}) {
                my $attribute = $self->meta->get_attribute($field);
                if ( $attribute->does('XT::Data::Trait::DBICLinked')
                       && $attribute->has_dbic_accessor ) {

                    my $accessor = $attribute->dbic_accessor;

                    if (@{$accessor} == 1) {
                        # Local field - simple value mapping
                        $update_values->{$field} = $self->$field;
                    } else {
                        # Related field - use the find the related object first
                        # and use it in the update

                        # The accessor method for the related field
                        my ($method, $foreign_method) = @{$accessor};

                        # The DBIC class for the foreign obj
                        my $foreign_class
                          = $db_object->result_source->relationship_info($method)->{class};

                        my ($foreign_obj)
                          = $self->schema->resultset($foreign_class)
                                         ->search({ $foreign_method => $self->$field })
                                         ->slice(0);

                        if ( defined $foreign_obj ) {
                            $db_object->update_from_related($field, $foreign_obj);
                        } else {
                            # warn('Update attempted to non-existent local value: ' . $field . ':' . $self->$field);
                        }
                    }
                }
            }

            # Only execute an update if we have values to use
            if( defined $update_values ){
                $db_object->update($update_values);
            }
            else {
                # No update to be made
            }
        } else {
            # No object
        }
    };

=head2 get_storage_object

Access the DBIC object related to this data object. The search key and value
are the DBIC accessor defined by the role parameter 'search_key' and the value
of the data object field defined by the role parameter 'search_field'

=cut

    method "get_storage_object" => sub {
        my $self = shift;

        my $search_field = $p->search_field;
        # Single record? More than one? None?
        my ($db_object)
          = $self->schema->resultset($p->storage_class)
                 ->search({ $p->search_key => $self->$search_field })
                 ->slice(0);

        return defined $db_object ? $db_object : ();
    };
}
