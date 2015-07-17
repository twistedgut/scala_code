package XT::DC::Messaging::Consumer::NAPReturns;
use NAP::policy "tt", 'class';
extends 'XT::DC::Messaging::ConsumerBase::Returns';

sub routes {
    return {
        destination => XT::DC::Messaging::ConsumerBase::Returns->base_route,
    };
}

=head1 SEE ALSO

L<XT::DC::Messaging::ConsumerBase::Returns> for all of the implementation

=cut

1;
