#!/usr/bin/env perl

use NAP::policy "tt", 'test';


use 5.012;
use Data::Dump qw/pp/;
use FindBin::libs;

use Test::MockModule;
use Test::XTracker::Data;
use Test::XTracker::Mock::DHL::XMLRequest;
use Test::XTracker::Mock::PSP;
use Test::XTracker::Model;
use Test::XTracker::Data::Order;
use Path::Class::Dir;
use Path::Class::File;
use XML::LibXML;
use English '-no_match_vars';
use DateTime;
use XT::Order::Parser;
use XT::Order::Importer;
use XT::Importer::FCPImport;

use Test::XTracker::Data;
use XTracker::Database qw/ get_schema_using_dbh /;
use XTracker::Config::Local qw( config_var );


# delete the orders directory
my $waitdir = config_var('SystemPaths', 'xmlwaiting_dir');
my $procdir  = XT::Importer::FCPImport::todays_subdir(config_var('SystemPaths', 'xmlproc_dir'));
my $errordir = XT::Importer::FCPImport::todays_subdir( config_var('SystemPaths', 'xmlproblem_dir'));

## WARNING: Make sure the O_IDs in the xmls are single digits otherwise the
## new ones are over 20 (the field size limit).
#unless ($ENV{REALLY_DELETE_ORDERS_FROM_IMPORT_DIR}) {
#      #plan skip_all => "Dangerous test of the order importer cron job - set REALLY_DELETE_ORDERS_FROM_IMPORT_DIR if you're sure you want to purge $waitdir, $procdir and $errordir";
#}

my $mock_data = Test::XTracker::Mock::DHL::XMLRequest->new(
    data => [
        {service_code => 'LON'},
        {service_code => 'LON'},
    ]
);
my $xmlreq = Test::MockModule->new( 'XTracker::DHL::XMLRequest' );
$xmlreq->mock( send_xml_request => sub { $mock_data->xml } );


sub purge_orders {
    mkdir $waitdir;
    mkdir $procdir;
    mkdir $errordir;
    unlink glob $waitdir.'/*';
    unlink glob $procdir.'/*';
    unlink glob $errordir.'/*';
}


# bug types:
## parsing - dies while parsing the file - just puts it in the error directory
## processing - a particular order from the file has a problem
##   in this case we also record the failed order in tmp/var/data/order_digest_failed.err

my @tests = (
    # bad currency fails parsing
    {
        file    => 't/data/order/bad_orders/parsing_problem-currency_XXX.xml',
        bug     => 'failed_parsing',
    },
    # duplicate O_ID fails processing
    {
        file    => 't/data/order/bad_orders/processing-duplicate_ordernum.xml',
        bug     => 'failed_processing',
    },
    # Shipments go on DDU hold if it's to a INTERNATIONAL_DDU country
    # and the customer hasn't accepted ddu terms
    {
        file    => 't/data/order/bad_orders/ddu_hold.xml',
        bug     => 'ddu_hold',
    },
);

foreach my $rh_test (@tests) {
    my $doc = XML::LibXML->load_xml(location => $rh_test->{file});
    my @orders = $doc->findnodes('/ORDERS /ORDER');


    # Append this suffix to the O_ID of each order in the file
    my $order_number_suffix = sprintf('%d%d', $PROCESS_ID, time());

    # prepare order file
    my $order_doc = XML::LibXML::Document->new('1.0', 'UTF-8');
    my $orders_node = $order_doc->createElement('ORDERS');
    my $new_order_filename = 'NOF';
    for my $order_tag (@orders) {
        purge_orders();

        # replace the PRE_AUTH_CODE with a new number
        ($order_tag->findnodes('TENDER_LINE/PAYMENT_DETAILS/PRE_AUTH_CODE/text()'))[0]->setData($order_number_suffix);

        # set some values
        my $original_order_number = $order_tag->getAttribute('O_ID');
        my $order_number = $original_order_number.$order_number_suffix;

        my %updates = (
            O_ID                => $order_number,
            ORDER_DATE          => DateTime->now(time_zone => 'local')->strftime('%Y-%m-%d %H:%M'),
            LOGGED_IN_USERNAME  => 'test-orders@net-a-porter.com',
        );

        while (my($key, $value) = each %updates) {
            $order_tag->setAttribute($key => $value);
        }

        $orders_node->addChild($order_tag);
        $new_order_filename .= '_'.$order_number;
    }

    $order_doc->setDocumentElement($orders_node);
    # save xml file to incoming orders
    my $out_file = Path::Class::File->new(
        $waitdir,
        $new_order_filename . '.xml',
    );
    $order_doc->toFile($out_file);

    XT::Importer::FCPImport::import_all_files();

    check_bug( {
        orders      => \@orders,
        bug         => $rh_test->{bug},
        filename    => $new_order_filename
    });
}

sub check_bug {

    my $rh_args = shift;

    if ($rh_args->{bug} =~ /^(failed_processing|failed_parsing)$/ ) {
    # the order file winds up in the $errordir
        my $out_errfile = Path::Class::File->new(
            $errordir,
            $rh_args->{filename} . '.xml',
        );
        # check that the input file has been stored in the error directory
        ok (-e $out_errfile, "The xml orders file $out_errfile is in the error directory");
    }

    ## FIXME IF it's a ddu_hold, check that it's on ddu hold

}


done_testing();


