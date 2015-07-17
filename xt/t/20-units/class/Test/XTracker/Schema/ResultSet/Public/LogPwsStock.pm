package Test::XTracker::Schema::ResultSet::Public::LogPwsStock;
use NAP::policy "tt", qw/class test/;

use Test::MockModule;
use Test::XTracker::Data;
use Test::Exception;
use XTracker::Constants::FromDB qw(
    :pws_action
);

BEGIN {
    extends 'NAP::Test::Class';
};

sub test__log_stock_change :Tests {
    my ($self) = @_;

    my ($channel, $product_data) = Test::XTracker::Data->grab_products({
        how_many => 1,
    });

    my $expected_variant_id = $product_data->[0]->{variant_id};
    my $expected_balance = 42;
    my $expected_quantity = 3;
    my $expected_action = $PWS_ACTION__ORDER;
    my $expected_notes = 'Some notes';

    my $mock_db_stock = Test::MockModule->new('XTracker::Database::Stock');
    $mock_db_stock->mock('get_total_pws_stock', sub { return {
        $expected_variant_id => { quantity => $expected_balance },
    } });

    my $new_log_id;

    ok($new_log_id = $self->schema->resultset('Public::LogPwsStock')->log_stock_change(
        variant_id      => $expected_variant_id,
        channel_id      => $channel->id(),
        pws_action_id   => $expected_action,
        quantity        => $expected_quantity,
        notes           => $expected_notes,
    ),'log_stock_change() returns an id value');

    my $new_log = $self->schema->resultset('Public::LogPwsStock')->find($new_log_id);
    is($new_log->variant_id(), $expected_variant_id, 'variant_id is as expected');
    is($new_log->channel_id(), $channel->id(), 'channel_id is as expected');
    is($new_log->pws_action_id(),$expected_action, 'action_id is as expected');
    is($new_log->quantity(), $expected_quantity, 'quantity is as expected');
    is($new_log->notes(), $expected_notes, 'notes are as expected');
    is($new_log->balance(), $expected_balance, 'balance is as expected');
}
