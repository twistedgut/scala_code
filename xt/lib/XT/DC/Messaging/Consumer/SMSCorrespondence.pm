package XT::DC::Messaging::Consumer::SMSCorrespondence;
use NAP::policy "tt", 'class';
extends 'XT::DC::Messaging::ConsumerBase::Correspondence';

sub routes {
    return {
        destination => XT::DC::Messaging::ConsumerBase::Correspondence->base_route,
    };
}

=head1 Consumer::Controller::SMSCorrespondence

=head2 SEE ALSO

L<XT::DC::Messaging::ConsumerBase::Correspondence> for all of the implementation

=cut
