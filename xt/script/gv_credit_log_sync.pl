#!/usr/bin/env perl
use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database qw(get_database_handle);

local $| = 1;

my $schema = get_database_handle({ name => 'xtracker_schema', type => 'readonly' });

my $invoices = $schema->resultset('Public::Renumeration');
my $orders = $schema->resultset('Public::Orders');
use DateTime::Format::MySQL;
use Path::Class;
use Text::CSV;

my $channels = $schema->resultset('Public::Channel')->get_channels({ fulfilment_only => 0 )};

for my $ch (values %$channels) {
    my $logs = $schema->resultset('Public::CustomerCreditLog')->search(
        { 'customer.channel_id' => $ch->{id} },
        { order_by => 'date', 
          prefetch => [
              'customer',
              { 'customer_credit' => 'currency' },
          ],
        },
    );

    my $fname = "customer_credit_$ch->{config_section}-$ch->{dc}";
    my $csv = Text::CSV->new( { eol => "\r\n" } );
    my $error = file( "$fname-discrepency.csv" )->openw;
    my $sql = file( "$fname.sql" )->openw;
    $error->autoflush(1);
    $sql->autoflush(1);

    $csv->print($error, [ qw(customer_id xt_balance xt_currency web_balance web_currency reason) ]);

    $sql->print( <<'EOF' );
BEGIN;
DELETE FROM customer_credit_log;

INSERT INTO customer_credit_log 
  (customer_credit_id, order_id, action, delta, context, created_dts, created_by, last_updated_dts, last_updated_by,notes)
  VALUES
EOF


    my $first = 0;

    my $count = 0;

    while (my $l = $logs->next) {
      $count++;
      my $id = get_pws_customer_credit_log_id($l, $csv, $error);

      unless ($id) {
        $csv->print($error, [
            $l->customer->pws_customer_id,
            $l->customer_credit->credit,
            $l->customer_credit->currency->currency,
            undef,
            undef,
            "Cant find row in web db"
        ] );
        next;
      }

      my $order_id = "NULL";
      my $delta = $l->change;
      my $op_id = $l->operator_id;
      my $when =  DateTime::Format::MySQL->format_datetime($l->date);
      my $notes = $l->action;
      my $action = '"ADJUSTED"';

      $notes =~ s/\\/\\\\/;
      $notes =~ s/"/""/;
      $notes =~ s/\n/\\n/;

      if ($notes =~ /^Refund - ([0-9-]+)/) {
        my ($i, $o);
        $i = $invoices->search({invoice_nr => $1})->first;

        $o = $i->shipment->order if $i;

        if ($o && $o->order_nr =~ /^[0-9]+$/) {
          $order_id = $o->order_nr;
          $action = '"REFUNDED"';
        }
      }
      elsif ($notes =~ /^Order - ([0-9-]+)/) {
        my $o = $orders->search({order_nr => $1})->first;

        if ($o) {
          $order_id = $o->order_nr;
          $action = '"ORDER_PAYMENT"';
        }
      }

      $sql->print( qq{\n  ($id, $order_id, $action, $delta, "", "$when", "xt-$op_id", "$when", "xt-$op_id", "$notes") } );

      warn "Processed $count log rows for $ch->{name}\n" unless $count % 1000;
    }

    $sql->print( qq{\n;} );
    $sql->close;
    $error->close;
    warn "Done $ch->{name}\n" unless $count % 1000;
}

{
  # Hash of is/pws_customer_id to the id in the MySQL customer_credit_log table.
  my $pws_customer_credit_log_ids = {};
  my $web_dbhs;
  my $web_sths;
  sub get_pws_customer_credit_log_id {
    my ($log, $csv, $error) = @_;

    my $customer = $log->customer;

    return $pws_customer_credit_log_ids->{ $customer->id }
      if exists $pws_customer_credit_log_ids->{ $customer->id };

    my $channel = $customer->channel;

    my $sth = $web_sths->{$channel->id} ||= do {
      my $web_dbh = $web_dbhs->{$channel->id} 
              ||= get_database_handle({name => 'Web_Live_'.$channel->business->config_section, type => 'readonly' });

      $web_dbh->prepare("SELECT id, currency_code, value FROM customer_credit where customer_id = ?");
    };

    $sth->execute( $customer->pws_customer_id );

    my $data = $sth->fetchrow_hashref;
    $sth->finish;

    return unless $data;

    my $discrepency;
    $discrepency = "amount mis-match" if $log->customer_credit->credit+0 != $data->{value}+0;
    $discrepency = "currency mis-match" if $log->customer_credit->currency->currency ne $data->{currency_code};

    $csv->print($error, [
        $log->customer->pws_customer_id,
        $log->customer_credit->credit,
        $log->customer_credit->currency->currency,
        $data->{value},
        $data->{currency_code},
        $discrepency
    ] ) if $discrepency;

    return $pws_customer_credit_log_ids->{ $customer->id } = $data->{ id };
  }
}
