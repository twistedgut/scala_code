#!/usr/bin/perl -w
use strict;
use warnings;
package Test::BarcodeScanner;
use base qw(Net::Server);
## no critic(RequireConsistentNewlines)

sub process_request
{
    my $self = shift;
    while (1)
    {
        sleep 5;
        print "123456-12"
            or die "mehbags $!";
    }
}

Test::BarcodeScanner->run(port => 8080);
