#!/usr/bin/env perl

# Gift Message Downloading script
#
# This script allows quick downloading of gift
# message images from the front-end, which is what
# XTracker does when the feature is enabled.
# It allows you to quickly check the front-end service
# is behaving as expected.

use strict;
use warnings;
no warnings "redefine";
use Getopt::Long;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Config::Local;
use XTracker::Database qw/schema_handle/;
use XTracker::Utilities 'url_encode';
use File::Slurp;

my $example_url = "http://whm.dave.net-a-porter.com/intl/voucherImageGenerator.nap?line-height=52&font-size=48&width=1024&height=768&text=__TEXT__";

sub usage {
    print "Usage:\n";
    print "[url=<frontend_target_url>] <shipment_id> [ shipment_item_id=<shipment_item_id> ] [raw_message_text=<raw_message_text>]\n\n";
    print "Examples:\n";
    print "    ./gift_message_downloader --shipment_id=129832\n";
    print "    ./gift_message_downloader --shipment_id=129832 --shipment_item_id=9832932\n";
    print "    ./gift_message_downloader --shipment_id=129832 --url=\"$example_url\" # any server you want\n";
    print "    ./gift_message_downloader --shipment_id=129832 --raw_message_text=\"check it\" # any message you want\n" ;
    print "    ./gift_message_downloader --shipment_id=129832 --raw_message_file=\"message.txt\"# easier for unicode and special chars\n";
    exit(1);
}

my $frontend_target_url;
my $shipment_id;
my $shipment_item_id;
my $raw_message_text;
my $raw_message_file;

GetOptions(
    'url=s' => \$frontend_target_url,
    'shipment_id=i' => \$shipment_id,
    'shipment_item_id=i' => \$shipment_item_id,
    'raw_message_text=s' => \$raw_message_text,
    'raw_message_file=s' => \$raw_message_file,
);

usage() if (!defined($shipment_id));

my $schema = schema_handle();

my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);

if (!defined($shipment)) {
    print "shipment not found (shipment_id=$shipment_id)\n";
    exit(2);
}

my $shipment_item;

if (defined($shipment_item_id)) {
    $shipment_item = $shipment->shipment_items->find($shipment_item_id);
    if (!defined($shipment_item)) {
        print "shipment_item not found (shipment_item_id=$shipment_item_id)\n";
        exit(3);
    }
}

my $gift_message_args = {
    shipment => $shipment,
};

$gift_message_args->{shipment_item} = $shipment_item if (defined($shipment_item));

my $gift_message_object = XTracker::Order::Printing::GiftMessage->new($gift_message_args);

# Make sure the file doesn't already exist because this prevents the download from happening
my $full_path = $gift_message_object->_get_absolute_image_filename();
unlink($full_path) if (-e $full_path);

# Support --url option in script by patching the gift message object
if (defined($frontend_target_url)) {
    ## no critic(ProtectPrivateVars)
    *XTracker::Order::Printing::GiftMessage::_get_image_generating_url = sub {
        my $self = shift;
        my $url = $frontend_target_url;
        my $enc_gm = url_encode($self->get_message_text());
        $url =~ s/__TEXT__/$enc_gm/;
        return $url;
    };
}

# Support for --raw_message_file by reading a file into the raw_message_text option
if (defined($raw_message_file)) {
    $raw_message_text = read_file($raw_message_file, binmode => ':utf8');
}

# Support for --raw_message_text option by patching get_message_text()
if (defined($raw_message_text)) {
    *XTracker::Order::Printing::GiftMessage::get_message_text = sub {
        return $raw_message_text;
    };
}

# Finally perform the action of downloading the file
$gift_message_object->get_image_path();
print "Image downloaded to: $full_path\n";

print "Script finished successfully\n";
exit(0);
