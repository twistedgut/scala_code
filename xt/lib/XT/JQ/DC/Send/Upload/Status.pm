package XT::JQ::DC::Send::Upload::Status;

use Moose;

use Moose::Util::TypeConstraints;
use MooseX::Types::Moose qw( Int ArrayRef Str );
use MooseX::Types::Structured qw( Dict Optional );

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker::FulcrumProxy';

has payload => (
    is => 'ro',
    isa => Dict[
        upload_id => Int,
        operator_id => Optional[Int],
        channel_id => Optional[Int],
        due_date => Optional[Str],
        environment => Optional[Str],
        status => enum([ 'Complete', 'Part Uploaded', 'Failed', 'Staging', 'WhatsNewStaging', 'WhatsNewLive' ]),
        completed_pids => Optional[ArrayRef[Int]]
    ],
    required => 1
);

has '+fulcrum_jobname' => (
    default => 'Receive::Upload::Status',
);


sub check_job_payload { () }

1;

=head1 NAME

XT::JQ::DC::Send::Upload::Status - Send to Fulcrum that an UpLoad has been run and what status it finished at

=head1 DESCRIPTION

Proxy job that sends an Upload::Status job to the Fulcrum
system. The job payload will be similar to below:

{
 upload_id => 345,
 status => 'Part Uploaded',
 competed_pids => [ 12345, 246810, 345678 ] - optional depending on value of 'status'
}
