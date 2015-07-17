#!/usr/env perl
use strict;
use warnings;

=head1 NAME

log_pws_stock.t - tests that pws log entries are correctly generated

=head1 DESCRIPTION

Tests that the log_stock_change method on the Public::LogPwsStock DBIC
class generates log entries correctly and does not generate duplicate
log entries

#TAGS shouldbeunit sql

=cut

use FindBin::libs;

use Test::XTracker::Data;
use Test::Most;
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw( :channel :pws_action );
use XTracker::Database qw( get_database_handle );

my $channel_id  = Test::XTracker::Data->any_channel->id;
my $schema = Test::XTracker::Data->get_schema;
my $dbh = $schema->storage->dbh;
my $variant_id;
my $variance    = 12;
my $notes       = 'A message';

sub clean_log {
    $dbh->do("delete from log_pws_stock where variant_id = ? AND pws_action_id = ? AND channel_id = ?", {}, $variant_id, $PWS_ACTION__UPLOAD, $channel_id);
}

sub do_logging {
    my $action = shift || $PWS_ACTION__UPLOAD;
    $schema->resultset('Public::LogPwsStock')->log_stock_change(
        variant_id      => $variant_id,
        channel_id      => $channel_id,
        pws_action_id   => $action,
        quantity        => $variance,
        notes           => $notes,
    );
}

$schema->txn_do(sub{
   my (undef,$pids) = Test::XTracker::Data->grab_products({
       how_many => 1,
       channel_id => $channel_id,
   });
   $variant_id  = $pids->[0]{variant_id};

   # make sure we have a known start point!
   ok(clean_log(), "delete all existing logs for $variant_id");

   # test that there are NO warnings
   warnings_are { do_logging() } [], 'no warnings with first log entry';
   warning_like { do_logging() } [qr/\Aduplicate log_pws_stock request for variant_id=$variant_id, channel_id=$channel_id, operator_id=$APPLICATION_OPERATOR_ID/], 'warning generated with duplicate log entry';

   # test that there are NO warnings after we cleanup
   ok(clean_log(), "delete all existing logs for $variant_id");

   warnings_are { do_logging() } [], 'no warnings with log entry after ROLLBACk';

   # test that we can still [incorrectly? who knows?] log many varian-action
   # pairs that aren't Upload, without warnings
   warnings_are { do_logging( $PWS_ACTION__RESERVATION ) } [], 'no warnings with first Reservation log entry';
   warnings_are { do_logging( $PWS_ACTION__RESERVATION ) } [], 'no warnings with second Reservation log entry';

   # clean and close
   $schema->storage->txn_rollback;

   done_testing;
});
