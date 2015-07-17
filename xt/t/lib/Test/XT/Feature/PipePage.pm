package Test::XT::Feature::PipePage;

use NAP::policy "tt", qw (test role);

requires 'mech';

=head2 test_mech__pipe_page__test_items

Tests that the contents of a "Place In Packing Exception (tote)" page match
a specification:

 $framework
    ->test_mech__pipe_page__test_items(
        handled => [
          { SKU => '123456-789', QC => 'Ok', Container => 'T12345' }
        ],
        pending => [],
    );

The page itself passes items between "Pending" and "Handled" states, and this
method expects you to specify what you expect in each. Order is unimportant.
The key names correspond to the column names in the table on the page, but
the ones show in the example above are smart ones to test against.

=cut

sub test_mech__pipe_page__test_items {
    my ( $framework, %args ) = @_;

    ok( $framework->assert_location(qr!/Fulfilment/Packing/PlaceInPEtote!),
        "We're on the PIPE page" );
    note "Checking the PIPE page looks as we think it should";

    for my $type (qw/handled pending/) {
        next unless $args{ $type };
        note "Comparing $type items";

        my @expected_items = sort _pipe_page_item_sort @{ $args{ $type } };
        my @returned_items = sort _pipe_page_item_sort
            @{ $framework->mech->as_data->{"items_$type"} };

        is( scalar(@returned_items), scalar(@expected_items),
            "Found the right number of items of $type: " .  scalar(@returned_items))
                || next;

        next unless scalar(@expected_items);

        my $count = 0;
        for ( @expected_items ) {
            note "Comparing item " . ($count + 1);

            my $expected_item = $expected_items[ $count ];
            my $returned_item = $returned_items[ $count ];

            for my $key ( sort keys %{ $expected_item } ) {
                is( $returned_item->{$key}, $expected_item->{$key},
                    "$key matches"
                );
            }
        }
    }

    return $framework;
}

sub _pipe_page_item_sort {
    ( $a->{'SKU'}       || '' ) cmp ( $b->{'SKU'}       || '' ) ||
    ( $a->{'Container'} || '' ) cmp ( $b->{'Container'} || '' ) ||
    ( $a->{'QC'}        || '' ) cmp ( $b->{'QC'}        || '' )
}

1;
