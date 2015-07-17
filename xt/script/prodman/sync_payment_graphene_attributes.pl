#!/opt/xt/xt-perl/bin/perl

=head1 NAME

    sync_payment_graphene_attributes.pl

=head1 SYNOPSIS

    This script gets all settlement discounts and payment terms from Graphene, compares them with
    the local XT database and creates new ones if appropriate

=head1 USAGE

    sudo perl -I/opt/xt/deploy/xtracker/lib -I/opt/xt/deploy/xtracker/lib_dynamic sync_payment_graphene_attributes.pl

=head1 AUTHOR

    Nelio Nunes - L<nelio.nunes@net-a-porter.com>

=cut

use NAP::policy;
use XTracker::Database 'xtracker_schema';
use HTTP::Status qw/ :constants/;
use REST::Client;
use JSON;

my $graphene_host = "http://graphene.wtf.nap";
my $graphene_url = "/suppliers/all-attributes";
my $client = REST::Client->new();

$client->setHost($graphene_host);
$client->GET(
    $graphene_url,
    {Accept => 'application/json'}
);

say "GRAPHENE URL is ".$graphene_host.$graphene_url;

unless ( $client->responseCode == HTTP_OK ) {
    die(sprintf(
            "ERROR: Invalid response %d from Graphene client, exiting now",
            $client->responseCode() )
    );
}

my $response = from_json($client->responseContent());

my $discounts = {};
foreach my $discount (@{$response->{settlementDiscounts}}){
    my $pc = sprintf("%.2f", $discount->{name});
    $discounts->{graphene}->{$pc} = $discount;
}

my $payment_terms = {};
foreach my $term (@{$response->{paymentTerms}}){
    $payment_terms->{graphene}->{$term->{name}} = $term;
}

# Getting all available settlement discounts from the DB
my @existing_settlement_discounts
    = xtracker_schema->resultset('Public::PaymentSettlementDiscount')->all();
foreach my $discount (@existing_settlement_discounts) {
    my $pc = sprintf( "%.2f", $discount->discount_percentage );
    $discounts->{xt}->{$pc} = $discount->id;
}

# Getting all available settlement discounts from the DB
my @existing_payment_terms
    = xtracker_schema->resultset('Public::PaymentTerm')->all();
foreach my $term (@existing_payment_terms) {
    $payment_terms->{xt}->{$term->payment_term} = $term->id;
}

my $changes_needed;
foreach ( [ payment_terms => $payment_terms ], [ discounts => $discounts ], ) {
    my ( $name, $data ) = @$_;

    # Creating the $add_in hash that tells you what needs to be added where
    my $add_in = { xt => [], graphene => [] };
    foreach ( [ sort keys %$add_in ], [ reverse sort keys %$add_in ] ) {
        my ( $from, $to ) = @$_;
        foreach my $data_element ( keys %{ $data->{$from} } ) {
            unless ( defined $data->{$to}->{$data_element} ) {
                push @{ $add_in->{$to} }, $data_element;
            }
        }
    }
    $changes_needed->{$name} = $add_in;
}

# If something needs to be added to graphene, we get a warning. This is not
# really important as these values are to be considered deprecated
for my $element ( keys %$changes_needed ){
  if ( @{$changes_needed->{$element}->{graphene}} ){
      say "WARNING: These $element are in XT but not in Graphene: ".join(", ", @{$changes_needed->{$element}->{graphene}});
  }
}

# If nothing is to be added to XT, then we just leave
my $continue = 0;
for my $element ( keys %$changes_needed ){
  if(@{$changes_needed->{$element}->{xt}}){
      say "* Found missing $element in XT: " . join( ", ", @{ $changes_needed->{$element}->{xt} } );
      $continue = 1;
  }else{
      say "No problems found with the database in XT for $element";
  }
}
exit unless $continue;

# Let's prompt the user to make sure this is intended, because we're making
# changes to the database
print "Are you sure you want to proceed? [YES|Whatever]: ";
chomp( my $input = <> );
if ( $input ne "YES" ) {
    say "Not proceeding ($input != YES)\nHave a nice day!";
    exit;
}

# Adding the new discounts to the database
for my $pc ( sort { $a <=> $b } @{ $changes_needed->{discounts}->{xt} } ) {
    say "Creating discount $pc...";
    xtracker_schema->resultset('Public::PaymentSettlementDiscount')
        ->create( { discount_percentage => $pc } );
}

# Adding the new payment_terms to the database
for my $term ( sort @{ $changes_needed->{payment_terms}->{xt} } ) {
    say "Creating term $term...";
    xtracker_schema->resultset('Public::PaymentTerm')
        ->create( { payment_term => $term } );
}

say "All done";
