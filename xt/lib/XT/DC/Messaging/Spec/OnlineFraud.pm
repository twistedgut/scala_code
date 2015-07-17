package XT::DC::Messaging::Spec::OnlineFraud;
use Moose;
use NAP::Messaging::Validator;

NAP::Messaging::Validator->add_type_plugins(
    'XT::DC::Messaging::Spec::Types::channel_config_section',
    'XT::DC::Messaging::Spec::Types::dc_name',
);

sub update_fraud_hotlist {
    return {
        type => '//rec',
        required => {
            from_dc => '/nap/dc_name',
            records => {
                type    => '//arr',
                contents=> {
                    type    => '//rec',
                    required=> {
                        action                  => '//str',
                        hotlist_field_name      => '//str',
                        channel_config_section  => '/nap/channel_config_section',
                        value                   => '//str',
                    },
                    optional=> {
                        order_number            => '//str',
                    },
                },
            },
        },
    };
}

1;
