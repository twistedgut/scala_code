#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head2 CANDO-180: Bug - Creating an Exchange takes 2 items off the Web-Stock level

When a user on xTracker creates an Exchange Return 2 items of stock are taken off the web-site when
only one item should be. This is because in order to display the Return Confirmation page the code
calls the method to create a return using the Returns Domain in the Handler and then rolls back
any changes that are made - BUT because there are web-site stock updates done whilst creating the
Exchange and these use a seperate database handle connected to the web db this chnage is committed
and not rolled back.

To fix this I have added a method 'called_in_preview_create_mode' in the Returns Domain Class which
when set to true prevents web-site stock updates from taking place as well as sending the AMQ message
to the web-site which is also unnecessary at the pre-confirmation stage.

=cut



use Test::XTracker::Data;
use Test::XTracker::RunCondition export => qw( $distribution_centre );
use Test::XTracker::MessageQueue;

use Catalyst::Utils qw/merge_hashes/;

use XT::Domain::Returns;
use XTracker::Config::Local;
use XTracker::Constants::FromDB qw/
    :customer_issue_type
    :renumeration_type
    :renumeration_class
    :flow_status
/;

# set-up the message queues based on DC
my $config = {
    DC1 => { queue => '/queue/nap-intl-orders' },
    DC2 => { queue => '/queue/nap-am-orders' },
    DC3 => { queue => '/queue/nap-apac-orders' }
}->{ $distribution_centre };

my $schema = Test::XTracker::Data->get_schema;
my $amq = Test::XTracker::MessageQueue->new;

my $pids = Test::XTracker::Data->find_or_create_products({
    how_many => 2,
    avoid_one_size => 1,
    force_create => 1,
});
my @skus=map {$_->{sku}} @$pids;

ok(
  my $domain = XT::Domain::Returns->new(
    schema => $schema,
    msg_factory => $amq->producer,
  ),
  "Created Returns domain"
);

test_return_RMA();

test_exchange_RMA();

done_testing;

sub test_return_RMA {
    note "Testing a Return";

    # Create a return order
    my ($order, $si) = make_order();

    # clear the AMQ queue
    $amq->clear_destination($config->{queue});

    my $return = $domain->create({
      called_in_preview_create_mode => 1,
      operator_id => 1,
      shipment_id => $si->shipment_id,
      pickup => 0,
      return_items => {
         $si->id => {
          type => 'Return',
          reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
        }
      }
    });
    $return->discard_changes;

    is($return->exchange_shipment_id, undef, "Return has no exchange shipment");
    cmp_ok( $return->return_items->count(), '==', 1, "Return has 1 Return Item" );
    # This test is broken for the sunny(ish) half of the year.
    # We need to sync TZ with the database to avoid midnight failures
    my $return_dt = $return->creation_date->clone->truncate(to => 'day');
    is($return_dt,
       DateTime->now->clone->set_time_zone($return_dt->time_zone)->truncate(to => 'day'),
       "Return has a creation date");

    # check no AMQ messages have been created
    cmp_ok( scalar $amq->messages( $config->{'queue'} ), '==', 0,  "No AMQ Messages sent" );
}

