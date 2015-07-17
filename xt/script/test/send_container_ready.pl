#!/usr/bin/env perl
#
# Script that will simulate the send of a 'container_ready' message from the dematic PRL
# to XT. For example:
#
# send_container_ready.pl --container TSW0001 --allocations 345 348
#
# Where 'container' identifies teh conatiner that the allocations have been picked in to
# and the allocations identify the allocations that have been picked
#
use strict;
use warnings;
use Getopt::Long;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Test::XTracker::Data;
use XTracker::Config::Local;


package NAP::Script::SendContainerReady {
    use Moose;
    with 'NAP::Test::Class::PRLMQ';

    has 'container_id' => (
        is => 'ro',
        required => 1,
    );

    has 'allocation_ids' => (
        is => 'ro',
        required => 1,
    );

    sub send_msg {
        my ($self) = @_;
        return $self->send_message($self->create_message(
            'ContainerReady' => {
                container_id => $self->container_id(),
                allocations  => [ map {{ allocation_id => "$_" }} @{$self->allocation_ids()} ],
                prl          => "dcd",
        }));
    }
};

my ($container_id, @allocation_ids);
GetOptions(
    'container=s' => \$container_id,
    'allocations=i{1,}' => \@allocation_ids,
);

NAP::Script::SendContainerReady->new(
    container_id => $container_id,
    allocation_ids => \@allocation_ids,
)->send_msg();

