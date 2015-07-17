#!/usr/bin/perl
use NAP::policy "tt",     'test';

=head2 Pre-Order Item tests

checks:
    'order_by_sku' method returns correct resultset
    'product_details_for_email' method returns correct Product name

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;

use XTracker::Constants             qw( :application );
use XTracker::Database              qw( get_database_handle );


# get a schema, sanity check
my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");


#----------------------------------------------------------
_test_pre_order_item( $schema, 1 );
#----------------------------------------------------------

done_testing();

sub _test_pre_order_item {
    my ( $schema, $oktodo ) = @_;

    SKIP: {
        skip '_test_pre_order_item', 1     if ( !$oktodo );

        note "TESTING pre_order_item";

        $schema->txn_do( sub {
            my $pre_order       = Test::XTracker::Data::PreOrder->create_complete_pre_order;
            my $channel         = $pre_order->customer->channel;
            # ordering records purposely so that to get in different sort order.
            my @pre_order_items = $pre_order->pre_order_items->search( undef, { order_by => { -desc => 'id' } } )->all;
            my @sorted          = ();

            note "Testing resultset 'order_by_sku' method";
            foreach my $item ( @pre_order_items ) {
                push @sorted, {
                    item_id  => $item->id,
                    sort_by  => [ $item->variant->product_id, $item->variant->size_id ],
                };
            }

            # order by product_id and by size_id
            my @sorted_list = sort { $a->{sort_by}[0] <=> $b->{sort_by}[0] || $a->{sort_by}[1] <=> $b->{sort_by}[1] } @sorted;

            @sorted = $pre_order->pre_order_items->order_by_sku->all;
            foreach( 0..$#sorted ) {
                my $got_id  = $sorted[$_]->id;
                my $expected_id = shift (@sorted_list)->{item_id};

                is( $got_id, $expected_id,"'order_by_sku' method works for pre_order_id = ". $got_id );
            }

            note "Testing 'product_details_for_email' method";
            # set the names of all the Products
            foreach my $item ( @pre_order_items ) {
                my $product = $item->variant->product;
                $product->product_attribute->name( 'Name - ' . $product->id );
                $product->product_attribute->description( 'Description - ' . $product->id );
            }

            # get the Product Details for each of the Items
            my @product_details = map { $_->product_details_for_email } @pre_order_items;
            my @expected        = map {
                {
                    product_id      => $_->variant->product_id,
                    name            => $_->variant->product->preorder_name,
                    designer_name   => $_->variant->product->designer->designer,
                    original_name   => $_->variant->product->preorder_name,
                    name_for_tt     => ignore(),
                }
            } @pre_order_items;

            cmp_deeply( \@product_details, \@expected,
                            "Called 'product_details_for_email' and got expected Results" );

            note "testing 'name_fot_tt' sub which is within the Product Detail Hash, on all Items";
            foreach my $idx ( 0..$#pre_order_items ) {
                my $item    = $pre_order_items[ $idx ];
                my $detail  = $product_details[ $idx ];

                my $product = $item->variant->product;
                my $designer= $product->designer;

                note "for Item: " . $item->id . ", PID: " . $product->id;
                is( $detail->{name_for_tt}(), $item->name,
                    "when 'name' eq 'original_name', 'name_for_tt()' returns 'name': '" . $detail->{name_for_tt}() . "'" );

                $detail->{name} = 'New Name - ' . $product->id;
                is( $detail->{name_for_tt}(), $designer->designer . ' - ' . $detail->{name},
                    "when 'name' ne 'original_name', 'name_for_tt()' returns 'designer_name - name': '" . $detail->{name_for_tt}() . "'" );

                $detail->{designer_name} = '';
                is( $detail->{name_for_tt}(), $detail->{name},
                    "when 'name' ne 'original_name' and 'desginer' is empty, 'name_for_tt()' returns 'name': '" . $detail->{name_for_tt}() . "'" );

                $detail->{designer_name}= $designer->designer;
                $detail->{name}         = '';
                is( $detail->{name_for_tt}(), $detail->{original_name},
                    "when 'name' ne 'original_name' and 'name' is empty, 'name_for_tt()' returns 'original_name': '" . $detail->{name_for_tt}() . "'" );
            }


            # rollback any changes
            $schema->txn_rollback();
        } );
    };

    return;
}

1;
