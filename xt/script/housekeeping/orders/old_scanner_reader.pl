#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib/";
use FindBin::libs qw( base=lib_dynamic );

use POE;
use POE::Component::Client::TCP;
use POE::Filter::Stream;

use POSIX qw(setsid);

use XTracker::Database 'xtracker_schema';
use XTracker::Order::Printing::ShipmentDocuments;

chdir '/'                 or die "Can't chdir to /: $!";
umask 0;

open STDIN, '<', '/dev/null'   or die "Can't read /dev/null: $!";
open STDOUT, '>', '/dev/null' or die "Can't write to /dev/null: $!";
open STDERR, '>', '/dev/null' or die "Can't write to /dev/null: $!";
defined(my $pid = fork)   or die "Can't fork: $!";
exit if $pid;
setsid                    or die "Can't start a new session: $!";


### hash to assign printers to hosts
my %printers = (
    "10.3.6.60" => { "document" => "Shipping Document 2", "label" => "Shipping Label 2" },
    "10.3.6.61" => { "document" => "Shipping Document 1", "label" => "Shipping Label 1" },
);

my $port = qw( 515 );    # The port to connect to.
my @hosts  = qw (10.3.6.60 10.3.6.61);                        # The hosts to test.
#my @hosts  = qw (10.3.6.60);

# Spawn a new client for each port.

foreach my $host (@hosts) {

    POE::Component::Client::TCP->new
      ( RemoteAddress => $host,
        RemotePort => $port,
        Filter     => "POE::Filter::Stream",

        # The client has connected.  Display some status and prepare to
        # gather information.  Start a timer that will send ENTER if the
        # server does not talk to us for a while.

        Connected => sub {
            print "Connected to $host:$port ...\n";
            $_[HEAP]->{banner_buffer} = [];
            $_[KERNEL]->delay( send_enter => 5 );
        },

        # The connection failed.

        ConnectError => sub {
            print "Could not connect to $host:$port ...\n";
        },

        # Reconnect in 5 seconds if disconnected
        Disconnected   => sub {
            print "Connection lost to $host:$port ...\n";
            $_[KERNEL]->delay( reconnect => 5 );
            print "Reconnecting...\n";
        },

        # The server has sent us something.  Save the information.  Stop
        # the ENTER timer, and begin (or refresh) an input timer.  The
        # input timer will go off if the server becomes idle.

        ServerInput => sub {
            my ( $kernel, $heap, $input ) = @_[ KERNEL, HEAP, ARG0 ];

            ### log file
            open my $fh, '>>', '/opt/xt/deploy/xtracker/script/housekeeping/shipment/scanner.log' || die "Can't open log file: $!";

            print "Got input from $host:$port - $input\n";
            print $fh "Got input from $host:$port - $input\n";

            if ($input =~ m/(\d{6,7}-\d{1,2})/) {

                ### box number from input data
                my $box_number = $1;

                print "Read box label - $box_number\n";

                my $shipment_id;

                ### print shipping docs
                eval {
                    my $schema = xtracker_schema;
                    $schema->txn_do(sub{
                                        $shipment_id = print_shipment_documents($schema->storage->dbh, $box_number, $printers{$host}{"document"}, $printers{$host}{"label"});
                                    });
                };

                if ($@) {
                    print "Error printing shipping document for: $shipment_id : $@\n";
                    print $fh "Error printing shipping document for: $shipment_id : $@\n";
                }
                else {
                    print "Printed shipping documents for: $shipment_id to ".$printers{$host}{"document"}.", ".$printers{$host}{"label"}."\n";
                    print $fh "Printed shipping documents for: $shipment_id to ".$printers{$host}{"document"}.", ".$printers{$host}{"label"}."\n";
                }
            }
            else {
                print $fh "Not valid format for box label - $input\n";
            }

            close $fh;


            push @{ $heap->{banner_buffer} }, $input;
            $kernel->delay( send_enter    => undef );
            $kernel->delay( input_timeout => 1 );
        },

        # Reconnect in 5 seconds after server error
        ServerError   => sub {
                print "Error from: $host:$port ...\n";
        },
      );
}

# Run the clients until the last one has shut down.

$poe_kernel->run();

exit 0;


