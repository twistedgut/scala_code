#!/opt/xt/xt-perl/bin/perl

use NAP::policy 'test';

use FindBin::libs;
use Set::Object;

use XTracker::Database 'xtracker_schema';

my $schema = xtracker_schema();

# I thought it'd be useful to identify where in our schema we have sources
# whose relationship and column accessors clash, and to make sure we don't
# increase this list (when we should be decreasing it). So here's a test to
# enforce us making sure our DBIC sources are more resilient.

# Legacy sources that we need to fix, but don't want to break the test suite
# for
my %source_clash_todo = (
    'Promotion::CustomerCustomerGroup' => [ qw/created modified/ ],
    'Promotion::Detail'                => [ qw/created_by last_modified_by target_currency/ ],
    'Public::AddressChangeLog'         => [ qw/change_from change_to/ ],
    'Public::LogDesignerDescription'   => [ qw/designer_id/ ],
    'Public::OrderAddressLog'          => [ qw/changed_from changed_to/ ],
    'Public::PutawayPrepContainer'     => [ qw/destination/ ],
    'Public::ReturnDelivery'           => [ qw/created_by/ ],
    'Public::SalesConversionRate'      => [ qw/destination_currency source_currency/ ],
    'Public::ShipmentAddressLog'       => [ qw/changed_from changed_to/ ],
    'Voucher::PurchaseOrder'           => [ qw/created_by/ ],
);

for my $source ( map { $schema->source($_) } sort $schema->sources ) {
    subtest sprintf('test %s for naming clashes', $source->source_name) => sub {
        my @columns = $source->columns;
        my @relationships = $source->relationships;

        my $duplicates
            = Set::Object->new(@columns) * Set::Object->new(@relationships);

        my $todos_expected
            = Set::Object->new(@{delete $source_clash_todo{$source->source_name}//[]});

        my $failures     = $duplicates     - $todos_expected;
        my $todos_passed = $todos_expected - $duplicates;
        my $todos        = $duplicates     * $todos_expected;

        # Mark tests as todo failures if they fail
        TODO: {
            local $TODO = 'Legacy failure - fix me!';
            fail( "$_ has a column and a relationship accessor" ) for sort @$todos;
        }
        # Trigger a failure if we pass any todos so we clear them up once
        # they're fixed
        fail( join q{ },
            "$_ was a todo - it's been fixed!",
            "This is good, remove it from the list of expected failures"
        ) for sort @$todos_passed;

        # Deal with failures
        my @failures = @$failures;
        fail( "$_ has a column and a relationship accessor" ) for sort @failures;
        pass( 'no unexpected column/relationship clashes' ) unless @failures;
    };
}

fail("Inexistent source $_ in expected failures - remove")
    for sort keys %source_clash_todo;

done_testing;
