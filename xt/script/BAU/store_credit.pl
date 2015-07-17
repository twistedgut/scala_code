#!/opt/xt/xt-perl/bin/perl
# script to get shipping charge from shipment by awb, add extra refund, create refund to store credit (or maybe to combination of store credit and card)
use NAP::policy "tt";

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;

use XTracker::Config::Local;
use XTracker::Database qw/schema_handle/;
use XTracker::Role::WithAMQMessageFactory;

use XTracker::Database::Invoice qw/generate_invoice_number/;
 
use Text::CSV;
use Data::Dump 'pp';

my $use_num = 0;
my $use_id = 0;

$|++;

# first pull the csv into an array of hashes (there must be a better way?)

my $file = shift @ARGV; 
my $value = shift @ARGV; 

my @data; my @columns;
my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
     or die "Cannot use CSV: ".Text::CSV->error_diag ();
 
open my $fh, "<:encoding(utf8)", $file or die "$file: $!";

my $row_count = 0;

while ( my $row = $csv->getline( $fh ) ) {
    if ($row_count++ == 0) { 
        @columns = @$row; 
    } else { 
        my $data = {};
        for my $ix ( 0 .. $#columns ) {
            $data->{$columns[$ix]} = (@$row)[$ix];
        }
        push @data, $data;
    }
}

$csv->eof or $csv->error_diag();
close $fh;

print pp @data;
print "\nRecords processed :" . ($row_count - 1) . "\n";

# now we can go through and get the order info inc shipping amount for the shipment, ready to create invoice and store credit

my $schema = schema_handle();

my @store_credits;
my @bad_store_credits;
my @failed_store_credits;


foreach my $data ( @data ) {

  my $order_nr = $data->{'order_nr'}; 
  print "ORDER: $order_nr\n";
  my $order = $schema->resultset('Public::Orders')->find({ order_nr => $order_nr });
  if ($order) { 
    my $customer_number = $order->customer->is_customer_number;
    my $currency_id = $order->currency_id;
    my $currency = $order->currency->currency;
    my $shipment_rs = $order->shipments->search({'shipment_class.class' => 'Standard'}, {join => 'shipment_class'} );
    my $shipment;
    if ( $shipment_rs == 1) {
        $shipment = $shipment_rs->first;
    } else {
        print "No obvious shipment to refund for " . $data->{'Order Number'} . "\n";
        push @bad_store_credits, $data->{'Order Number'};
    }

    if ($shipment) { 
        push @store_credits, {order => $order->order_nr, cust => $customer_number, value  => $value, currency => $currency_id, shipment => $shipment, };
        print "Prepared:  " . join(':',$customer_number, $currency, $value) . "\n";
    }
  }
}

#print pp @store_credits;
print "Store credits count: " . scalar @store_credits . "\n";
print "Bad store credits count: " .  scalar @bad_store_credits . "\n";

sleep (1);

my $notes = 'Auto shipping refund gratuity';
my $factory = XTracker::Role::WithAMQMessageFactory->msg_factory;

my $renumeration_rs = $schema->resultset('Public::Renumeration');

my $dbh=$schema->storage->dbh;

my $sc_count = 0; 

foreach my $store_credit (@store_credits) {
    my ($order, $cust, $currency, $value, $shipment) = ($store_credit->{order}, $store_credit->{cust}, $store_credit->{currency}, $store_credit->{value}, $store_credit->{shipment} );
    print "Creating renumeration... ";

    eval {
        $schema->txn_do( sub {
            my $invoice_nr = generate_invoice_number( $dbh );

            my $renumeration = $renumeration_rs->create( { 
                shipment => { id => $shipment->id },
                invoice_nr =>  $invoice_nr, 
                renumeration_type => { type => 'Store Credit'},
                renumeration_class => { class => 'Gratuity'},
                renumeration_status => { status => 'Completed'},
                shipping  => 0,
                misc_refund => $value,    
                alt_customer_nr => 0,      
                gift_credit => 0, 
                store_credit => 0, 
                currency_id  => $currency, 
                gift_voucher  => 0
            });
            $renumeration->update_status( $renumeration->renumeration_status_id, 1 );
        
            # uncomment to force commit in dev env where amq is not working
            # $schema->txn_commit();

            print "Sending " . join(':',$cust, $currency, $value) . "\n";

            $factory->transform_and_send(
                'XT::DC::Messaging::Producer::Order::StoreCreditRefund',
                {   
                    renumeration => $renumeration
                }
            );
            $sc_count++;
        });
    };
    if ( my $err = $@ ) {
        print "ERROR: $@ \n";
        push @failed_store_credits, $order;
        #die "TEST END";
    }
}

print "Store credits prepared " . scalar @store_credits . "\n";
print "Please check " . join (',',@bad_store_credits) . "\n"; print scalar @bad_store_credits . "\n";
print "FAILED: " . join (',',@failed_store_credits) . "\n"; print scalar @failed_store_credits . "\n";
print "Store credits Processed : $sc_count\n";
