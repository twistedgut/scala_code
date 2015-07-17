package XT::JQ::DC::Send::Upload::Completed;

use Moose;

use MooseX::Types::Moose qw( Int );
use MooseX::Types::Structured qw( Dict );

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker::FulcrumProxy';

has payload => (
    is => 'ro',
    isa => Dict[
        upload_id => Int
    ],
    required => 1
);

has '+fulcrum_jobname' => (
    default => 'Receive::Upload::Completed',
);


sub check_job_payload { () }

1;

=head1 NAME

XT::JQ::DC::Send::Upload::Completed - Send Confirmation that an Upload has been done to Fulcrum

=head1 DESCRIPTION

Proxy job that sends an Upload::Completed job to the Fulcrum
system. The job payload will be similar to below:

{
 upload_id => 345
}
