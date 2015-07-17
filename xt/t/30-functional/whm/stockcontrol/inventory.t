#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

inventory.t - Test the Product Details page

=head1 DESCRIPTION

Set the storage_type, and test the resulting AMQ messages to IWS and PRL

#TAGS prl iws inventory whm

=cut

use FindBin::libs;
use Test::XTracker::RunCondition
    export => qw( $prl_rollout_phase );



use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XTracker::Artifacts::RAVNI;
use Test::XT::Flow;

use XT::Domain::PRLs;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw( :authorisation_level :storage_type );
use Data::Dump  qw( pp );


my $schema      = Test::XTracker::Data->get_schema;
my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::StockControl',
    ],
);
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

# Get 2 products and a voucher
my ($channel,$pids) = Test::XTracker::Data->grab_products( {
                                how_many => 2,
                                channel => 'nap',
                                phys_vouchers => {
                                    how_many => 1,
                                    want_stock => 0,   # the amount of stock you want set for the voucher
                                },
                            } );

# and make sure one product doesn't have stock
my $variants_pid_0 = $schema->resultset('Public::Variant')->search({product_id => $pids->[0]->{pid}});
while (my $variant = $variants_pid_0->next){
    $schema->resultset('Public::Quantity')->search({variant_id => $variant->id})->delete;
}
# make sure one product has stock
Test::XTracker::Data->ensure_stock($pids->[1]->{'pid'}, $pids->[1]->{'size_id'}, $channel->id );
# we'll use this later
my $variants_pid_1 = $schema->resultset('Public::Variant')->search({product_id => $pids->[1]->{pid}});

# store products in handly list
my $products = [];
push @$products, $schema->resultset('Public::Product')->find($pids->[0]->{pid});
push @$products, $schema->resultset('Public::Product')->find($pids->[1]->{pid});
push @$products, $schema->resultset('Voucher::Product')->find($pids->[2]->{pid});

# check data set up OK
ok(!$products->[0]->has_stock, "first product has no stock");
ok($products->[1]->has_stock, "second product has stock");
ok($products->[2]->is_physical, "third product is physical voucher");

# ensure storage types set on products
$products->[0]->update({storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT});
$products->[1]->update({storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT});


# righto - go to the ProductDetails page for each product
#
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Stock Control/Inventory'
    ]}
});

$framework->flow_mech__stockcontrol__inventory_productdetails($pids->[0]->{pid})
          ->flow_mech__stockcontrol__inventory_productdetails_submit({storage_type => $PRODUCT_STORAGE_TYPE__CAGE})
          ->mech->has_feedback_success_ok(qr/Product attributes updated successfully/);
# check we generated a message to IWS
$xt_to_wms->expect_messages({
    messages => [ {
        type => 'pid_update',
        details => {
            pid => $pids->[0]->{pid},
            storage_type => 'cage',
        },
    } ]
});

# If PRLs are turned on, we should've sent one sku_update message per PRL per variant
if ($prl_rollout_phase) {
    my @prls = XT::Domain::PRLs::get_all_prls;
    my @messages;
    foreach my $prl (@prls) {
        foreach my $variant ($variants_pid_0->all) {
            push @messages,
            {
                '@type' => 'sku_update',
                'path' => $prl->amq_queue,
                details => {
                    'sku' => $variant->sku,
                    'storage_type' => 'Cage',
                },
            };
        }
    }
    $xt_to_prls->expect_messages({
        messages => \@messages
    });
}

$framework->flow_mech__stockcontrol__inventory_productdetails($pids->[1]->{pid})
          ->flow_mech__stockcontrol__inventory_productdetails_submit({storage_type => $PRODUCT_STORAGE_TYPE__OVERSIZED})
          ->mech->has_feedback_success_ok(qr/Product attributes updated successfully/);

$framework->flow_mech__stockcontrol__inventory_productdetails($pids->[2]->{pid})
          ->flow_mech__stockcontrol__inventory_productdetails_submit({storage_type => $PRODUCT_STORAGE_TYPE__OVERSIZED})
          ->mech->has_feedback_error_ok(qr/This page doesn't support voucher changes/);

# check data changed as expected
is($products->[0]->discard_changes->storage_type_id, $PRODUCT_STORAGE_TYPE__CAGE, 'First product storage type updated');
is($products->[1]->discard_changes->storage_type_id, $PRODUCT_STORAGE_TYPE__OVERSIZED, 'Second product storage type updated');

# check we generated a message to IWS
$xt_to_wms->expect_messages({
    messages => [ {
        type => 'pid_update',
        details => {
            pid => $pids->[1]->{pid},
            storage_type => 'oversize',
        },
    } ]
});

# If PRLs are turned on, we should've sent one sku_update message per PRL per variant
if ($prl_rollout_phase) {
    my @prls = XT::Domain::PRLs::get_all_prls();
    my @messages;
    foreach my $prl (@prls) {
        foreach my $variant ($variants_pid_1->all) {
            push @messages,
            {
                '@type' => 'sku_update',
                'path' => $prl->amq_queue,
                details => {
                    'sku' => $variant->sku,
                    'storage_type' => 'Oversized',
                },
            };
        }
    }
    $xt_to_prls->expect_messages({
        messages => \@messages
    });
}

done_testing();
