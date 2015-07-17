package XT::DC::Messaging::Spec::DCQuery::FraudQuery;

use Moose;

sub dc_fraud_query {
    return {
        type        => '//rec',
        required    => {
            query_id    => '//str',
            account_urn => '//str',
            query       => '//str',
        },
    };
}

1;
