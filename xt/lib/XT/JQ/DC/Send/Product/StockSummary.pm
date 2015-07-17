package XT::JQ::DC::Send::Product::StockSummary;

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
                ordered         => Int,
                delivered       => Int,
                main_stock      => Int,
                sample_stock    => Int,
                sample_request  => Int,
                reserved        => Int,
                pre_pick        => Int,
                cancel_pending  => Int,
                last_updated    => Str,
                arrival_date    => Str|Undef,
            ]
    ],
    required => 1
);

has '+fulcrum_jobname' => (
    default => 'Receive::Product::StockSummary',
);


sub check_job_payload { () }

1;

=head1 NAME

XT::JQ::DC::Send::Product::StockSummary - Product stock summary data

=head1 DESCRIPTION

Proxy job that sends a (XT::JQ::Central::)Product::StockSummary job to the Fulcrum
system. The job payload will be similar to below:

[
    {
        product_id      => 12345,
        channel_id      => 1,
        ordered         => 20,
        delivered       => 0,
        main_stock      => 0,
        sample_stock    => 1,
        sample_request  => 1,
        reserved        => 12,
        pre_pick        => 0,
        cancel_pending  => 3,
        last_updated    => '2009-01-01 23:01',
        arrival_date    => '2008-12-01',
    }
]



