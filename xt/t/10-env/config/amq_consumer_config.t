#!/usr/bin/env perl

use NAP::policy qw/tt test class/;

BEGIN {
    extends "NAP::Test::Class";
}

=head1 NAME

Test both xt_dc_messaging.conf and xt_dc_psp_messaging.conf configs have the same Consumer
definitions.

=head1 SYNOPSIS

NAP::Messaging requires to define the consumer definition in both configs.
It is required that one defines the CONSUMER with 'enabled=0' in one of the file they
do not want the Consumer for. Also set channel_id=0 if Consumer has channel specific config.

=cut

# to be done first before ALL the tests start
sub startup : Test( startup => no_plan ) {
    my $self = shift;

}

=head1 TESTS

=head2 test_consumer_config

Tests Consumer definition exists in both configs ( xt_dc_messaging.conf & xt_dc_psp_messaging.conf)
and the channel_id is defined if it exists.

=cut

sub test_consumer_config : Tests() {
    my $self = shift;

    # Load Config's
    my $psp_config = Test::XTracker::Config->psp_messaging_config;
    my $amq_config = Test::XTracker::Config->messaging_config;

    # Compare the hashes
    cmp_deeply(_clean_hash($amq_config),_clean_hash($psp_config) ,"Configs are defined correctly");
}

sub _clean_hash {
   my $config_hash = shift;

   # Extract only 'Consumer::' ones
   my %consumer_hash =
    map   { $_ => $config_hash->{ $_ } }
    grep  { /^Consumer::/ }
    keys %{ $config_hash };


   # delete all keys except channel_id ones
   # Also make channel_id 0 to compare
   foreach my $key ( keys %consumer_hash ) {

        next unless (ref($consumer_hash{$key}) eq 'HASH');
        foreach my $key1 ( keys %{ $consumer_hash{$key} } ) {
            if($key1 ne 'channel_id' ) {
             delete( $consumer_hash{$key}{$key1});
            } else {
                # Make channel_id value same for comparison
                $consumer_hash{$key}{$key1} = 'IGNORE'
            }
        }
    }

    return \%consumer_hash;
}

Test::Class->runtests;
