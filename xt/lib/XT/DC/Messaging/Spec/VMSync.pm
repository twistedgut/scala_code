package XT::DC::Messaging::Spec::VMSync;
use strict;
use warnings;

sub vmsync {
    return {
        type     => '//rec',
        required => {
            'product_id' => '//int',
            'variant_id' => '//int',
            'measurements' => {
                type => '//arr',
                contents => {
                    type => '//rec',
                    required => {
                        'measurement_id' => '//int',
                        'measurement_name' => '//str',
                        'value' => '//str',
                        'visible' => '//bool',
                    },
                },
            },
        },
    };
}

1;
