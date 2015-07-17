#!/usr/bin/env perl

=head1 NAME

recode_mechanize_iws.t

=head1 DESCRIPTION

Create some new products.

Move some other products out of IWS into transit by sending InventoryAdjust messages.

Perform validation for "cross-channel recode":
    Create products on another channel, and try to recode SKUs on another channel.
    Check that an error correctly occurs.

Perform validation for "not enough stock":
    Try to recode more stock than is available.
    Check that an error correctly occurs.

Save a snapshot of the stock before the recode using L<Test::XTracker::LocationMigration>.

Submit the Recode page with the correct values this time, which 'destroys' the stock.

Take another snapshot of the stock and ensure that the new products have been 'destroyed',
and the other 'transit' products status has not changed (is this right?).

Perform all the steps above twice:

1. Recode one product to many, via the Inventory page, clicking on the recode link
(only suitable if we're recoding exactly one SKU).

2. Recode many products to one, via the Recode page.

#TAGS iws inventory recode needsrefactor duplication whm

=head1 SEE ALSO

recode_mechanize_prl.t

=head1 TODO

Refactor this so it doesn't duplicate code and docs with recode_mechanize_prl.t

=cut

use NAP::policy qw( test );
use FindBin::libs;
use Test::XTracker::RunCondition iws_phase => 'iws';

use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XTracker::LocationMigration;
use Test::XTracker::Artifacts::RAVNI;
use Test::XT::Flow;
use Test::Differences;
use Test::XTracker::MessageQueue;
use Test::XTracker::PrintDocs;

use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw( :authorisation_level );


test_prefix('Setup');

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::WMS',
        'Test::XT::Flow::StockControl',
        'Test::XT::Flow::PrintStation',
        'Test::XT::Feature::Recodes',
    ],
);

my $channel = Test::XTracker::Data->channel_for_nap;
my $channel_id = $channel->id;

my $factory = $framework->wms_amq;
my $wms_monitor = $framework->wms_receipt_dir;
my $schema = $framework->schema;

my $transit_quantity = 13;
my $recode_out_quantity = 10;
my $recode_in_quantity = 17;

test_prefix('Recode - one to many');
my $products_4_transit_count = 1;
my $new_products_count = 2;
do_recode('inventory', $products_4_transit_count, $new_products_count);

$products_4_transit_count = 3;
$new_products_count = 1;
do_recode('recode', $products_4_transit_count, $new_products_count);

