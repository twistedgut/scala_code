package XT::JQ::DC::Send::Product::ShippingData;

use Moose;

use MooseX::Types::Moose qw(Str Int Num ArrayRef);
use MooseX::Types::Structured qw(Dict Optional);

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker::FulcrumProxy';

has payload => (
    is => 'ro',
    isa => Dict[
        product_id          => Int,
        operator_id         => Int,
        fabric_content      => Optional[Str],
        origin_country_id   => Optional[Int],
        weight              => Optional[Str],
        weight_unit         => Optional[Str],
        storage_type        => Optional[Str],
        from_dc             => Str,
    ],
    required => 1
);

has '+fulcrum_jobname' => (
    default => 'Receive::Product::Shipping',
);


sub check_job_payload { () }

1;

=head1 NAME

XT::JQ::DC::Send::Product::ShippingData - Product stock summary data

=head1 DESCRIPTION

Proxy job that sends a (XT::JQ::Central::)Product::Updated job to the Fulcrum
system with product related data entered by the DC during the Goods In process.
The job payload will be similar to below:

{
    product_id          => 12345,
    operator_id         => 202,
    fabric_content      => '100% Cotton',
    origin_country_id   => 25,
    weight              => '2.45',
    weight_unit         => 'kgs',
    from_dc             => 'DC1',
}



