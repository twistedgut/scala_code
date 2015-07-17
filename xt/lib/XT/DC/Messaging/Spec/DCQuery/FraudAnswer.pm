package XT::DC::Messaging::Spec::DCQuery::FraudAnswer;

use Moose;

sub dc_fraud_answer {
    return {
        type        => '//rec',
        required    => {
            query_id    => '//str',
            answer      => '//bool',
        },
    };
}

1;
