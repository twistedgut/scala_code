package XT::JQ::DC::Send::Operator::Message;

use Moose;

use MooseX::Types::Moose qw( Str Int ArrayRef );
use MooseX::Types::Structured qw( Dict );

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker::FulcrumProxy';

has payload => (
    is => 'ro',
    isa => ArrayRef[
        Dict[
            recipient_id => Int,
            sender_id => Int,
            subject => Str,
            body => Str,
        ]
    ],
    required => 1
);

has '+fulcrum_jobname' => (
    default => 'Receive::Operator::Message',
);


sub check_job_payload { return (); }


1;

=head1 NAME

XT::JQ::DC::Send::Operator::Message - Send a Message to an Operator

=head1 DESCRIPTION

Proxy job that sends a Operator::Message job to the Fulcrum
system. The job payload will be similar to below:

[
 {
  recipient_id => 904,
  sender_id => 56,
  subject => 'Subject of Message',
  body => 'Message Body'
 }
]
