package XT::JQ::DC::Send::Product::Transfered;

use Moose;

use MooseX::Types::Moose qw(Str Int);
use MooseX::Types::Structured qw(Dict Optional);

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker::FulcrumProxy';

has payload => (
    is => 'ro',
    isa => Dict[
        source_channel  => Int,
        dest_channel    => Int,
        transfer_date   => Str,
        product_id      => Int,
        quantity        => Int,
    ],
    required => 1
);


has '+fulcrum_jobname' => (
    default => 'Receive::Product::Transfered',
);


sub check_job_payload { () }

1;

=head1 NAME

XT::JQ::DC::Send::Product::Transfered

=head1 DESCRIPTION

Flags to Fulcrum when a PID has been transferred, giving the date and quantity of stock transferred.

{
    product_id          => 12345,
    source_channel      => 1,
    dest_channel        => 3,
    transfer_date       => '2009-01-01',
    quantity            => 10,
}



