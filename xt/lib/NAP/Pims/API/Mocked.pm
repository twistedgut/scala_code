package NAP::Pims::API::Mocked;
use NAP::policy qw/class/;
extends 'NAP::Pims::API';

=head1 NAME

XTracker::Pims::API::Mocked

=head1 DESCRIPTION

Mocked version of API to allow sane values without the need to contact an external system

=cut

with 'XTracker::Role::WithSchema';
with 'XTracker::Role::AccessConfig';

override 'get_quantities' => sub {
  my ($self) = @_;

  # Grab all the boxes from the db, and return them with a quantity (which is really their primary key!)
  [map {{
    code      => $_->pims_code,
    quantity  => $_->id
  }} (
    $self->schema->resultset('Public::Box')->all,
    $self->schema->resultset('Public::InnerBox')->all
  )];
};