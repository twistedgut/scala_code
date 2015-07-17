#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use JSON;
use XML::LibXML;

use Test::XTracker::Data;

BEGIN { use_ok( 'XT::Order::Parser' ); }
require_ok( 'XT::Order::Parser' );

my $schema =  Test::XTracker::Data->get_schema();


{
    my $dom = XML::LibXML->load_xml(string => '<order>foo</order>');
    my $parser = XT::Order::Parser->new_parser({
        schema => $schema,
        data => $dom
    });
    isa_ok( $parser, 'XT::Order::Parser::PublicWebsiteXML' );
}

{
    my $json = { orders => 'foo', merchant_url => 'www.jimmychoo.com' };
    my $parser = XT::Order::Parser->new_parser({
        schema => $schema,
        data => $json
    });
    isa_ok( $parser, 'XT::Order::Parser::IntegrationServiceJSON' );
}

done_testing;
