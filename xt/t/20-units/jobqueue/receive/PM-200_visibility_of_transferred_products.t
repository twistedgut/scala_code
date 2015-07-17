#!/usr/bin/env perl

=head1 DESCRIPTION

Test for scenarios where product is set to transfer and visibility is set to true
for new channel. Website updates are now channelised.

The message that updates visibility is an XT::JQ::Receive::Product::Update.
That is the kind of message that this script creates.

The worker for this job will then create a number of Send::Product::WebUpdate
jobs to update the relevant Web DB(s). Those are the jobs that we are checking
for 'message as expected'. Because we can't tell the order of these jobs,
we read them into a hash and compare that hash of all channels with what we
expect.

=head1 SEE ALSO

L<http://jira4.nap/browse/PM-200>

=head1 AUTHOR

Pete Smith

=cut

use NAP::policy "tt", 'test';

use Test::XTracker::RunCondition database => 'full';
use Test::XTracker::Data;
use Test::XT::DC::JQ;

use XTracker::Constants                 qw{ :application };
use XTracker::Constants::FromDB         qw{ :product_channel_transfer_status };
use XTracker::Database::Product         qw( create_product_channel );
use XTracker::Database::ChannelTransfer qw( set_product_transfer_status );
use XTracker::Comms::DataTransfer       qw( set_xt_product_status );

use Test::Deep qw/cmp_deeply/;

BEGIN {
    use_ok("XT::JQ::DC::Receive::Product::Update");
}

my $jqt = Test::XT::DC::JQ->new;

# get a schema to query
my $schema = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema' );

my %channel;
for (qw(nap out)) {
    $channel{ $_ } = Test::XTracker::Data->channel_for_business(name => $_);
}



test_scenario(
    initial_channel     => 'nap',
    visibility_updates  => {nap => 1},
    expected            => {nap => {environment => 'live', visible => 1} },
);

test_scenario(
    initial_channel     => 'nap',
    visibility_updates  => {nap => 0},
    expected            => {nap => {environment => 'live', visible => 0} },
);

test_scenario(
    initial_channel     => 'nap',
    transfer_channel    => 'out',
    visibility_updates  => {out => 1},
    expected            => {},
);

test_scenario(
    initial_channel     => 'nap',
    transfer_channel    => 'out',
    visibility_updates  => {nap => 0, out => 1},
    expected            => {nap => {environment => 'live', visible => 0} },
);

test_scenario(
    initial_channel     => 'nap',
    transfer_channel    => 'out',
    set_transfer_live   => 1,
    visibility_updates  => {out => 1, nap => 0},
    expected            => {
        out => {environment => 'live',      visible => 1},
        nap => {environment => 'staging',   visible => 0},
    },
);

$jqt->queue->work_until_done;

done_testing();

sub test_scenario {
    my %args = @_;

    $jqt->clear_ok;

    note 'Testing scenario ' . p %args;

    # create PID
    my ($product) = Test::XTracker::Data->create_test_products({
        channel_id              => $channel{ $args{initial_channel} }->id,
        how_many                => 1,
        dont_ensure_stock       => 1,
        require_product_name    => 1,
    });

    if ($args{transfer_channel}) {
        # transfer product
        set_product_transfer_status(
            $schema->storage->dbh,
            {
                product_id  => $product->id,
                channel_id  => $channel{ $args{initial_channel} }->id,
                status_id   => $PRODUCT_CHANNEL_TRANSFER_STATUS__REQUESTED,
                operator_id => $APPLICATION_OPERATOR_ID,
            }
        );

        # create channel record on destination channel - if not exists
        create_product_channel(
            $schema->storage->dbh,
            {
                product_id  => $product->id,
                channel_id  => $channel{ $args{transfer_channel} }->id,
            }
        );

        if ($args{set_transfer_live}) {
            ## set status (live)
            set_xt_product_status( { dbh => $schema->storage->dbh, product_ids => $product->id, live => 1, channel_id => $channel{ $args{transfer_channel} }->id } );
            set_xt_product_status( { dbh => $schema->storage->dbh, product_ids => $product->id, live => 0, channel_id => $channel{ $args{initial_channel} }->id } );
        }
    }

    my @channel_updates = map { {
        channel_id  => $channel{ $_ }->id,
        visible     => $args{visibility_updates}->{ $_ },
    } } keys %{ $args{visibility_updates} };

    my $visibility_payload = [{
        product_id  => $product->id,
        operator_id => $APPLICATION_OPERATOR_ID,
        channel     => \@channel_updates,
    }];

    my $job = XT::JQ::DC->new( { funcname => 'Receive::Product::Update' });
    $job->set_payload( $visibility_payload );
    my $handle = $job->send_job;
    $jqt->process_job_ok( $handle );

    my $got = {};
    my $expected = {};

    # fix expected hash to use expected channel names and only enabled channels
    for (keys %{ $args{expected} }) {
        # the key should change to be the channel name and also
        # we should only expect it if the channel is enabled
        $expected->{ $channel{ $_ }->name }
            = $args{expected}->{ $_ } if $channel{$_}->is_enabled;
    }

    # Ensure that we don't compare numbers with strings.
    for (keys %{$expected}) {
        $expected->{ $_ }->{visible} = sprintf('%d', $expected->{$_}->{visible});
    }

    my $jobs = $jqt->get_jobs_rs;

    while (my $job = $jobs->next) {
        my $job_hash = $job->as_hash;

        $got->{ $job_hash->{payload}->{channel} } = {
            visible     => $job_hash->{payload}->{transfer_categories}->{pws_visibility}->{visible},
            environment => $job_hash->{payload}->{environment},
        };
    }

    cmp_deeply($got, $expected, 'Message as expected');
}

