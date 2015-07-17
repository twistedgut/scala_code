package XT::JQ::DC::Send::Product::Comment;

use Moose;

use MooseX::Types::Moose        qw( Str Int Maybe );
use MooseX::Types::Structured   qw( Dict );

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker::FulcrumProxy';

has payload => (
    is => 'ro',
    isa => Dict[
        product_id  => Int,
        username    => Str,
        comment     => Str,
        action      => Str
    ],
    required => 1
);

has '+fulcrum_jobname' => (
    default => 'Receive::Product::Comment',
);


sub check_job_payload { () };

1;

=head1 NAME

XT::JQ::DC::Send::Product::Comment - Add/Delete a Product Comment

=head1 DESCRIPTION

Proxy job that sends a Product::Comment job to the Fulcrum
system. The job payload will be similar to below:

{
    product_id  => 12345,
    username    => 'a.user',
    comment     => 'comments go here',
    action      => 'add' or 'delete'
}
