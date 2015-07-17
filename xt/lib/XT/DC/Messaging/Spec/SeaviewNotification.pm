package XT::DC::Messaging::Spec::SeaviewNotification;

use Moose;

sub seaview_notification {
    return {
        type        => '//rec',
        required    => {
            verb => '//str',
            published => '/nap/datetime',
            object => {
                type => '//rec',
                required => {
                    id => '//str',
                },
            },
            actor => {
                type => '//rec',
                required => {
                    client => '//str',
                    userName => '//str',
                },
            },
        },
    };
}

1;

