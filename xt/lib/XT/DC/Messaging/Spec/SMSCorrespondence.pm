package XT::DC::Messaging::Spec::SMSCorrespondence;

use NAP::policy "tt", 'class';

=head1 NAME

XT::DC::Messaging::Spec::SMSCorrespondence

=head1 DESCRIPTION

Queue spec responses from the SMS Proxy

=cut

sub SMSResponse {
    return {
        type        => '//rec',
        required    => {
                id      => '//str',
                result  => '//str',
            },
        optional    => {
                reason  => '//str',
            },
    };
}

1;
