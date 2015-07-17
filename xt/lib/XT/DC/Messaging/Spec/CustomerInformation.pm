package XT::DC::Messaging::Spec::CustomerInformation;
use NAP::policy "tt";
use NAP::Messaging::Validator;

=head1 NAME

XT::DC::Messaging::Spec::CustomerInformation;

=head1 DESCRIPTION

Queue spec responses for customer information

=cut

NAP::Messaging::Validator->add_type_plugins(
    map {"XT::DC::Messaging::Spec::Types::$_"}
        qw(language channel)
    );


sub CustomerInformation {
    return {
        type        => '//rec',
        required    => {
            cust_id    => '//int',
            channel    => '/nap/channel',
            timestamp  => '/nap/datetime',
            attributes => {
                type     => '//rec',
                optional => {
                    language => '/nap/language'
                }
            }
        }
    };
}
