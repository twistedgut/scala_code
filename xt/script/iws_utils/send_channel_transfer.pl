#!/usr/bin/env perl
use NAP::policy "tt";
use Net::Stomp::Producer;
use JSON::XS;
use Getopt::Long::Descriptive;

my @valid_channel =('NET-A-PORTER.COM','theOutnet.com','MRPORTER.COM','JIMMYCHOO.COM');
my $ch_desc = "one of @valid_channel";
sub valid_channel {
    my ($ch_name) = @_;

    return !! grep { $_ eq $ch_name } @valid_channel;
}

my $default_dest = 'queue/dc1/iws_inventory';

my ($opts,$usage) = describe_options(
    "%c %o pid pid ...",
    [ 'from=s', 'channel to transfer from',
      { required => 1, callbacks => { $ch_desc => \&valid_channel } } ],
    [ 'to=s', 'channel to transfer to',
      { required => 1, callbacks => { $ch_desc => \&valid_channel } } ],
    [],
    [ 'broker=s', 'hostname of the broker',
      { default => 'localhost' } ],
    [ 'destination=s', "queue name to send to (defaults to $default_dest)",
      { default => $default_dest } ],
    [],
    [ 'help|h', 'help text' ],
);
if ($opts->help) {
    print $usage->text;
    exit 0;
}

my $ser = JSON::XS->new->utf8;

my $st = Net::Stomp::Producer->new({
    servers => [ { hostname => $opts->broker, port => 61613 } ],
    serializer => sub { $ser->encode($_[0]) },
    default_headers => {
        #'content-type' => 'json',
        persistent => 'true',
    },
});


my $message = {
    from => {
        stock_status => 'main',
        channel => $opts->from,
    },
    to => {
        stock_status => 'main',
        channel => $opts->to,
    },
    what => {
        pid => 66424,
    },
    version => '1.0',
    '@type' => 'stock_change'
};

for my $pid (@ARGV) {
    $message->{what}{pid}=0+$pid;
    say "Sending message for $pid";
    $st->send($opts->destination,
              { type => 'stock_change' },
              $message
    );
}