sub do_recode {

    # $path specifies the route to take for choosing products to recode
    my ($path, $products_4_transit_count, $new_products_count) = @_;

    my @new_products = Test::XTracker::Data->create_test_products({
        how_many => $new_products_count,
        channel_id => $channel_id,
        product_quantity => 0,
        storage_type_id => 1,
    });
    my %new_variants = map {
        $_->id, $_->variants->slice(0,0)->single
    } @new_products;

    my @transit_products = products_out_of_iws_into_transit({
        how_many => $products_4_transit_count,
        quantity => $transit_quantity
    });

    test_prefix("Recode - via $path - $products_4_transit_count to $new_products_count");
    $framework->login_with_permissions({
        dept => 'Stock Control',
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Stock Control/Recode',
            'Stock Control/Inventory',
        ] },
    });

    # A hack so we don't test the validation more than once... should look at
    # porting this whole test into Test::Class
    state $execute_validation_tests = 1;
    if ( $execute_validation_tests ) {
        $execute_validation_tests = 0;
        local $Test::More::Prefix::prefix = 'Validation - Cross-channel recode';

        $framework->flow_mech__select_printer_station({
            section    => 'StockControl',
            subsection => 'Recode',
            channel_id => $channel_id,
        })->flow_mech__select_printer_station_submit;

        if ($path eq 'inventory') {
            if ($products_4_transit_count != 1) {
                die "Can't go via inventory page unless we're recoding exactly one sku";
            }
            $framework->flow_mech__stockcontrol__inventory_overview_variant($transit_products[0]->{variant_id});
            $framework->flow_mech__stockcontrol__inventory_overview_variant_recode();
        } elsif ($path eq 'recode') {
            $framework->flow_mech__stockcontrol__recode;
            $framework->flow_mech__stockcontrol__recode_select_skus(map {$_->{sku}} @transit_products);
        }

        # Create products on another channel
        my $target_channel = Test::XTracker::Data->channel_for_out;
        my @target_channel_products = Test::XTracker::Data->create_test_products({
            channel_id => $target_channel->id,
            product_quantity => 0,
            storage_type_id => 1,
        });
        my $variant = $target_channel_products[0]->variants->slice(0,0)->single;

        $framework->errors_are_fatal(0);
        # Try to recode to SKUs on another channel
        $framework->flow_mech__stockcontrol__recode_submit({
            destroy => { map {
                $_->{sku}, $transit_quantity,
            } @transit_products },
            create => { $variant->sku => $recode_in_quantity },
        });
        $framework->mech->has_feedback_error_ok(
            (map {
                qr{$_}
            } sprintf( q{An error occurred while recoding: SKU %s can not be recoded as it is not on the expected channel: '%s'},
                $variant->sku, $channel->name
            )),
            'should not be able to recode SKUs from one channel to another',
        );

        local $Test::More::Prefix::prefix = 'Validation - Not enough stock';
        # Get back to the recoding form
        if ($path eq 'inventory') {
            if ($products_4_transit_count != 1) {
                die "Can't go via inventory page unless we're recoding exactly one sku";
            }
            $framework->flow_mech__stockcontrol__inventory_overview_variant($transit_products[0]->{variant_id});
            $framework->flow_mech__stockcontrol__inventory_overview_variant_recode();
        } elsif ($path eq 'recode') {
            $framework->flow_mech__stockcontrol__recode;
            $framework->flow_mech__stockcontrol__recode_select_skus(map {$_->{sku}} @transit_products);
        }

        # Try to destroy more than the available quantity
        $framework->flow_mech__stockcontrol__recode_submit({
            destroy => { map {
                $_->{sku}, $transit_quantity+1000,
            } @transit_products },
            create => { map {
                $new_variants{$_->id}->sku,
                    $recode_in_quantity,
                } @new_products },
        });
        # Check that we were given the correct error message
        like($framework->mech->app_error_message,
            qr{An error occurred while recoding: Not enough stock},
            'user informed that there is not enough stock');
        $framework->errors_are_fatal(1);
    }

    if ($path eq 'inventory') {
        if ($products_4_transit_count != 1) {
            die "Can't go via inventory page unless we're recoding exactly one sku";
        }
        $framework->flow_mech__stockcontrol__inventory_overview_variant($transit_products[0]->{variant_id});
        $framework->flow_mech__stockcontrol__inventory_overview_variant_recode();
    } elsif ($path eq 'recode') {
        $framework->flow_mech__stockcontrol__recode;
        $framework->flow_mech__stockcontrol__recode_select_skus(map {$_->{sku}} @transit_products);
    }

    {
    my $data=$framework->mech->as_data->{source};
    my %in_page = map {
        $_->{SKU}{value}, $_->{Quantity}
    } @$data;
    for my $in_prod (@transit_products) {
        cmp_ok($in_page{$in_prod->{sku}},
               '>=',
               $transit_quantity,
               'expected source products in page'
           );
    }
    }

    my @out_quantity_tests = map {
        Test::XTracker::LocationMigration->new( variant_id => $_->{variant_id} ),
    } @transit_products;
    my @in_quantity_tests = map {
        Test::XTracker::LocationMigration->new(
            variant_id =>
                $new_variants{$_->id}->id
            ),
    } @new_products;

    foreach my $test (@out_quantity_tests,@in_quantity_tests) {
        $test->snapshot('before recode');
    }

    # Prepare the monitor so we catch the message
    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

    my $print_directory = Test::XTracker::PrintDocs->new();

    # Destroy the stock with sensible values this time
    $framework->flow_mech__stockcontrol__recode_submit({
        destroy => { map {
            $_->{sku}, $recode_out_quantity,
        } @transit_products },
        create => { map {
            $new_variants{$_->id}->sku,
                $recode_in_quantity,
            } @new_products },
    });

    foreach my $test (@out_quantity_tests,@in_quantity_tests) {
        $test->snapshot('after recode submit');
    }

    foreach my $test (@out_quantity_tests) {
        $test->test_delta(
            from => 'before recode',
            to => 'after recode submit',
            stock_status => {
                'In transit from IWS' => -$recode_out_quantity,
            },
        );
    }

    foreach my $test (@in_quantity_tests) {
        $test->test_delta(
            from => 'before recode',
            to => 'after recode submit',
            stock_status => {
            }
        );
    }

    $framework->test_printing__recode_doc({
        print_directory => $print_directory,
        variants        => \%new_variants,
    });

    test_prefix('Recode putaway (no mechanize)');

    # Check that the messages were sent
    my @messages = map {
        +{
            type => 'pre_advice',
            details => {
                items => [
                    { skus => [ {
                        sku => $new_variants{$_->id}->sku,
                        quantity => $recode_in_quantity,
                    } ] }
                ],
                stock_status => 'main',
            }
        }
    } @new_products;

    my @messages_sent_to_iws = $xt_to_wms->expect_messages( {
        messages => \@messages,
    });


    # Use the message payload to send some fake messages.
    foreach my $message (@messages_sent_to_iws) {
        send_fake_iws_stock_received($message->{payload_parsed});
    }


    $_->snapshot('after recode putaway') for @out_quantity_tests,@in_quantity_tests;

    $_->test_delta(
        from => 'after recode submit',
        to => 'after recode putaway',
        stock_status => {
            'Main Stock' => $recode_in_quantity,
        },
    ) for @in_quantity_tests;
    $_->test_delta(
        from => 'after recode submit',
        to => 'after recode putaway',
        stock_status => {
        },
    ) for @out_quantity_tests;

}


