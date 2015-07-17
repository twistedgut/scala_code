#!/opt/xt/xt-perl/bin/perl
#
# this script creates a flood of orders, and sprays them into the
# xmlwaiting directory of the poor, poor XT box that has to cope with it
#

use NAP::policy "tt";

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use Test::XTracker::Data;
use XTracker::Utilities qw( :string );

use XTracker::Config::Local;
use XTracker::Database qw/get_database_handle/;
use XT::Importer::FCPImport qw( :xml_filename );

use Data::Printer;

use DateTime;
use DateTime::Format::Strptime;

my $template_dir = config_var( 'SystemPaths', 'xtdc_base_dir' )."t/data/order_importer/templates";
my $xt_instance = config_var( 'XTracker', 'instance');

# we generate lots of orders with variability around:
#  channel
#  number of products
#  shipping destination
#  shipping options
#  customer status
#

my $variables = {
    brands => [ qw( NAP MRP OUTNET ) ],
    destinations => [
                      { name => 'Premier', },
                      { name => 'UK Standard', },
                      { name => 'Europe', },
                      { name => 'US Standard', },
                      { name => 'Asia pacific', }
                    ],
    customers => [
                   { type => 'regular', },
                   { type => 'board member', },
                   { type => 'staff', },
                   { type => 'eip', }
                 ],
};

my $orders_xml_header = qq{<?xml version="1.0" encoding="UTF-8"?>\n<ORDERS>\n};
my $orders_xml_footer = qq{</ORDERS>\n};

my $tt_flood_dir = config_var('SystemPaths','template_flood_dir');
my $orders_xml_body_tt_path = "$tt_flood_dir/order.xml.tt";

open ( my $tt_fd, '<:encoding(utf8)', $orders_xml_body_tt_path)
    or die "Cannot open orders XML TT file '$orders_xml_body_tt_path' for reading\n";

my $orders_xml_body_tt;

eval {
    local $/ = undef;
    $orders_xml_body_tt = <$tt_fd>;
    close $tt_fd;
};

if (my $e = $@) {
    die "Unable to read XML body template: $e\n";
}


my $tax_rate = 0.1;

my @products_per_order = ( ( 1 ) x 6,
                           ( 2 ) x 4,
                           ( 3 ) x 3,
                           4, 5, 7, 8,
                           10, 11, 13
                         );

my $max_orders_per_file = 23;
my $max_price = 2979;

my $output_dir =       $ARGV[0] || '.';
my $order_file_count = $ARGV[1] || 100;

die "Order file count must be a positive integer\n"
    unless $order_file_count =~ m{^\d+$};

die "Order file count must not be ridiculously large\n"
    if $order_file_count > 5000;

die "Output directory does not exist '$output_dir'\n"
    unless -d $output_dir;

die "Cannot write in output directory '$output_dir'\n"
    unless -w $output_dir;

# start with clock n seconds in the past, where 'n' is
# the number of files we're going to create
my $datetime = DateTime->now( time_zone => 'UTC' )
                       ->subtract( seconds => $order_file_count );


my $yyjjj_formatter      = DateTime::Format::Strptime->new(pattern => q{%y%j});
my $epochsecs_formatter  = DateTime::Format::Strptime->new(pattern => q{%s});

my $now = DateTime->now;

$now->set_formatter( $yyjjj_formatter );

my $day = "$now";

my $epochsecs = $now->set_formatter( $epochsecs_formatter );

my $secs = "$epochsecs" % 86400;

my $order_id = "$day$secs";

ORDER_FILE:
foreach my $of_num (1..$order_file_count) {
    my $brand       = pick( @{$variables->{brands}} );

    my $channel = "$brand-$xt_instance";

    my @orders = ();

  ORDER:
    my $order_count = int(rand $max_orders_per_file)+1;

    foreach my $o_num (1..$order_count) {
        my $destination  = pick( @{$variables->{destinations}} );
        my $customer     = pick( @{$variables->{customers}} );
        my $num_products = pick( @products_per_order );

        my $pids;

        my $channel_for_business = Test::XTracker::Data->channel_for_business(
            name => uc $brand
        );

        eval {
            $pids = Test::XTracker::Data->find_or_create_products(
                { channel_id => $channel_for_business->id,
                  how_many => $num_products,
                  ensure_stock => 1,
                  with_delivery => 1,
                  require_product_name => 1
                }
            );
        };

        if (my $e = $@) {
            warn "Unable to get products: $e\n";
            next ORDER;
        }

        # coming soon...
        my ($billing_address, $destination_address)
            = ('Billing address', 'Destination address');

        my $products = [
            map {
                my $product = $_->{product};
                my $variant = $_->{variant};

                my $price = rand $max_price;
                my $tax = $price * $tax_rate;

                { unit_price => sprintf('%0.02f', $price),
                  tax => sprintf('%0.02f', $tax),
                  duty => '0.00',
                  description => flatten( $product->product_attribute->description ),
                  sku => $_->{sku},
                  quantity => 1,
                };
            }
            @$pids
        ];

        my $delivery_total = 20;
        my $delivery_tax = $delivery_total * $tax_rate;

        my $gross_total = $delivery_total+$delivery_tax;

        foreach ( @$products ) {
            $gross_total += $_->{unit_price} + $_->{tax} + $_->{duty};
        }

        my $order_data = {
            order_id         => $order_id++,
            order_date       => $datetime->ymd('-').' '.$datetime->hms(':'),
            billing_address  => $billing_address,
            shipping_address => $destination_address,
            products         => $products,
            channel          => $channel,
            delivery_total   => sprintf('%0.02f',$delivery_total),
            delivery_tax     => sprintf('%0.02f',$delivery_tax),
            gross_total      => sprintf('%0.02f',$gross_total),
            currency         => rand 2 > 1 ? 'GBP' : 'EUR'
        };

        my $orders_xml_body = '';

        my $tt = Template->new();

        eval {
            $tt->process(
                \$orders_xml_body_tt,
                $order_data,
                \$orders_xml_body
            );
        };

        if (my $e = $@) {
            warn "Unable to create order body: $e\n";

            next ORDER;
        }

        push @orders,$orders_xml_body;
    }

    if (@orders) {
        my $filename = make_xml_filename( $channel, $datetime );

        # bump timestamp portion of filename by one second to
        # make sure generated files won't clash with each other
        $datetime->add( seconds => 1 );

        eval {
            open ( my $xml_fd, '>:encoding(utf8)', "$output_dir/$filename" );

            print $xml_fd $orders_xml_header,
                          @orders,
                          $orders_xml_footer;

            close $xml_fd;
        };

        if ( my $e = $@) {
            die "Unable to write order XML file '$output_dir/$filename'\n";
        }
    }
}

sub pick { return $_[rand @_]; }

