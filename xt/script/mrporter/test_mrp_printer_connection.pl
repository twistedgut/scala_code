#!/usr/bin/env perl -w

use strict;
use warnings;
use IO::Socket::INET;

my $address = shift;

die "tell me an ip address" unless ($address);

my $socket = create_socket($address);
die "failed to make socket" unless $socket;

print_to_socket($socket, "01000010");
warn "printed a short message ok";

print_to_socket($socket, "01000010\n");
warn "printed a short message with newline ok";

for my $i (1..8000) {
    print_to_socket($socket, "01000010\n",$i);
}
warn "printed a short message with newline 8000 times ok";

my $bigline = "01000010" x 8000;
print_to_socket($socket,$bigline."\n");
warn "printed a long line of 0s and 1s";

open my $fh, '<', "t/data/testzebracontent.dsp";
my $data = do { local $/; <$fh> };
close $fh;
print_to_socket($socket,$data);
warn "printed a real message ok";

sub create_socket {
    my ($address) = @_;
    my $iosock= IO::Socket::INET->new(
            PeerAddr    => $address,
            PeerPort    => 9100,
            Proto       => 'tcp',
            Timeout     => 3,
    );
    return $iosock;
}

sub print_to_socket {
    my ($socket,$data,$count) = @_;
    $count||="-";
    $data||="test";
    die "no socket ($count)" unless $socket;
    die "socket not connected ($count)" unless $socket->connected;

    #warn "about to print";
    $socket->print($data);
    #warn "printed!";
}


