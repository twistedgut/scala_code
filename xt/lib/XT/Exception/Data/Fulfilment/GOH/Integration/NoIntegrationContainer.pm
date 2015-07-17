package XT::Exception::Data::Fulfilment::GOH::Integration::NoIntegrationContainer;
use NAP::policy 'exception';

=head1 NAME

XT::Exception::Data::Fulfilment::GOH::Integration::NoIntegrationContainer

=head1 DESCRIPTION

Thrown at GOH Integration point if user tries to mark container as complete but the process does not have integration container record.

=head1 ATTRIBUTES

=cut

has '+message' => (
    default => q/There is no information about Integration container/,
);
