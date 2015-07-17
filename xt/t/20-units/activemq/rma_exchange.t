#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use Catalyst::Utils qw/merge_hashes/;
use Test::NAP::Messaging::Helpers 'napdate';
use XT::Domain::Returns;
use XTracker::Config::Local;
use XTracker::Constants::FromDB qw/
    :customer_issue_type
    :renumeration_type
    :renumeration_class
    :renumeration_status
    :flow_status
    :shipment_type
/;

my $schema = Test::XTracker::Data->get_schema;
my $amq = Test::XTracker::MessageQueue->new;

my $pids = Test::XTracker::Data->find_or_create_products({
    how_many => 2,
    avoid_one_size => 1,
    force_create => 1,
});
my @skus=map {$_->{sku}} @$pids;

my $out_queue = config_var('Producer::PreOrder::TriggerWebsiteOrder','routes_map')->{Test::XTracker::Data->channel_for_nap->web_name};

ok(
  my $domain = XT::Domain::Returns->new(
    schema => $schema,
    msg_factory => $amq->producer,
    requested_from_arma => 1,
  ),
  "Created Returns domain"
);

test_return_RMA();

test_exchange_RMA();

done_testing;

sub test_return_RMA {
    note "Testing a Return";

    $amq->clear_destination($out_queue);

    # Create a return order
    my ($order, $si) = make_order();

    my $return = $domain->create({
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

    is($return->exchange_shipment_id, undef, "Return has no exchange shipment");
    # This test is broken for the sunny(ish) half of the year.
    # We need to sync TZ with the database to avoid midnight failures
    my $return_dt = $return->creation_date->clone->truncate(to => 'day');
    is($return_dt,
       DateTime->now->clone->set_time_zone($return_dt->time_zone)->truncate(to => 'day'),
       "Return has a creation date");

    my @items = $si->shipment->shipment_items->order_by_sku;
    my $shipment = $si->shipment;

    $return->discard_changes;
    $amq->assert_messages({
        destination => $out_queue,
        filter_header => superhashof({
            type => 'OrderMessage',
        }),
        filter_body => superhashof({
            orderNumber => $order->order_nr,
        }),
        assert_body => superhashof({
            orderItems => bag(
                all(
                    superhashof({
                        returnable => "Y",
                        sku => $skus[1],
                        status => "Dispatched",
                        unitPrice => "250.000",
                        tax => "0.000",
                        duty => "0.000",
                    }),
                    code(sub{! exists shift->{returnCreationDate}}),
                ),
                superhashof({
                  returnCreationDate => napdate($return->return_items->first->creation_date),
                  returnReason => "POOR_FIT",
                  returnable => "Y",
                  sku => $skus[0],
                  status => "Return Pending",
                  unitPrice => "100.000",
                  tax => "0.000",
                  duty => "0.000",
                  xtLineItemId => $si->id,
                }),
            ),
            orderNumber            => $order->order_nr,
            returnCancellationDate => napdate($return->cancellation_date),
            returnCreationDate     => napdate($return->creation_date),
            returnCutoffDate       => napdate($shipment->return_cutoff_date),
            rmaNumber              => $return->rma_number,
            status                 => "Dispatched",
        }),
    }, 'order status sent on AMQ');

    $amq->clear_destination($out_queue);
    my $stock_manager = $order->channel->stock_manager;
    $domain->cancel({return_id => $return->id, operator_id => 1, stock_manager => $stock_manager});

    $return->discard_changes;
    ok($return->is_cancelled, "Return is now cancelled");

    $order->discard_changes;
    is($shipment->returns->not_cancelled->first,
       undef,
       "Order doesn't have RMA anymore"
      );

    # Now cancel the return, the payload should go back to the original form
    $amq->assert_messages({
        destination => $out_queue,
        filter_header => superhashof({
            type => 'OrderMessage',
        }),
        filter_body => superhashof({
            orderNumber => $order->order_nr,
        }),
        assert_body => all(
            superhashof({
                orderItems => bag(
                    all(
                        superhashof({
                            status => "Dispatched",
                        }),
                        code(sub{! exists shift->{returnCreationDate}}),
                    ),
                    all(
                        superhashof({
                            sku => $skus[0],
                            status => "Dispatched",
                        }),
                        code(sub{! exists shift->{returnCreationDate}}),
                    ),
                ),
                orderNumber            => $order->order_nr,
                returnCutoffDate       => napdate($shipment->return_cutoff_date),
                status                 => "Dispatched",
            }),
            code(sub{   !exists $_[0]->{returnCancellationDate}
                     && !exists $_[0]->{rmaNumber} })
        ),
    }, 'order status message correct after cancel RMA');
}

sub test_exchange_RMA {
    note "Testing an Exchange";

    $amq->clear_destination($out_queue);

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
        },
      }
    );
    my $shipment    = $si->shipment;

    # fix the data so there should be charges
    $shipment->update( { shipment_type_id => $SHIPMENT_TYPE__INTERNATIONAL } );
    $shipment->shipment_address->update( { country => Test::XTracker::Data->get_non_charge_free_state()->country } );

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

    my $return = $domain->create({
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

    my @items = $shipment->shipment_items->order_by_sku;

    # get the latest last log
    my $new_pws_stock_log   = $pws_stock_log_rs->reset->first;
    cmp_ok( $new_pws_stock_log->id , '>', $org_pws_stock_log->id, "New PWS Stock Log's Id is greater than Original so new log has been created" );
    cmp_ok( $new_pws_stock_log->quantity, '==', -1, "New PWS Stock Log Quantity is '-1'" );
    is( $new_pws_stock_log->notes, "Exchange on ".$return->shipment_id, "New Stock Notes field has Exhange Shipment Id in it" );
    note "NEW PWS STOCK LOG: ". ( defined $new_pws_stock_log ? "ID: ".$new_pws_stock_log->id.", ".$new_pws_stock_log->notes : 'N/A' );

    $amq->assert_messages({
        destination => $out_queue,
        filter_header => superhashof({
            type => 'OrderMessage',
        }),
        filter_body => superhashof({
            orderNumber => $order->order_nr,
        }),
        assert_body => superhashof({
            orderItems => bag(
                all(
                    superhashof({
                        returnable => "Y",
                        sku => $skus[1],
                        status => "Dispatched",
                    }),
                    code(sub{! exists shift->{returnCreationDate}}),
                ),
                superhashof({
                    returnCreationDate => napdate($return->return_items->first->creation_date),
                    returnReason => "SIZE_TOO_SMALL",
                    exchangeSku => $exchange_var->sku,
                    returnable => "Y",
                    sku => $skus[0],
                    status => "Return Pending",
                    xtLineItemId => $si->id,
                }),
            ),
            orderNumber            => $order->order_nr,
            returnCancellationDate => napdate($return->cancellation_date),
            returnCreationDate     => napdate($return->creation_date),
            returnCutoffDate       => napdate($shipment->return_cutoff_date),
            rmaNumber              => $return->rma_number,
            status                 => "Dispatched",
        }),
    }, 'order status sent on AMQ');


    # We are creating an exchange *WITH TAX*. There should be debit of a -ve
    # ammount (i.e. we need to charge the customer tax to ship this)
    # as we have created the Shipment with a "non_charge_free_state"
    my $renum_ammount = $tax_ammount + $duty_ammount;
    ok(my $renum = $shipment->renumerations->first, "We have a renumeration")
            or die "No renmeration on shipment @{[$shipment->id]}";

    cmp_ok($renum->renumeration_class_id, '==', $RENUMERATION_CLASS__RETURN, "Renumeration class of Return");
    cmp_ok($renum->renumeration_type_id, '==', $RENUMERATION_TYPE__CARD_DEBIT, "Card debit");
    cmp_ok($renum->renumeration_status_id, '==', $RENUMERATION_STATUS__PENDING, "Renumeration status is Pending");
    cmp_ok($renum->total_value, '==', $renum_ammount, "Refund of $renum_ammount");

    $amq->clear_destination($out_queue);
    my $stock_manager = $order->channel->stock_manager;
    $domain->cancel({
        return_id => $return->id, operator_id => 1, stock_manager => $stock_manager,
    });

    $return->discard_changes;
    ok($return->is_cancelled, "Return is now cancelled");

    ok($return->exchange_shipment->is_cancelled, "Return has exchange shipment cancelled")
      or diag($return->exchange_shipment->shipment_status_id);

    $order->discard_changes;
    is($shipment->returns->not_cancelled->first,
       undef,
       "Order doesn't have RMA anymoe"
      );

    # Now cancel the return, and it should go from the message.
    $amq->assert_messages({
        destination => $out_queue,
        filter_header => superhashof({
            type => 'OrderMessage',
        }),
        filter_body => superhashof({
            orderNumber => $order->order_nr,
        }),
        assert_body => all(
            superhashof({
                orderItems => bag(
                    all(
                        superhashof({
                            status => "Dispatched",
                        }),
                        code(sub{! exists shift->{returnCreationDate}}),
                    ),
                    all(
                        superhashof({
                            sku => $skus[0],
                            status => "Dispatched",
                        }),
                        code(sub{! exists shift->{returnCreationDate}}),
                    ),
                ),
                orderNumber            => $order->order_nr,
                returnCutoffDate       => napdate($shipment->return_cutoff_date),
                status                 => "Dispatched",
            }),
            code(sub{   !exists $_[0]->{returnCancellationDate}
                     && !exists $_[0]->{rmaNumber} })
        ),
    }, 'order status message correct after cancel RMA');
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
