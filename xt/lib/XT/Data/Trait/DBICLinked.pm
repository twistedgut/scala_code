package XT::Data::Trait::DBICLinked;

use NAP::policy 'tt', 'role';
Moose::Util::meta_attribute_alias('DBICLinked');

=head1 NAME

XT::Data::Trait::DBICLinked

=head1 DESCRIPTION

Trait to indicate where a data object field is linked to the XT database via a
DBIC accessor. Provides a simple attribute field to hold the accessor
information.

=cut

has dbic_accessor => (
    is        => 'ro',
    isa       => 'ArrayRef',
    predicate => 'has_dbic_accessor',
);
