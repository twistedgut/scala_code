#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use POE;
use POE::Component::Client::TCP;
use POE::Filter::Stream;

use POSIX qw(setsid);

use XTracker::Database 'xtracker_schema';
use XTracker::Order::Printing::ShipmentDocuments;

use XTracker::Config::Local qw(config_var);

use File::Pid;

chdir '/'                 or die "Can't chdir to /: $!";
umask 0;

# unless we're debugging, redirect output to devnull
if (not config_var('BarcodeScanner', 'debug'))
{
    open STDIN, '<', '/dev/null'   or die "Can't read /dev/null: $!";
    open STDOUT, '>', '/dev/null' or die "Can't write to /dev/null: $!";
    open STDERR, '>', '/dev/null' or die "Can't write to /dev/null: $!";
}

defined(my $pid = fork)   or die "Can't fork: $!";
exit if $pid;
setsid                    or die "Can't start a new session: $!";

my $pid_filename = config_var('BarcodeScanner', 'pidfile');
die 'No parameter for BarcodeScanner pidfile'
    if not defined $pid_filename;

die "Already running : [$pid_filename]"
    if (-e $pid_filename);

my $pidfile = File::Pid->new({ file => $pid_filename });
   $pidfile->write;

my $conf = slurp_conf();

local $SIG{TERM} = 'term_handler';

foreach my $host (keys %{$conf})
{
    my $port     = $conf->{$host}->{port};
    my $document = $conf->{$host}->{document};
    my $label    = $conf->{$host}->{label};

    POE::Component::Client::TCP->new
    (
        RemoteAddress   => $host,
        RemotePort      => $port,
        Filter          => "POE::Filter::Stream",

        #SessionParams => [ options => { debug => 1, trace => 1 } ],

        # The client has connected.  Display some status and prepare to
        # gather information.  Start a timer that will Reconnect if the
        # server does not talk to us for a 2 minutes.
        Connected => sub
        {
            print "Connected to $host:$port ...\n";
            $_[HEAP]->{banner_buffer} = [];
            $_[KERNEL]->delay( reconnect => 120 );
        },


        # The connection failed.
        ConnectError => sub
        {
            print "Could not connect to $host:$port ...\n";
            $_[KERNEL]->delay( reconnect => 5 );
            print "Trying $host:$port in 5s ...\n";
        },

        # The connection timed out
        ConnectTimeout => sub {
            print "Connection timed-out for $host:$port ...\n";
            $_[KERNEL]->delay( reconnect => 5 );
            print "Trying $host:$port in 5s ...\n";
        },


        # Reconnect in 5 seconds if disconnected
        Disconnected   => sub
        {
            print "Connection lost to $host:$port ...\n";
            $_[KERNEL]->delay( reconnect => 5 );
            print "Reconnecting...\n";
        },


        # The server has sent us something.  Save the information.  Stop
        # the ENTER timer, and begin (or refresh) an input timer.  The
        # input timer will go off if the server becomes idle.
        ServerInput => sub
        {
            my ( $kernel, $heap, $input ) = @_[ KERNEL, HEAP, ARG0 ];

            ### log file
            my $log_file = config_var('BarcodeScanner', 'logfile');
            open my $fh, '>>', $log_file || die "Can't open log file: $!";

            print     "Got input from $host:$port - $input\n";
            print $fh "Got input from $host:$port - $input\n";

            if ($input =~ m/(C?\d{6,7}-\d{1,2})/)
            {
                ### box number from input data
                my $box_number = $1;

                print "Read box label - $box_number\n";

                my $shipment_id;

                ### print shipping docs
                eval
                {
                    my $schema = xtracker_schema;
                    $schema->txn_do(sub{
                        $shipment_id = print_shipment_documents($schema->storage->dbh, $box_number, $document, $label);
                    });
                };

                if ($@)
                {
                    print     "Error printing shipping document for: $shipment_id : $@\n";
                    print $fh "Error printing shipping document for: $shipment_id : $@\n";
                }
                else
                {
                    print     "Printed shipping documents for: $shipment_id to $document, $label\n";
                    print $fh "Printed shipping documents for: $shipment_id to $document, $label\n";
                }
            }
            else
            {
                print $fh "Not valid format for box label - $input\n";
            }

            close $fh;

            push @{ $heap->{banner_buffer} }, $input;
            $kernel->delay( reconnect    => undef );
            $kernel->delay( input_timeout => 1 );
        },

        # Reconnect in 5 seconds after server error
        ServerError   => sub
        {
            print "Error from: $host:$port ...\n";
        },
    );
} # foreach barcode host

# Run the clients until the last one has shut down.
$poe_kernel->run();

exit 0;


sub term_handler
{
    warn "deleting pid file : " . $pidfile->file . "\n";
    $pidfile->remove;
    exit;
}

sub test_print_shipment_documents
{
    return 1 if (rand 1 > 0.5);
    die 'fishing';
}

sub slurp_conf
{
    my $conf;

    foreach my $scanner (@{ config_var('BarcodeScanner', 'Scanner') })
    {
        $conf->{$scanner->{ip_addr}} =
        {
            document    => $scanner->{document},
            label       => $scanner->{label},
            port        => $scanner->{port},
        };
    }

    return $conf;
}
