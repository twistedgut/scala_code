package Test::XTracker::Schema::Result::Public::Client;
use NAP::policy "tt", qw/test class/;

BEGIN {
    extends 'NAP::Test::Class';
};

sub test__get_client_code :Tests {
    my ($self) = @_;

    my @clients = $self->schema()->resultset('Public::Client')->search()->all();

    for my $client (@clients) {
        my $client_code = $client->get_client_code();
        ok($client_code, 'Client: "' . $client->name()
           . '" has returned a client code ' . $client_code);
    }

}
