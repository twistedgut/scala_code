package XTracker::Database::Container;
use strict;
use warnings;

use Perl6::Export::Attrs;
use Readonly;
use XTracker::Constants::FromDB ':storage_type';
use XTracker::Database;
use XTracker::Config::Local;
use Carp 'confess';
use List::Util qw/first/;
use List::MoreUtils qw/uniq/;
use MooseX::Params::Validate qw/pos_validated_list/;

use NAP::DC::Barcode::Container;

=head2 get_compatible_storage_types_for

B<Description>

Get ARRAY ref of storage types that are compatible with passed Container ID.

Mapping of container type and storage types are defined in config
in "PRL > Goods_In_Container_Types" section.

=cut

sub get_compatible_storage_types_for :Export(:utils) {
    my ($container_id) = pos_validated_list(\@_,
        { isa => 'NAP::DC::Barcode::Container' },
    );

    # get mapping of "storage types => container types" from configuration file
    my $storage_type_mapping = config_var('PRL', 'Goods_In_Container_Types');

    my @result;

    foreach my $storage_type (keys %$storage_type_mapping) {
        next if $storage_type_mapping->{$storage_type} ne $container_id->type;

        push @result, $storage_type;
    }

    return [sort @result];
}

=head2 is_compatible

Requires container_id and storage_type_id parameters.

Returns 1 if the container is of the type that's required for that storage type.

Returns 0 if not.

=cut

sub is_compatible :Export(:validation) {
    my ($args) = @_;
    confess "expected parameter container_id"    unless $args->{container_id};
    confess "expected parameter storage_type_id" unless $args->{storage_type_id};
    confess "expected parameter schema"          unless $args->{schema};

    my $expected_container_type = compatible_type_for_goods_in($args);

    return 1 if $args->{container_id}->type eq $expected_container_type;

    return 0;
}

=head2 compatible_type_for_goods_in

Requires storage_type_id parameter.

Returns the type of container needed at goods in for this storage type
(a valid type string as supplied in xtracker config file).

For now, we have decreed that each storage type can only go in one type of
container at goods in.

This (and the config section) have been named to make it clear that it's
the containers used at goods in that we're talking about here. It's possible
that we may want similar methods for other warehouse processes which will
have slightly different requirements (e.g. for moving between packing and PE,
hanging items can probably go in totes, but for goods in they're on rails, in
DC2 at least...)

=cut

sub compatible_type_for_goods_in :Export(:utils) {
    my ($args) = @_;
    confess "expected parameter storage_type_id" unless $args->{storage_type_id};
    confess "expected parameter schema"          unless $args->{schema};

    my $storage_type_mapping = config_var('PRL', 'Goods_In_Container_Types');

    confess "no storage_type -> container_type mapping defined in config"
        unless defined($storage_type_mapping) and ref $storage_type_mapping eq 'HASH';

    my $storage_type = $args->{schema}->resultset('Product::StorageType')
        ->find($args->{storage_type_id});

    confess "couldn't find storage type for id ".$args->{storage_type_id} unless $storage_type;

    return $storage_type_mapping->{$storage_type->name};
}

Readonly my $commissioner_name => 'Commissioner';

# mainly to avoid spelling erors
sub get_commissioner_name :Export(:naming) { return $commissioner_name; }

sub is_valid_place :Export(:validation) {
    my $place = shift;

    return 1 unless $place; # undef/empty is allowed

    return $place eq $commissioner_name;
}

=head2 name_of_container_type

Takes a container type and returns the name we want to use for it in messages
to users.

If container type is not recognized - string "unknown"

=cut

sub name_of_container_type :Export(:naming) {
    my ($container_type) = @_;

    my $container_class_name
        = NAP::DC::Barcode::Container->class_from_type($container_type)
            or return "Unknown";

    return $container_class_name->name;
}

=head2 get_container_by_id($schema, $container_barcode) : container_row

For passed DBIC C<$schema> and L<NAP::DC::Barcode::Container> C<$id>
finds or creates record in database and returns DBIC object of
L<Public::Container>

=cut

sub get_container_by_id :Export(:utils) {
    my ($schema, $id) = pos_validated_list(\@_,
        { isa => 'XTracker::Schema' },
        { isa => 'NAP::DC::Barcode::Container' },
    );

    # discard changes is required in order to force the model to pick
    # up the default status that's allocated by Postgres for
    # non-existent containers
    return $schema->resultset( 'Public::Container' )
        ->find_or_create( { id => $id } )
        ->discard_changes;
}

1;
