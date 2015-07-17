package Test::XTracker::Data::AccessControls;

use NAP::policy qw( test class tt );

with    qw(
    Test::Role::AccessControls
);

=head1 NAME

Test::XTracker::Data::AccessControls

=head1 DESCRIPTION

Used to set-up data for Access Control related stuff.

Is actually a Class that is a wrapper around the Role 'Test::Role::AccessControls'.

You can get access to the same functionality via 'Test::XTracker::Model' which uses
the same Role or 'Test::XTracker::Data' which extends T:X:Model.

It's preferable if you use 'Test::XTracker::Data' to access the methods you want as
this Class is here to keep a lot of existing tests working that were relying on this
Class existing to work and it was too much work to fix all of them.

=cut

use XTracker::Database              qw( schema_handle );

=head1 METHODS

=head2 get_schema

    $dbic_schema = __PACKAGE__->get_schema;

Returns a DBIC Schema Handle. This method is
required by 'Test::Role::AccessControls'.

=cut

sub get_schema {
    return schema_handle();
}

