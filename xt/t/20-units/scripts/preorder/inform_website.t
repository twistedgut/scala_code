#!perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;

use Test::XTracker::MessageQueue;
use XTracker::Script::PreOrder::InformWebsite;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw( :pre_order_item_status);

#----------------------------------------------------------------------

my $schema = Test::XTracker::Data->get_schema();

my $producer = Test::XTracker::MessageQueue->new;

#----------------------------------------------------------------------
# An exportable preorder

my $non_exportable_preorder = Test::XTracker::Data::PreOrder->create_complete_pre_order();
my $exportable_preorder = Test::XTracker::Data::PreOrder->create_pre_order_with_exportable_items();

# First get the Result Set used by the Class
my $informer_for_rs = XTracker::Script::PreOrder::InformWebsite->new(
    { producer => $producer } );

# Refine the Result Set to the created preorders
my $rs = $informer_for_rs->preorders_for_export->search(
    { 'me.id' => { 'in' => [ $non_exportable_preorder->id,
                             $exportable_preorder->id,
                           ]
                 },
    });

undef $informer_for_rs;

# Instantiate the script with the Preorder Result Set
my $informer_success
  = XTracker::Script::PreOrder::InformWebsite->new(
      { producer => $producer, preorders_for_export => $rs } );

my $preop_status      = $non_exportable_preorder->pre_order_status_id;
my $preop_item_status = { map { $_->id => $_->pre_order_item_status_id }
                              $non_exportable_preorder->pre_order_items->all };

lives_ok {$informer_success->invoke()}
         'Website message succeeds for mixed preorder status recordset';

my $postop_status      = $non_exportable_preorder->discard_changes->pre_order_status_id;
my $postop_item_status = { map { $_->id => $_->pre_order_item_status_id }
                               $non_exportable_preorder->pre_order_items->all };

# Statuses are unchanged in failure
cmp_deeply( $preop_item_status ,$postop_item_status,
            'Preorder item statuses are unchanged when non-exportable');

ok( $preop_status == $postop_status,
   'Preorder status is unchanged when non-exportable');

ok($exportable_preorder->discard_changes->all_items_are_exported,
   'All preorder item statuses set to exported when exportable');

ok($exportable_preorder->is_exported,
   'Preorder status set to exported when exportable');

ok( !$non_exportable_preorder->is_exported
      && !$non_exportable_preorder->is_part_exported,
    'Preorder has not been set to exported or part-exported when non-exportable');

# Remove the script reference so we can spin up another one
undef $informer_success;

#----------------------------------------------------------------------
# A partially-exportable preorder

my $partially_exportable_preorder
  = Test::XTracker::Data::PreOrder->create_pre_order_with_exportable_items();

$partially_exportable_preorder->pre_order_items
                              ->first
                              ->update({pre_order_item_status_id => $PRE_ORDER_ITEM_STATUS__CONFIRMED});

my $partially_exportable_preorder_rs
  = create_preorder_rs($partially_exportable_preorder);

my $informer_partial
  = XTracker::Script::PreOrder::InformWebsite->new(
      { producer => $producer,
        preorders_for_export => $partially_exportable_preorder_rs
      });

lives_ok {$informer_partial->invoke()}
         'Website is informed of a partially-exportable preorder';

ok(!$partially_exportable_preorder->discard_changes->all_items_are_exported,
   'Preorder item statuses are not all set to exported when partially exportable');

ok($partially_exportable_preorder->some_items_are_exported,
   'Some preorder item statuses are set to exported when partially exportable');

ok($partially_exportable_preorder->is_part_exported,
   'Preorder status is set to part exported when partially exportable');


done_testing;


sub create_preorder_rs {
    my @preorders = @_;

    my $preorder_rs = $schema->source('Public::PreOrder')->resultset;
    $preorder_rs->set_cache(\@preorders);
    return $preorder_rs;
}
