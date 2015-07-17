#!perl

## % with stickers, address cards, gift cards, any printing
## per hour during sale day and normal day
## no of flat, goh, other items in each

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw(:common);
use Text::CSV_XS;

my $csv = Text::CSV_XS->new({
        binary=>1,
});

open my $outfile, '>', '/tmp/sample_order_data.csv' or die "couldn't open file for writing";

my $dbh = get_database_handle({name=>'xtracker',type=>'readonly'});
my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');

my %skus;

my @day_shipments = fetch_shipments();
my @cols = ("SKU","Storage Type","Client","Weight (lbs)","Name");
$csv->combine(@cols);
print $outfile $csv->string()."\n";

foreach my $shipment (@day_shipments) {
    foreach my $shipment_item ($shipment->shipment_items()) {
        my $variant = $shipment_item->variant;
        next unless $variant;   
        my $sku = $variant->sku;
        next if ($skus{$sku});
        my @fields = ($sku);
        if ($variant->product && $variant->product->storage_type) {
            push @fields, $variant->product->storage_type->name;
        } else {
            push @fields, "Unknown";
        }
        if ($variant->product->get_product_channel->channel->name eq 'JIMMYCHOO.COM') {
            push @fields, "JC";
        } else {
            push @fields, "NAP";
        }
        push @fields, $variant->product->shipping_attribute->weight;
        push @fields, $variant->product->product_attribute->name;
        $csv->combine(@fields);
        print $outfile $csv->string()."\n";
        $skus{$sku} = 1;
    }
}

close $outfile;

sub fetch_shipments {

    my $shipment_rs = $schema->resultset('Public::Shipment')->search({
        date => [ -or =>
            [
                [ -and =>
                            {'>=' => '2011-11-16 00:00:00'},
                            {'<' => '2011-11-17 00:00:00'},
                ],
                [ -and =>
                            {'>=' => '2011-11-25 00:00:00'},
                            {'<' => '2011-11-26 00:00:00'},
                ]
            ]
        ],
    },{
        order_by => 'date',
    });


    return $shipment_rs->all();
}
