package XT::DC::Messaging::Spec::DutyRate;
use NAP::policy "tt";
use NAP::Messaging::Validator;

NAP::Messaging::Validator->add_type_plugins(
    map {"XT::DC::Messaging::Spec::Types::$_"}
        qw(country)
    );

sub duty_rate {
    return {
        type => '//rec',
        required => {
            hs_code => '//str',
            country_code => '/nap/country',
            duty_rate => '//num',
            channel_ids => {
                type => '//arr',
                contents => '//int',
                length => { min => 1 },
            },
        }
    };
}
