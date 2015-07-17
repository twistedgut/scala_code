#!/usr/bin/env perl
use strict;
use warnings;
use lib '/opt/xt/deploy/xtracker/lib';
use lib '/opt/xt/deploy/xtracker/lib_dynamic';
BEGIN {$ENV{NO_XT_LOGGER}=1};
use NAP::policy;
use XTracker::Database 'xtracker_schema';
use XTracker::Constants::FromDB qw( :product_channel_transfer_status );
use XTracker::Constants qw( $APPLICATION_OPERATOR_ID );

my $schema = xtracker_schema;

my $nap_channel = $schema->resultset('Public::Channel')->net_a_porter;
my $out_channel = $schema->resultset('Public::Channel')->the_outnet;

# we can ignore vouchers: they are never transferred
my $bad_quantities = $schema->resultset('Public::Quantity')->search({
    'me.quantity' => { '>' => 0 },
    'me.channel_id' => $nap_channel->id,
    'product_channel.channel_id' => $nap_channel->id,
    'product_channel_2.channel_id' => $out_channel->id,
    'product_channel.transfer_status_id' => $PRODUCT_CHANNEL_TRANSFER_STATUS__TRANSFERRED,
},{
    '+select' => [qw(product_variant.product_id location.location)],
    '+as' => [qw(pid location_name)],
    join => [
        'location',
        {
            product_variant => {
                product => ['product_channel','product_channel'],
            },
        },
    ],
});

my @pids;
$schema->txn_do(sub {
  while (my $bq = $bad_quantities->next) {
      my $out_quantity = $schema->resultset('Public::Quantity')->search({
          channel_id => $out_channel->id,
          variant_id => $bq->variant_id,
          status_id => $bq->status_id,
          location_id => $bq->location_id,
      })->next;

      printf "%d items for PID %d in location %s\n",
          $bq->quantity,
              $bq->get_column('pid'),
                  $bq->get_column('location_name'),
                  ;
      push @pids,$bq->get_column('pid');

      if ($out_quantity) {
          say "there's already OUTNET stock in that location, merging the two quantities";
          $out_quantity->update_quantity( $bq->quantity );
          $bq->update_quantity( -$bq->quantity );
          $bq->delete_and_log($APPLICATION_OPERATOR_ID)
              if $bq->quantity==0;
      }
      else {
          say "no OUTNET stock in that location, updating channel for existing NAP stock";
          $bq->update({
              channel_id => $out_channel->id,
          });
      }
  }

  my $products = $schema->resultset('Public::Product')->search({
      id => { -in => \@pids }
  });
  while (my $p = $products->next) {
      $p->broadcast_stock_levels;
  }
});

=pod

This script looks for C<quantity> rows for NAP stock that should
really be OUTNET stock. Then, it either changes the channel for the
quantity, or merges it with an existing OUTNET quantity in the same
location/variant/status.

=cut