done_testing;



=head2 send_fake_iws_stock_received

Emulate IWS sending fake stock_received based on the payload sent for pre-advice.

=over 4

=item $payload - Hash ref defining the payload

=back

=cut

sub send_fake_iws_stock_received {
    my ($pre_advice_payload) = @_;

    my ($pgid) = ( $pre_advice_payload->{pgid} =~ m/r-(\d+)/ );

    my $sr_rs = $schema->resultset('Public::StockRecode')->find($pgid);

    $factory->transform_and_send('XT::DC::Messaging::Producer::WMS::StockReceived',{
        operator => $schema->resultset('Public::Operator')->find( $APPLICATION_OPERATOR_ID ),
        sr => $sr_rs,
    });

    $wms_monitor->expect_messages( {
        messages => [ { 'type'   => 'stock_received' } ]
    } );
}

=head2 products_out_of_iws_into_transit

Move some products out of IWS into transit

=over 4

=item how_many

How many distinct products to take out of IWS into transit

=item quantity

Product count

=item channel_id

the channel to create products in

=item Return Value

C<@products>

=back

=cut

sub products_out_of_iws_into_transit {
    my ($args) = @_;

    test_prefix('Products to transit');

    my (undef, $pids) = Test::XTracker::Data->grab_products({
        how_many => $args->{how_many},
        channel_id => $args->{channel_id},
        ensure_stock_all_variants => 1,
    });

    my ($status,$reason) = ('main','stock out to xt');

    foreach my $transit_product (@$pids) {

        my ($sku, $product, $variant_id, $variant ) = @{$transit_product}{ qw( sku product variant_id variant ) };

        my $quantity_change = $args->{quantity};

        $factory->transform_and_send('XT::DC::Messaging::Producer::WMS::InventoryAdjust',{
            sku => $sku,
            quantity_change => -$quantity_change,
            reason => $reason,
            stock_status => $status,
        });

        $wms_monitor->expect_messages( {
            messages => [ {   type    => 'inventory_adjust',
                              details => { reason => $reason,
                                           sku => $sku,
                                           quantity_change => -$quantity_change
                                       }
                          } ]
        } );
    }

    # Return list of products sent into transit
    return @$pids;
}