sub test_exchange_RMA {
    note "Testing an Exchange";

    # Create a return order
    my $tax_ammount = 10;
    my $duty_ammount = 5;
    my ($order, $si) = make_order(
      { items => {
          $skus[0] => {
              price => 100.00,
              tax => $tax_ammount,
              duty => $duty_ammount,
          },
        }
      }
    );

    my $exchange_var = $pids->[0]->{product}->search_related('variants',{
        size_id => { '!=' => $pids->[0]->{size_id} },
    })->slice(0,0)->single;

    Test::XTracker::Data->set_product_stock({
      product_id => $exchange_var->product_id,
      size_id => $exchange_var->size_id,
      quantity => 100,
      stock_status => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    });

    # get the Web-Site Stock update logs
    # for the exchange variant
    my $pws_stock_log_rs    = $exchange_var
                                ->log_pws_stocks
                                    ->search( {}, { order_by => 'me.id DESC' } );
    my $org_pws_stock_log   = $pws_stock_log_rs->first;     # get the current last log
    note "ORIGINAL PWS STOCK LOG: ". ( defined $org_pws_stock_log ? "ID: ".$org_pws_stock_log->id.", ".$org_pws_stock_log->notes : 'N/A' );

    # clear the AMQ queue
    $amq->clear_destination($config->{queue});

    my $return = $domain->create({
      called_in_preview_create_mode => 1,
      operator_id => 1,
      shipment_id => $si->shipment_id,
      pickup => 0,
      refund_type_id => $RENUMERATION_TYPE__CARD_DEBIT,
      return_items => {
         $si->id => {
          type => 'Exchange',
          reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
          exchange_variant => $exchange_var->id,
        }
      }
    });
    $return->discard_changes;

    isnt(my $ex = $return->exchange_shipment, undef, "return has exchange shipment");
    ok($ex->is_exchange, "Exchange shipment is actually an exchange");
    ok($ex->is_awaiting_return, "Exchange shipment on hold");
    cmp_ok( $ex->shipment_items->count(), '==', 1, "Exchange shipment has 1 Shipment Item" );
    cmp_ok( $ex->shipment_items->first->variant_id, '==', $exchange_var->id,
                                    "Exchange Shipment Item's Variant Id is the same as the Exchange Variant requested" );
    cmp_ok( $return->return_items->first->exchange_shipment_item_id, '==', $ex->shipment_items->first->id,
                                    "Return Item's Exchange Shipment Id is the same as the Exchange Shipment Item's Id" );

    my $shipment = $si->shipment;
    my @items = $shipment->shipment_items->order_by_sku;

    # get the latest last log
    my $new_pws_stock_log   = $pws_stock_log_rs->reset->first;
    if ( defined $org_pws_stock_log ) {
        cmp_ok( $new_pws_stock_log->id, '==', $org_pws_stock_log->id,
                                "New PWS Stock Log record Id is the same as the original one meaning no new log records have been created" );
    }
    else {
        # if the original wasn't defined then neither
        # should the new one be
        ok( !defined $new_pws_stock_log, "New PWS Stock Log record is Undefined so no new log has been created" );
    }
    note "NEW PWS STOCK LOG: ". ( defined $new_pws_stock_log ? "ID: ".$new_pws_stock_log->id.", ".$new_pws_stock_log->notes : 'N/A' );

    # We are creating an exchange *WITH TAX*. There should be debit of a -ve
    # ammount (i.e. we need to charge the customer tax to ship this)
    # for a domestic shipment type there should be NO renumeration
    # only for internation ie south africa
    my $renum_ammount = $tax_ammount + $duty_ammount;
    if (!$shipment->is_domestic) {
        ok(my $renum = $shipment->renumerations->first, "We have a renumeration")
          or die "No renmeration on shipment @{[$shipment->id]}";

        is($renum->renumeration_class_id, $RENUMERATION_CLASS__RETURN, "Renumeration class of Return");
        cmp_ok($renum->total_value, '==', -$renum_ammount, "Refund of -$renum_ammount (yes, a negative refund)");
        is($renum->renumeration_type_id, $RENUMERATION_TYPE__CARD_DEBIT, "Card debit");

    }

    # check no AMQ messages have been created
    cmp_ok( scalar $amq->messages( $config->{'queue'} ), '==', 0,  "No AMQ Messages sent" );
}


# Create an order, and return the Order object and a shipment item
sub make_order {
    my ($data) = @_;

    $data ||= {};

    $data = Catalyst::Utils::merge_hashes(
      {
        items => {
          $skus[0] => { price => 100.00 },
          $skus[1] => { price => 250.00 },
        }
      },
      $data
    );

    my $order = Test::XTracker::Data->create_db_order( $data );

    my $shipment = $order->shipments->first;

    my $si = $shipment->shipment_items->find_by_sku($skus[0]);

    return ($order, $si);
}

