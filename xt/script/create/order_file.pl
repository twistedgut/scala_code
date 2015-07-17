#!/opt/xt/xt-perl/bin/perl
use NAP::policy;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Config::Local qw/config_var/;
use Template;
use Getopt::Long;

my ($order_number, $channel, $shipping_sku, $address_1, $address_2, $address_3, $city,
    $county, $state, $postcode, $country_code);
GetOptions (
    "order_number=s"    => \$order_number,
    "channel=s"         => \$channel,
    "shipping_sku=s"    => \$shipping_sku,
    "address_1=s"       => \$address_1,
    "address_2=s"       => \$address_2,
    "address_3=s"       => \$address_3,
    "city=s"            => \$city,
    "county=s"          => \$county,
    "state=s"           => \$state,
    "postcode=s"        => \$postcode,
    "country_code=s"        => \$country_code,
);

die "An order number is required" unless $order_number;

$channel //= 'NAP-INTL';
$shipping_sku //= '900008-001';

my $order_date = DateTime->now();

my $order_file_name = "order_$order_number.xml";
my $template_path = config_var('SystemPaths', 'xtdc_base_dir') . '/root/base/order';
my $write_to_path = config_var('SystemPaths', 'xmparallel_dir') . '/31-EXPRESS/ready/' . $order_file_name;

print "Template at: $template_path\n";
print "Order file outputting to: $write_to_path\n";

my $output;
Template->new({
    INCLUDE_PATH    => $template_path,
})->process('order_xml.tt', {
    order_number    => $order_number,
    channel         => $channel,
    order_date      => $order_date->strftime('%F %H:%M'), # e.g 2014-09-25 16:05
    shipping_sku    => $shipping_sku,
    address_1       => $address_1,
    address_2       => $address_2,
    address_3       => $address_3,
    city            => $city,
    county          => $county,
    state           => $state,
    postcode        => $postcode,
    country_code    => $country_code,
}, $write_to_path) || die Template->error();

print "OK\n";
