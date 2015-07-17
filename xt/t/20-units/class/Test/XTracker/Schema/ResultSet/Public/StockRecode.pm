package Test::XTracker::Schema::ResultSet::Public::StockRecode;

use NAP::policy "tt", 'test';

use FindBin::libs;
use parent 'NAP::Test::Class';

use Test::More;

use Test::XT::Data::Recode;

sub test_putaway_prep_process_groups : Tests {
    my ($self) = @_;

    note "Create test recode";
    my $recode     = Test::XT::Data::Recode->create_recode();
    my $recode_rs  = $self->schema->resultset('Public::StockRecode');

    note "Check recode groups returned by putaway_prep_process_groups";
    my $group_rows_by_channel = $recode_rs->putaway_prep_process_groups;
    my $channel_name = $recode->variant->product->get_product_channel->channel->name;

    ok ($group_rows_by_channel->{$channel_name}, "Rows returned for channel $channel_name");

    my $recode_row = $group_rows_by_channel->{$channel_name}->{$recode->id};
    ok ($recode_row, "Row returned for this recode in this channel");

    is ($recode_row->{sku}, $recode->variant->sku, "Correct SKU shown");
    is ($recode_row->{quantity}, $recode->quantity, "Correct quantity shown");

    my $rows_including_test_recode = scalar keys %{$group_rows_by_channel->{$channel_name}};
    note "$rows_including_test_recode recode(s) shown for $channel_name";

    note "Complete the recode";
    $recode->update({
        complete => 1,
    });

    note "Get new list of groups";
    $group_rows_by_channel = $recode_rs->putaway_prep_process_groups;
    if ($rows_including_test_recode > 1) { # Our test recode wasn't the only one
        # It should've decreased by one
        is (scalar keys %{$group_rows_by_channel->{$channel_name}}, $rows_including_test_recode - 1,
            "One fewer row returned for $channel_name");
        is ($group_rows_by_channel->{$channel_name}->{$recode->id}, undef,
            "Row for this recode has gone");
    } else { # Our test recode was the only one
        # The channel should be gone completely now
        is ($group_rows_by_channel->{$channel_name}, undef, "No rows returned for $channel_name");
    }
}

1;
