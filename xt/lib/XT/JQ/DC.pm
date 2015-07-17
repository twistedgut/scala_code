package XT::JQ::DC;
# vim: ts=8 sts=4 et sw=4 sr sta
use Moose; # automagically gives us strict and warnings
use MooseX::FollowPBP;

use Carp;
use XT::JQ::DC::Queue;


extends 'XT::Common::JQ::Interface';

has '+queue' => (
    default => sub { return XT::JQ::DC::Queue->new } ,
);

no Moose;

1;
__END__

pod

=head1 NAME

XT::JQ::DC - an interface to creating jobs for the DC job queue

=head1 DESCRIPTION

This module extends XTT::Common::JQ::Interface to allow a simplified way
to create jobs and place them onto the Central job queue for processing.

=head1 SYNOPSIS

 use XT::JQ::DC;

 my $job =XT::JQ::DC->new({ funcname => 'Product::Update' });

 $job->set_feedback_to( { operators= > [ 123, 456 ] } );

 $job->set_remote_targets( ['DC1', 'DC2'] );

 $job->set_export_to_website( 1 );

 $job->set_payload({
     somefields => '1',
     another    => 'hello world',
 });

 my $jobhandle = $job->send_job();

 print 'the job id is ' . $jobhandle->jobid;

=head1 AUTHOR

Jason Tang <jason.tang@net-a-porter.com>

=cut

