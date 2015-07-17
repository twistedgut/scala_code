package XTracker::Pims::API;
use NAP::policy qw/class/;

use Class::Load 'load_class';

=head1 NAME

XTracker::Pims::API

=head1 DESCRIPTION

Wrapper for NAP::Pims::API that pulls in XT config values

=cut

with 'XTracker::Role::AccessConfig';

has api => (
  is      => 'ro',
  isa     => 'NAP::Pims::API',
  default => sub {
    my ($self) = @_;
    my $service_class = $self->get_config_var('Pims', 'api_class');
    load_class($service_class);
    $service_class->new({ url => $self->get_config_var('Pims', 'url') });
  },
  handles => [qw/get_quantities/]
);