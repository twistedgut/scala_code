package XT::DC::Model::MessageQueue;
use NAP::policy "tt", 'class';
extends 'Catalyst::Model';
use XTracker::Database 'xtracker_schema';
use XTracker::Role::WithAMQMessageFactory;

sub COMPONENT {
    my ($class,$app) = @_;
    my $msg_factory = XTracker::Role::WithAMQMessageFactory->build_msg_factory;
    $msg_factory->transformer_args->{schema} = xtracker_schema;

    return $msg_factory;
}
