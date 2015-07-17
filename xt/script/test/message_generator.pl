#!/usr/bin/env perl
use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Role::WithAMQMessageFactory;

# This only ever works for VERY VERY VERY VERY simple cases. If you don't
# IMMEDIATELY understand why from a VERY quick glance at the next line, then
# under NO CIRCUMSTANCES should you EVER EVER EVER run this script. Really.
my ( $message_type, %payload ) = @ARGV;
die "Usage: perl message_generator.pl MessageType args go here"
    unless $message_type;

my $factory = XTracker::Role::WithAMQMessageFactory->build_msg_factory;

$factory->transform_and_send('XT::DC::Messaging::Producer::WMS::' . $message_type, \%payload);
