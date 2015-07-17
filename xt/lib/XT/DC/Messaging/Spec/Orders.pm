package XT::DC::Messaging::Spec::Orders;
use NAP::policy 'tt';

=head1 NAME

XT::DC::Messaging::Spec::Orders;

=head1 DESCRIPTION

Queue spec responses for the 'Consumer::Orders' class.

=cut

use NAP::Messaging::Validator;


NAP::Messaging::Validator->add_type_plugins(
    map {"XT::DC::Messaging::Spec::Types::$_"}
            qw( channel )
);


=head1 METHODS

=head2 PaymentStatusUpdate

Spec for the 'PaymentStatusUpdate' message.

=cut

sub PaymentStatusUpdate {
    return {
        type        => '//rec',
        required    => {
            order_number => '//str',
            channel      => '/nap/channel',
            preauth_ref  => '//str',
            timestamp    => '//str',
        }
    };
}
