#!/opt/xt/xt-perl/bin/perl

=head1 NAME

import_csv_jc_quantity_into_xt.pl - import JC quantity rows from CSV file into XT

=head1 DESCRIPTION

The CSV file is generated from an export from JC DB and will have following columns:
variant_id, location_id, quantity, zero_date, channel_id, status_id #DISCARDED
sku,location,quantity,channel,allowed_status
should be comma separated file
zero_date not needed

=head1 SYNOPSIS

    perl import_csv_jc_quantity_into_xt.pl

    -help   (optional)
    -file   complete path of the quantity data file to be imported (required)
    -total  total messages to be sent before taking a break (required)
    -sleep  time in seconds to sleep before start sending next batch of messages (required)

=cut

use strict;
use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw/schema_handle/;
use XTracker::Config::Local;

use Pod::Usage;
use Text::CSV_XS;
use Getopt::Long;

use XTracker::Constants::FromDB ':storage_type';

local $|=1;

GetOptions ('file=s'  => \( my $import_file ),
            'total=i' => \( my $total_messages_before_sleep ),
            'sleep=i' => \( my $sleep ),
            'help|?'  => \( my $help )) or die("Error in command line arguments. Type -help for more options\n");

if ($help || ! $import_file || ! $sleep || ! $total_messages_before_sleep) {

    pod2usage(-verbose => 0);
    exit 1;
}

die "\nFile does not exist: $import_file\n\n" if (! -e $import_file);

my $schema        = schema_handle();
my $jc_channel_id = $schema->resultset('Public::Channel')->jimmy_choo->id;

my $csv = Text::CSV_XS->new ( { } );

my $iws_location_id = _get_iws_location_id();

my $flow_status = {'main' => 'Main Stock', 'dead' => 'Dead Stock'};

_delete_all_jc_rows($jc_channel_id);

my $total_messages_sent = 0;
open my $fh, "<:encoding(utf8)", $import_file or die "Cannot open file $import_file: $!\n";
my @cols = @{$csv->getline ($fh)};
$csv->column_names (@cols);
FILE : while ( my $row = $csv->getline_hr( $fh ) ) {

    # over writing all locations to IWS
    $row->{location_id} = $iws_location_id;
    $row->{variant_id}  = get_variant_id_from_sku( $row );
    $row->{channel_id}  = $jc_channel_id;
    $row->{status_id}   = get_status_id( $row );

    my $row_number = $csv->record_number();
    print "Starting row $row_number:\n";

    # insert and broadcast the data row
    try {
        my $guard = $schema->storage->txn_scope_guard;

        # if row already exist, update quantity
        my $quantity_updated = _check_jc_row_exists( $row );

        if (! $quantity_updated) {
            print "Inserting row in XT... variant: $row->{variant_id}, location: $row->{location_id}, status: $row->{status_id}\n";
            _insert_jc_row_in_xt( $row );
        }

        #print "Broadcasting...\n";
        #_broadcast_to_product_service( $row->{variant_id} );

        print "Finishing row $row_number\n";
        $guard->commit;

        ++$total_messages_sent;

        if ($total_messages_sent == $total_messages_before_sleep) {
            $total_messages_sent = 0;
            print "Batch sent, sleeping for $sleep seconds ...............\n";
            sleep($sleep);
        }
    } catch {
        die "Could not import JC data: $_\n";
    };
}
$csv->eof or $csv->error_diag();
close $fh;

print "------------ Process Complete ------------\n";


# get status id for main or dead stock
sub get_status_id {
    my ($row) = @_;

    my $status = $schema->resultset('Flow::Status')
                          ->search({ name => $flow_status->{$row->{allowed_status}} })->single;

    if ($status) {
        return $status->id;
    } else {
        print "ERROR: Cant find status id for flow status $flow_status->{$row->{allowed_status}}\n";
    }
}

# get variant id from product-size
sub get_variant_id_from_sku {
    my ($row) = @_;

    my ($product_id, $size_id) = split(/-/, $row->{sku});

    my $variant = $schema->resultset('Public::Variant')
                          ->search({ product_id => $product_id,
                                     size_id    => $size_id })->single;

    if ($variant) {
        return $variant->id;
    } else {
        print "ERROR: Cant find variant id for product $product_id and size $size_id\n";
    }
}

# get IWS location id
sub _get_iws_location_id {

    my $location = $schema->resultset('Public::Location')
                          ->search({ location => 'IWS' })->single;

    return $location->id;
}


# update storage type to FLAT (= 1) for each JC product
sub _update_product_storage_type {
    my ($quantity) = @_;

    $quantity->product_variant->product->update({ storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT });
}


# delete all jc rows
sub _delete_all_jc_rows {
    my ($jc_channel_id) = @_;

    my $quantity = $schema->resultset('Public::Quantity')
                          ->search({ channel_id  => $jc_channel_id });
                                     
    if ($quantity) {
        $quantity->delete;
        say "Deleting existing jc rows";
    }
}

# If row already exist in DB, update the quantity
sub _check_jc_row_exists {
    my ($row) = @_;

    my $quantity = $schema->resultset('Public::Quantity')
                          ->search({ variant_id  => $row->{variant_id},
                                     location_id => $row->{location_id},
                                     channel_id  => $row->{channel_id},
                                     status_id   => $row->{status_id}})->single;
    if ($quantity) {
        print "Updating quantity for this row: $row->{variant_id}, location: $row->{location_id}, status: $row->{status_id}\n";

        # updating quantity
        my $updated_quantity = $quantity->quantity + $row->{quantity};
        $quantity->quantity($updated_quantity);
        $quantity->update;

        return 1;
    }
    return 0;
}


# Broadcast JC quantity to product service for a variant
sub _broadcast_to_product_service {
    my ($variant_id) = @_;

    my $broadcast = XTracker::WebContent::StockManagement::Broadcast->new({
        schema     => $schema,
        channel_id => $jc_channel_id
    });

    $broadcast->stock_update( variant_id => $variant_id );
    $broadcast->commit();
}


# Insert JC quantity rows into XT from a CSV file
sub _insert_jc_row_in_xt {
    my ($row) = @_;

    my $quantity = $schema->resultset('Public::Quantity')->create({
        variant_id  => $row->{variant_id},
        location_id => $row->{location_id},
        quantity    => $row->{quantity},
        channel_id  => $row->{channel_id},
        status_id   => $row->{status_id}
    });

    print "Updating storage type to 'Flat' for JC products...\n";
    _update_product_storage_type($quantity);
}
