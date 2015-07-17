package XT::DC::Messaging::Spec::Returns;

use Moose;

sub return_request {
    return {
        type    => '//any',
    };
}

sub cancel_return_items {
    return {
        type    => '//any',
    };
}


1;
