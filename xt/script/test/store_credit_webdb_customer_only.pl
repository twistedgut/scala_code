#!/opt/xt/xt-perl/bin/perl
# script to add credit for one customer, identified by their web db customer id.
# doesn't require the customer to exist in xt.
# currency and channel are hardcoded to USD and OUT_AM.
# doesn't do any validation.
# use at your own risk.
use NAP::policy "tt";

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Config::Local;
use Log::Log4perl;
use NAP::CustomerCredit::Client;

my $customer_id = shift @ARGV; 
my $value       = shift @ARGV; 
my $channel     = shift @ARGV // 'NAP_INTL';
my $currency    = shift @ARGV // 'GBP';

my $user_name   = `logname`;

print "Adding $value $currency for $customer_id";
NAP::CustomerCredit::Client->new({config=>\%XTracker::Config::Local::config})->add_store_credit($channel,$customer_id,$currency,$value,$user_name);

1;
