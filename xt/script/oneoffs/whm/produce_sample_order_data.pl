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
my @storage_types = ("Dematic_Flat", "Flat","Hanging","Oversized","Awkward","Cage","Unknown");
my @document_types = ("Address Card","Gift Card","MrP Sticker");
my @cols = ("Shipment ID","Datetime",@storage_types,"Item count",@document_types);
$csv->combine(@cols);
print $outfile $csv->string()."\n";

foreach my $shipment (@day_shipments) {
    my %document_types;
    my @doctypes = $shipment->list_picking_print_docs(2);   # as if we were in phase 2
    while (my $doc = shift @doctypes) {
        $document_types{$doc} = 1;
    }
    if ($shipment->gift_message()) {
        $document_types{"Gift Card"} = 1;
    }
    my %storage_types;
    foreach my $shipment_item ($shipment->shipment_items()) {
        my $variant = $shipment_item->variant;
        next unless $variant;   
        if ($variant->product && $variant->product->storage_type) {
            $storage_types{$variant->product->storage_type->name}++;
        } else {
            $storage_types{'Unknown'}++;
        }
    }
    my @fields = ($shipment->id, $shipment->date);
    push @fields, map {$storage_types{$_}} @storage_types;
    push @fields, $shipment->shipment_items->count;
    push @fields, map {$document_types{$_}} @document_types;
    $csv->combine(@fields);
    print $outfile $csv->string()."\n";
}

close $outfile;

sub fetch_shipments {

    my $shipment_rs = $schema->resultset('Public::Shipment')->search({
        date => [ -and =>
                    {'>=' => '2011-11-10 00:00:00'},
                    {'<' => '2011-11-17 00:00:00'},
        ],
    },{
        order_by => 'date',
    });


    return $shipment_rs->all();
}
