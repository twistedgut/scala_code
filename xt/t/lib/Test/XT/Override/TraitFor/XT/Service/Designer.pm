package Test::XT::Override::TraitFor::XT::Service::Designer;
use NAP::policy "tt", 'role';

use Test::RoleHelper;

use Data::Dump  qw( pp );

=head1 NAME

Test::XT::Override::TraitFor::XT::Service::Designer - A role with overrides to be
applied to XT::Service::Designer

=head1 DESCRIPTION

This module is a Moose role with overrides for XT::Service::Designer. You can use
L<Test::XT::Override> to apply these, or just apply them manually yourself.

=head1 METHOD MODIFIERS

=head2 around search

This method overrides the call to XT::Service::Designer->search. This will
always return an Empty Array Ref.

=cut

around 'search' => sub {
    my $orig = shift;
    my $self = shift;
    my @params = @_;

    # DEV's will use 'development' & Jenkins runs as 'unittest'
    return $self->$orig( @params )      unless ( $ENV{PLACK_ENV} =~ m/(development|unittest)/i );

    $self->log->info( "In Overridden 'search' method from '" . __PACKAGE__ . "', args: " . pp( \@params ) );

    # return an Empty Array Ref.
    return [ ];
};
