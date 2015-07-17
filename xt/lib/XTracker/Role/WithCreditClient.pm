package XTracker::Role::WithCreditClient;
use NAP::policy "tt", "role";
use XTracker::Config::Local;
use NAP::CustomerCredit::Client;

my $client; # we want a singleton, per process

has customer_credit_client => (
    is => 'rw',
    lazy_build => 1,
    builder => 'build_customer_credit_client',
);

sub build_customer_credit_client {
    return $client if $client;

    $client = NAP::CustomerCredit::Client->new({
        config => \%XTracker::Config::Local::config,
    });

    return $client;
}
