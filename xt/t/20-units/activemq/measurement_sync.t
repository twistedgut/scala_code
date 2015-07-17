#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use JSON::XS ();
use XTracker::Config::Local qw/config_var/;

my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app();
my $schema = Test::XTracker::Data->get_schema;

my $mesg_type = 'XT::DC::Messaging::Producer::Sync::VariantMeasurement';
my $destination = config_var('Producer::Sync::VariantMeasurement', 'destination');
my $consume_destination = XT::DC::Messaging->config
    ->{'Consumer::VMSync'}{routes_map}{destination};

my $product_type = $schema->resultset('Public::ProductType')->search({
    product_type => 'Coats'
})->single;

my ($channel,$pids) = Test::XTracker::Data->grab_products({
    product_type_id => $product_type->id
});

my $variant = $pids->[0]{variant};
my $product = $pids->[0]{product};


my @measurements = $product->product_type->search_related(
    'product_type_measurements',{
        channel_id => $channel->id,
    })->all;
my $skip_id = $measurements[0]->measurement_id;
my @variant_measurements;

for my $m (@measurements) {
    if ($m->measurement_id == $skip_id) {
        push @variant_measurements,$m;
        $schema->resultset('Public::VariantMeasurement')
            ->search({
                variant_id => $variant->id,
                measurement_id => $m->measurement_id,
            })->delete;
    }
    else {
        push @variant_measurements,
            $schema->resultset('Public::VariantMeasurement')
                ->update_or_create({
                    variant_id => $variant->id,
                    measurement_id => $m->measurement_id,
                    value => 100+$m->measurement_id,
                });
    }
    if ($m->measurement_id % 2) {
        $product->show_measurement($m->measurement_id);
    }
    else {
        $product->hide_measurement($m->measurement_id);
    }
}

$amq->clear_destination($destination);

lives_ok {
    $amq->transform_and_send(
        $mesg_type,
        {
            variants => [ $variant->id ],
            schema => $schema,
        }
    );
}
    "Can send valid message";

my @messages = $amq->assert_messages({
    destination => $destination,
    filter_header => superhashof({
        type => 'vmsync',
    }),
    filter_body => superhashof({
        variant_id => $variant->id,
    }),
    assert_header => superhashof({
        JMSXGroupID => $product->id,
    }),
    assert_body => superhashof({
        product_id => $variant->product_id,
        variant_id => $variant->id,
        measurements => bag(
            map { +{
                measurement_id => $_->measurement_id,
                measurement_name => $_->measurement->measurement,
                ( $_->measurement_id == $skip_id
                      ? ( value => '' )
                          : ( value => $_->value ) ),
                visible => ( $_->measurement_id % 2 ? JSON::XS::true : JSON::XS::false ),
            } } @variant_measurements,
        ),
    }),
}, 'Message sent');

my ($msg) = $amq->messages($destination);
$msg = $amq->deserializer->($msg->body);

my $updated_id = $msg->{measurements}[0]{measurement_id};
my $updated_value = $msg->{measurements}[0]{value} = 90;
my $updated_vis = $msg->{measurements}[0]{visible} =
    ( $updated_id % 2 ? JSON::XS::false : JSON::XS::true ); #opposite

my $deleted_id = $msg->{measurements}[1]{measurement_id};
$msg->{measurements}[1]{value}=''; # remove the value
my $deleted_vis = $msg->{measurements}[1]{visible} =
    ( $deleted_id % 2 ? JSON::XS::false : JSON::XS::true ); #opposite

my $res = $amq->request(
    $app,
    $consume_destination,
    $msg,
    { type => 'vmsync' }
);
ok( $res->is_success, 'update consumed' );

my $new_m = $schema->resultset('Public::VariantMeasurement')->search({
    variant_id => $variant->id,
    measurement_id => $updated_id
})->single;
my $vis_count = $schema->resultset('Public::ShowMeasurement')->count({
    product_id => $product->id,
    measurement_id => $updated_id
});
is($new_m->value,$updated_value,'value stored');
is($vis_count,
   ($updated_vis ? 1 : 0),
   'visibility stored');

my $deleted_count = $schema->resultset('Public::VariantMeasurement')->search({
    variant_id => $variant->id,
    measurement_id => $deleted_id,
})->count;
is($deleted_count,0,'deleted measurement');
$vis_count = $schema->resultset('Public::ShowMeasurement')->count({
    product_id => $product->id,
    measurement_id => $deleted_id
});
is($vis_count,
   ($deleted_vis ? 1 : 0),
   'visibility stored for deleted value');

done_testing;
