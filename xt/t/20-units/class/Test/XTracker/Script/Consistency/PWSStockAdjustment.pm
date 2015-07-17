package Test::XTracker::Script::Consistency::PWSStockAdjustment;
use NAP::policy "tt", qw/test class/;
use Test::MockModule;
sub get_schema { shift->schema(); }

BEGIN {
    extends 'NAP::Test::Class';

    with qw/
        Test::Role::WithSchema
        XT::Data::Order::Import::Role::ManipulateOrderFiles
        Test::Role::Channel
    /;
};

use XTracker::Script::Consistency::PWSStockAdjustment;
use XTracker::Config::Parameters 'sys_param';
use Test::XTracker::Data;

sub test__order_backlog :Tests {
    my ($self) = @_;

    my $stockadjust_script = XTracker::Script::Consistency::PWSStockAdjustment->new();

    $self->clear_all_shipping_methods();
    note('Clear all of the existing split order xml files');

    my $nap_channel = $self->nap_channel();
    my $backlog = $stockadjust_script->order_backlog($nap_channel);
    is($backlog, 0, 'No backlog returned when there are no order files on NAP');

    $self->add_order_file_to_shipping_method({
        shipping_method     => 'standard',
        status              => 'ready',
        channel             => $nap_channel,
        order_number        => 42,
        order_file_number   => 1,
        modification_time   => $self->schema()->db_now()->add( seconds => 5 )->epoch(),
    });
    note('Add a new order with modification time of now');

    $backlog = $stockadjust_script->order_backlog($nap_channel);
    ok($backlog > 0, 'A backlog has been detected...');
    is($stockadjust_script->is_within_threshold($backlog), 1, '... and it is within the threshold');

    $self->add_order_file_to_shipping_method({
        shipping_method     => 'standard',
        status              => 'ready',
        channel             => $nap_channel,
        order_number        => 42,
        order_file_number   => 2,
        modification_time   => $self->schema()->db_now()->add( hours => 2 )->epoch(),
    });

    $backlog = $stockadjust_script->order_backlog($nap_channel);
    ok($backlog > 0, 'A backlog has been detected...');
    is($stockadjust_script->is_within_threshold($backlog), 0, '... and it is outside the threshold');

    my $mrp_channel = $self->mrp_channel();
    $backlog = $stockadjust_script->order_backlog($mrp_channel);
    is($backlog, 0, 'No backlog returned when there are no order files on MRP (files from other channels are ignored)');
}

sub test__invoke :Tests {
    my ($self) = @_;

    my $stockadjust_script = XTracker::Script::Consistency::PWSStockAdjustment->new();

    $self->clear_all_shipping_methods();

    my $email_params;my $sku;my $pws_quantity = 10;
    my $sm_mock = Test::MockModule->new('XTracker::WebContent::StockManagement::OurChannels');
    $sm_mock->mock(get_all_stock_levels => sub {
                       return {$sku => $pws_quantity};
                   });
    my $pwssa_mock = Test::MockModule->new('XTracker::Script::Consistency::PWSStockAdjustment');
    $pwssa_mock->mock(send_summary_email => sub {
                          $email_params = $_[1];
                      });

    $sku = '0-0';
    $stockadjust_script->invoke();
    cmp_deeply($email_params,
               {
                   channels => array_each(
                       {
                           name => ignore(),
                           sc_error => re(qr{\A'0-0' is not a valid SKU\b}),
                       },
                   ),
               },
               'script dies with bogus SKUs')
        or diag 'Got: '. Data::Printer::p($email_params);

    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        channel => $self->nap_channel,
        how_many => 1,
        ensure_stock_all_variants => 1,
    });
    $sku = $pids->[0]{sku};
    $email_params=undef;
    $self->schema->resultset('Public::StockConsistency')->delete;
    my $old_value = sys_param('webconsistency/pids');
    sys_param('webconsistency/pids',[]);

    my $run_invoke = sub {
        # the script ignores stock_consistencies reported <=2 times,
        # so we run it three times
        for (1..3) {
            $stockadjust_script->invoke();
            Test::XTracker::Data->ensure_stock(
                $pids->[0]{pid},
                $pids->[0]{size_id},
                $channel->id,
            );
            for my $d ($channel->search_related('stock_consistencies')->all) {
                note Data::Printer::p($d);
            }
        }
    };

    $run_invoke->();
    cmp_deeply($email_params,
               {
                   channels => superbagof({
                       fail => {},
                       name => $channel->name,
                       success => {
                           $pids->[0]{pid} => {
                               $pids->[0]{size_id} => {
                                   pws_quantity => $pws_quantity,
                                   sku => $sku,
                                   xt_quantity => ignore(),
                               },
                           },
                       },
                   }),
               },
               'discrepancy noticed')
        or diag 'Got: '. Data::Printer::p($email_params);

    sys_param('webconsistency/pids',[$pids->[0]{pid}]);
    $email_params=undef;

    $run_invoke->();
    cmp_deeply($email_params,
               undef,
               'script ignores PIDs when instructed')
        or diag 'Got: '. Data::Printer::p($email_params);

    sys_param('webconsistency/pids',$old_value);
}
