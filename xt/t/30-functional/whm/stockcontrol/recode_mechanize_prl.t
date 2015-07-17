#!/usr/bin/env perl

=head1 NAME

recode_mechanize_prl.t

=head1 DESCRIPTION

Create some new products.

Move some other products out of PRL into transit by sending InventoryAdjust messages.

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

3. Check the stock_recode rows are created, check they link to the correct
variant and have the correct quantity, and check the format of the notes field
is correct.

#TAGS prl inventory recode needsrefactor duplication whm

=head1 SEE ALSO

recode_mechanize_iws.t

=head1 TODO

Refactor this so it doesn't duplicate code and docs with recode_mechanize_iws.t

=cut

use NAP::policy qw( test );
use FindBin::libs;
use Test::XTracker::RunCondition prl_phase => 'prl';

use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XTracker::LocationMigration;

use Test::XT::Flow;
use Test::Differences;

use Test::XTracker::PrintDocs;

use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Config::Local;
use XTracker::Database 'xtracker_schema';
use XT::Domain::PRLs;

test_prefix('Setup');

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::PRL',
        'Test::XT::Flow::StockControl',
        'Test::XT::Flow::PrintStation',
        'Test::XT::Feature::Recodes',
    ],
);

my $channel = Test::XTracker::Data->channel_for_nap;

my $transit_quantity = 13;
my $recode_out_quantity = 10;
my $recode_in_quantity = 17;

my @prls = XT::Domain::PRLs::get_all_prls;
foreach my $prl (@prls) {

    note "Testing PRL: ", $prl->name;
    test_prefix('Recode - one to many');
    my $products_4_transit_count = 1;
    my $new_products_count = 2;
    do_recode($prl, 'inventory', $products_4_transit_count,
              $new_products_count);

    $products_4_transit_count = 3;
    $new_products_count = 1;
    do_recode($prl, 'recode', $products_4_transit_count,
              $new_products_count);

}

sub do_recode {

    # $path specifies the route to take for choosing products to recode
    my ($prl, $path, $products_4_transit_count, $new_products_count) = @_;

    my @new_products = Test::XTracker::Data->create_test_products({
        how_many => $new_products_count,
        channel_id => $channel->id,
        product_quantity => 0,
        storage_type_id => 1,
    });
    my %new_variants = map {
        $_->id, $_->variants->slice(0,0)->single
    } @new_products;

    my @transit_products = $framework->flow_msg__prl__products_into_transit ({
        how_many => $products_4_transit_count,
        quantity => $transit_quantity,
        channel => $channel,
        prl => $prl->amq_identifier,
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
            channel_id => $channel->id,
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

    my $print_directory = Test::XTracker::PrintDocs->new();

    # Get our latest id, so we can check what's been created since after the recode
    my $stock_recode_rs = xtracker_schema->resultset('Public::StockRecode');
    my $pre_recode_max_id = $stock_recode_rs->get_column('id')->max || 0;

    # Destroy the stock with sensible values this time
    $framework->flow_mech__stockcontrol__recode_submit({
        destroy => { map {
            $_->{sku}, $recode_out_quantity,
        } @transit_products },
        create => { map {
            $new_variants{$_->id}->sku, $recode_in_quantity,
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
                'In transit from PRL' => -$recode_out_quantity,
            },
        );
    }

    $framework->test_printing__recode_doc({
        print_directory => $print_directory,
        variants        => \%new_variants,
    });

    # Check that stock recode rows were created successfully
    my $stock_recodes = $stock_recode_rs->search(
        { id => { q{>} => $pre_recode_max_id } },
        { order_by => 'variant_id' }
    );
    is( $stock_recodes->count, @new_products,
        'all new products have stock recode rows' );
    for my $stock_recode ( $stock_recodes->all ) {
        test_stock_recode_row( $stock_recode, {
            variant_id => $new_variants{$stock_recode->variant->product_id}->id,
            quantity   => $recode_in_quantity
        });
    }

    # We stop here, the putaway prep recode tests start from this point.
}

done_testing;

# Test the stock recode row is correct. Pass it a hash of expected values
# that match the column names. The 'notes' column just gets tested for its
# formatting, not the actual values.
sub test_stock_recode_row {
    my ( $stock_recode, $expected ) = @_;

    is( $stock_recode->$_, $expected->{$_}, "stock recode row has correct $_" )
        for keys %$expected;
    # Just check the format here, not the actual values - should be good enough
    like( $stock_recode->notes,
        qr{Recode:\sto\s
        (?:                 # Group 'SKU(quantity), '
            (?:             # Group 'SKU(quantity)'
                \d+-\d+     # Match SKU
                \(\d+\)     # Match '(quantity)'
            )
            (?:,\s)?        # Optionally match ', ' delimiter
        )+                  # Must have at least one SKU(quantity)
        \sfrom\s
        (?:
            (?:\d+-\d+\(\d+\))(?:,\s)? # This matches the above
        )+\.
        }xms,
        'stock recode row has correct notes format'
    );
}
