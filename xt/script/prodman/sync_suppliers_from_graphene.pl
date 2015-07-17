#!/opt/xt/xt-perl/bin/perl

=head1 NAME

    sync_suppliers_from_graphene.pl

=head1 SYNOPSIS

    This script gets all suppliers in Graphene, compares them with
    the local XT database and creates new ones if appropriate

=head1 USAGE

    sudo perl -I/opt/xt/deploy/xtracker/lib -I/opt/xt/deploy/xtracker/lib_dynamic sync_suppliers_from_graphene.pl

=head1 AUTHOR

    Nelio Nunes - L<nelio.nunes@net-a-porter.com>

=cut

use NAP::policy;
use XTracker::Database 'xtracker_schema';
use HTTP::Status qw/ :constants/;
use REST::Client;
use JSON;
use List::Util 'pairs';
use Data::Dump "pp";
my $graphene_host = "http://graphene.wtf.nap";
my $graphene_url = "/suppliers";
my $client = REST::Client->new();
use Log::Log4perl ':easy';
Log::Log4perl->easy_init({ level => $INFO });

INFO "Execution started";
$client->setHost($graphene_host);
$client->GET(
    $graphene_url,
    {Accept => 'application/json'}
);

INFO "GRAPHENE URL is ".$graphene_host.$graphene_url;

unless ( $client->responseCode == HTTP_OK ) {
    die(sprintf(
            "ERROR: Invalid response %d from Graphene client, exiting now",
            $client->responseCode() )
    );
}

my $response = from_json($client->responseContent());

my %suppliers = map { $_->{code} => $_->{name} } @{from_json($client->responseContent)};

INFO scalar(keys(%suppliers))." suppliers in graphene";

my @existing_codes = xtracker_schema->resultset('Public::Supplier')->get_column('code')->all;
delete @suppliers{@existing_codes};

INFO scalar(@existing_codes)." existing suppliers in XT";
INFO scalar(keys(%suppliers))." suppliers to insert";
if (%suppliers){
	INFO pp pairs %suppliers;
}

# The remaining suppliers on the hash need to be inserted
xtracker_schema->resultset('Public::Supplier')->populate([
    [qw(code description)],
    pairs %suppliers
]);

INFO "All done";
