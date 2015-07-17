package XT::JQ::DC::Send::Product::Delivered;

use Moose;

use MooseX::Types::Moose qw(Str Int Num Undef ArrayRef);
use MooseX::Types::Structured qw(Dict Optional);

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker::FulcrumProxy';

has payload => (
    is => 'ro',
    isa => ArrayRef[
            Dict[
                product_id      => Int,
                channel_id      => Int,
            ]
    ],
    required => 1
);

has '+fulcrum_jobname' => (
    default => 'Receive::Product::Delivered',
);


sub check_job_payload { () }

1;

=head1 NAME

XT::JQ::DC::Send::Product::Delivered - Product delivery

=head1 DESCRIPTION

Proxy job that sends a (XT::JQ::Central::Receive)Product::Delivered job to the Fulcrum
system. The job payload will be similar to below:

[
    {
        product_id      => 12345,
        channel_id      => 1,
    }
]



