#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use XTracker::Config::Local qw( config_var );
use Test::XTracker::RunCondition export => ['$distribution_centre'];
use Test::XTracker::MessageQueue;
use Module::Pluggable::Object;

my $test = <<END;

WHM-33: http://jira4.nap/browse/WHM-33

1. Verify that time critical messages are allocated to x3 queues: Inventory
queue, Fulfilment queue, print queue (see notes for messages allocated per queue)
2. Verify that stock_change message includes stock_changed response

NB:
"inventory" queue
pre_advice
stock_change
pid_update
inventory_adjusted

"fulfilment" queue
shipment_request
shipment_cancel
shipment_reject
shipment_received
item_moved
shipment_packed
shipment_wms_pause
route_tote

"printing" queue
printing_done

END

sub short_name {
    return $_[0] =~ s{^XT::DC::Messaging::}{}r;
}

my @modules = Module::Pluggable::Object->new(
    search_path => 'XT::DC::Messaging::Producer::WMS',
    instantiate => 'new',
)->plugins;

my %logical_destinations =
    map {
        ( $_->type, config_var(short_name(ref($_)),'destination') // $_->destination )
    }
    @modules;

my %producer_clasess =
    map {
        ( $_->type, $_->meta->name )
    }
    @modules;

my $make_queue;
if ($distribution_centre eq 'DC1') {
    # IWS!
    $make_queue = sub { '/queue/dc1/iws_'.shift }
}
elsif ($distribution_centre eq 'DC2') {
    # ravni
    $make_queue = sub { '/queue/dc2/ravni_wms' }
}
elsif ($distribution_centre eq 'DC3') {
    # ravni
    $make_queue = sub { '/queue/dc3/ravni_wms' }
}
else {
    die "WTF? unknown DC $distribution_centre"
}

my $target_queue = '';

# Get the lines after NB that aren't blank
for my $line ( grep {$_} split(/\n/, (split(/NB:/, $test))[1]) ) {

    # Set the target queue
    if ( $line =~ m/"(.+)" queue/ ) {
        $target_queue = $make_queue->($1);

        note "Messages on the $line - [$target_queue]";

    } else {
        ok( $logical_destinations{ $line }, "Found logical destination for $line" ) || next;
        my $short_class = short_name($producer_clasess{$line});

        ok( $short_class, "Found producer class for $line ($short_class)" ) || next;

        my $map = config_var($short_class,'routes_map');
        my $mapped_destination =
            $map ? $map->{$logical_destinations{$line}}
                 : $logical_destinations{$line};

        is( $mapped_destination, $target_queue, "Target queue is correct" );
    }
}

done_testing();
