package Test::XTracker::Schema::ResultSet::Public::Channel;
use NAP::policy "tt", qw/test class/;

BEGIN {
    extends 'NAP::Test::Class';
};

sub test__find_by_name :Tests {
    my ($self) = @_;

    my $schema = $self->schema();
    $schema->txn_dont(sub {
        # Create a fake channel we can test with
        my $test_channel_id = $schema->resultset('Public::Channel')->create({
            name    => 'Todd-Y-Porter',
            business_id => $schema->resultset('Public::Business')->first->id(),
            distrib_centre_id => $schema->resultset('Public::DistribCentre')->first()->id(),
        })->id();

        is($schema->resultset('Public::Channel')->find_by_name('Todd-Y-Porter')->id(),
            $test_channel_id,
                'find_by_name() case sensitive returns correct channel when it should');

        ok(!$schema->resultset('Public::Channel')->find_by_name('ToDD-Y-porter'),
                'find_by_name() case sensitive returns nothing when it should');

        is($schema->resultset('Public::Channel')->find_by_name('ToDD-y-porter', {
                ignore_case => 1,
            })->id(),
            $test_channel_id,
                'find_by_name() case insensitive returns correct channel when it should');

    });
}
