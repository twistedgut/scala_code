#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use 5.012;
use Data::Dump qw/pp/;
use FindBin::libs;

use Test::XTracker::RunCondition
    database => 'full';


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

use Test::XTracker::Data;
use XTracker::Database qw/ get_schema_using_dbh /;

use List::Util 'shuffle';

# e.g.
# export ORDER_IMPORTER_REGRESSION_DIR=t/data/order_regression/
unless ($ENV{ORDER_IMPORTER_REGRESSION_DIR}) {
    plan skip_all => 'Regression tests for orders';
}

my $xml_dir = Path::Class::Dir->new($ENV{ORDER_IMPORTER_REGRESSION_DIR});

die "No such dir $ENV{ORDER_IMPORTER_REGRESSION_DIR}" unless -d $xml_dir;

my $mock_data = Test::XTracker::Mock::DHL::XMLRequest->new(
    data => [
        {service_code => 'LON'},
        {service_code => 'LON'},
    ]
);
my $xmlreq = Test::MockModule->new( 'XTracker::DHL::XMLRequest' );
$xmlreq->mock( send_xml_request => sub { $mock_data->xml } );

for my $child ( sort $xml_dir->children ) {
    next if $child->is_dir;
    next unless $child->basename =~ /\.xml$/;

    note 'Loading order file ' . $child;

    my $doc = XML::LibXML->load_xml(location => $child);

    my @orders = $doc->findnodes('/ORDERS /ORDER');
    my $index = 1;

    my $skip = 0;
    for my $order_tag (@orders) {
        $skip = 0;
        #set some values
        my $rand = rand;
        $rand = sprintf('%d', ($rand * 1234));
        my $order_number = sprintf('%d%d%d', $PROCESS_ID, time(), $index++);# . $rand;
        my $order_number2 = sprintf('%d%d%d', $PROCESS_ID, time(), $index++);# . $rand;

        #my %updates = (
            #O_ID                => $order_number,
            #ORDER_DATE          => DateTime->now(time_zone => 'local')->strftime('%Y-%m-%d %H:%M'),
            #LOGGED_IN_USERNAME  => 'test-orders@net-a-porter.com',
        #);

        my ( $order_a, $order_b );

        {
            my %updates = (
                O_ID                => $order_number,
                ORDER_DATE          => DateTime->now(time_zone => 'local')->strftime('%Y-%m-%d %H:%M'),
            );

            while (my($key, $value) = each %updates) {
                $order_tag->setAttribute($key => $value);
            }
            eval {
                # update PSP ref
                my $preauth_node = 'TENDER_LINE/PAYMENT_DETAILS/PRE_AUTH_CODE';
                my $node = $order_tag->find( $preauth_node );
                $node->get_node( 0 )->removeChildNodes;
                $node->get_node( 0 )->appendTextNode( $order_number );
            };
            if ( $@ ) {
                $skip = 1;
            }

            # prepare order file
            my $order_doc = XML::LibXML::Document->new('1.0', 'UTF-8');
            my $orders_node = $order_doc->createElement('ORDERS');
            $order_doc->setDocumentElement($orders_node);
            $orders_node->addChild($order_tag);

            # save xml file to incoming orders
            my $out_file = Path::Class::File->new(
                Test::XTracker::Data->pending_orders_dir,
                $order_number . '.xml',
            );

            # new order importer
            $order_doc->toFile($out_file);
            $order_b = import_order_new_way(
                file            => $out_file,
                order_number    => $order_number,
            );
        }

        {
            my %updates = (
                O_ID                => $order_number2,
                ORDER_DATE          => DateTime->now(time_zone => 'local')->strftime('%Y-%m-%d %H:%M'),
            );

            while (my($key, $value) = each %updates) {
                $order_tag->setAttribute($key => $value);
            }
            # update PSP ref
            eval {
                # update PSP ref
                my $preauth_node = 'TENDER_LINE/PAYMENT_DETAILS/PRE_AUTH_CODE';
                my $node = $order_tag->find( $preauth_node );
                $node->get_node( 0 )->removeChildNodes;
                $node->get_node( 0 )->appendTextNode( $order_number2 );
            };
            if ( $@ ) {
                $skip = 1;
            }
            # prepare order file
            my $order_doc = XML::LibXML::Document->new('1.0', 'UTF-8');
            my $orders_node = $order_doc->createElement('ORDERS');
            $order_doc->setDocumentElement($orders_node);
            $orders_node->addChild($order_tag);

            # save xml file to incoming orders
            my $out_file = Path::Class::File->new(
                Test::XTracker::Data->pending_orders_dir,
                $order_number2 . '.xml',
            );


            # old order importer
            $order_doc->toFile($out_file);
            $order_a = import_order_old_way(
                file            => $out_file,
                order_number    => $order_number2,
            );
        }

        Test::XTracker::Model->diff_orders($order_a, $order_b, {
            orders                      => [qw/ basket_nr order_nr use_external_tax_rate/],
            customer                    => [qw/ basket_nr order_nr /],
            shipments                   => [qw/ sla_cutoff shipment_address_id/],
            shipment_items              => [qw//],
            addresses                   => [qw//],
            tenders                     => [qw/voucher_code_id/],
            # shipment_item_pws_updates causes issues with rollback
            shipment_item_pws_updates   => 0,
        });
    }
    next if $skip;
#last;
}


sub import_order_new_way {
    my %args = @_;

    my $schema = Test::XTracker::Data->get_schema;

    my $order_xml  = XML::LibXML->load_xml(
        location => $args{file}->absolute,
    );

    my $order_hash;

    {
        my $guard = $schema->txn_scope_guard;

        XT::Order::Importer->import_orders({
            data    => $order_xml,
            schema  => $schema,
            skip    => 1,
        });

        my $order = Test::XTracker::Model->gimme_order({order_nr => $args{order_number}}, $schema);
        $order_hash = Test::XTracker::Model->order_to_hash($order);
    }

    return $order_hash;
}

sub import_order_old_way {
    my %args = @_;

    my $parser = XML::LibXML->new;
    $parser->validation(0);

    my $channels    = Test::XTracker::Data->get_schema->resultset('Public::Channel')->get_channels({fulfilment_only => 0});
    my $dbh_web     = Test::XTracker::Data->get_webdbhs;
    my $dbh         = Test::XTracker::Data->get_dbh;
    $dbh_web->{AutoCommit} = 0;
    $dbh->{AutoCommit} = 0;
    $dbh->{RaiseError} = 1;

    #$dbh->begin_work or die $dbh->errstr;

    # process the XML in a vacuum-of-silence
    my $import_error = XT::OrderImporter::process_order_xml(
        path        => $args{file},
        dbh         => $dbh,
        DC          => Test::XTracker::Data->whatami,
        dbh_web     => $dbh_web,
        parser      => $parser,
        channels    => $channels,
        skip_commit => 1,
    );

    if ($import_error) {
        $import_error=~m/, 2='(\d+)'/;
        ## no critic(ProhibitCaptureWithoutTest)
        Test::XTracker::Data->revert_broken_import(Test::XTracker::Data->get_schema, $1);
        die "Order importer failed to run and rollback attempted: $import_error";
    }

    my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    my $order = Test::XTracker::Model->gimme_order({order_nr => $args{order_number}}, $schema);
    my $order_hash = Test::XTracker::Model->order_to_hash($order);

    $dbh->rollback || die 'rollback failed';
    #$dbh->commit || die 'commit failed';

    XT::OrderImporter::archive(
        $args{file}->basename,
        Test::XTracker::Data->processed_order_dir,
        Test::XTracker::Data->pending_orders_dir
    );


    ok(!$import_error, 'Imported ' . $args{file}->basename . ' ok');

    Test::XTracker::Data->_release_order_importer_lock();

    return $order_hash;
}

done_testing();

