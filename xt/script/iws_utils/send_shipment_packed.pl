#!perl
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)

=head1 NAME

iws_utils/send_shipment_packed.pl

=head1 DESCRIPTION

Given a file of shipment ids, it works out which ones are packed, and sends a shipment_packed message

=head1 SYNOPSIS

perl script/iws_utils/send_shipment_packed.pl --shipmentfile=../Open_Shipments_20110728.csv  --dbhost=xtdc1.wtf.nap --dbpass=<password> --dbuser=<username> --amqhost=xtdc1-qa4.dave

perl iws_utils/send_shipment_packed.pl [options]

 options:
    --help|?            this page
    --shipmentfile|s    the path to the file with shipment ids to parse
    --outputformat|o    the output format. valid values are 'stats', 'ids', or 'csv'
    --dbhost|h          where to find the xtracker database
    --dbname|n          name of the database
    --dbuser|u          username for DB access
    --dbpass|p          password for DB access
    --amqhost|a         the hostname of the amq broker to send the messages to
    --really_send|r     Needs to be set to really send AMQ messages. If this isn't set no changes are made anywhere.

=cut

use NAP::policy "tt";

use Getopt::Long;
use Pod::Usage;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Path::Class;
use Text::CSV_XS;
use DBI;
use Net::Stomp::Producer;
use NAP::Messaging::Serialiser;
use Data::Dump qw/pp/;

my $validformats = {'stats' => 1, 'ids' => 1, 'csv' => 1};
my %opt = (
            shipmentfile => '',
            outputformat => 'stats',
            dbhost       => '',
            dbname       => 'xtracker',
            dbuser       => 'www',
            dbpass       => 'www',
           );
GetOptions( \%opt, 'shipmentfile|s=s',
                   'outputformat|o=s',
                   'dbhost|h=s',
                   'dbname|n=s',
                   'dbuser|u=s',
                   'dbpass|p=s',
                   'amqhost|a=s',
                   'really_send|r=s',
                   'help|?' );
pod2usage(1) if ($opt{help});
foreach (keys %opt){
    unless ($opt{$_}){
        warn "no value set for $_\n";
        pod2usage(1);
    }
}
die "invalid output format"
    unless $validformats->{$opt{outputformat}};
die "You're gonna have to provide an amqhost if you want to really send messages"
    if ($opt{really_send} && !$opt{amqhost});

my $factory = ($opt{amqhost}) ? Net::Stomp::Producer->new({
    servers => [ {
        hostname => $opt{amqhost},
        port     => 61613,
    } ],
    serializer => sub { NAP::Messaging::Serialiser->serialise($_[0]) },
    default_headers => {
        'content-type' => 'json',
        persistent => 'true',
    },
}) : undef;
die "no valid AMQ connection"
    if ($opt{really_send} && !$factory);


my $in = file($opt{shipmentfile})->openr || die "failed to open file $opt{shipmentfile}";

my $DSN     = 'dbi:Pg:dbname='. $opt{'dbname'} . ";host=" . $opt{'dbhost'};
my $PGUSER  = $opt{'dbuser'};
my $PGPASS  = $opt{'dbpass'};
my $dbh_xtracker = DBI->connect($DSN, $PGUSER, $PGPASS)
    or die "Failed to connect to xtracker database " . $DBI::errstr;

my $sql = "select shipment_status_id, status from shipment s join shipment_status ss on s.shipment_status_id = ss.id where s.id=?";



my $data;
my $messages_sent = 0;
my $csv=Text::CSV_XS->new({
    binary=>1,
    eol=>"\n",
});
while (my $row_in=$csv->getline($in)) {
    my $sid = $row_in->[0];
    $sid =~ s/^s-//; # strip 's-' at start of shipment
    my $row = $dbh_xtracker->selectrow_hashref($sql, undef, ($sid));
    unless ($row){
        warn(qq{WARNING: Couldn't find shipment $sid in XT db});
        next;
    }
    if ($opt{outputformat} eq 'ids'){
        push @{$data->{$row_in->[1]}->{$row->{status}}}, $sid;
    } elsif ($opt{outputformat} eq 'stats'){
        $data->{$row_in->[1]}->{$row->{status}}++;
    } elsif ($opt{outputformat} eq 'csv'){
        $row_in->[2] = $row->{status};
        push @$data, $row_in;
    }


    next unless $opt{really_send};

    next unless ($row->{status} eq 'Dispatched' && lc($row_in->[1]) eq 'fullyassembled');
#    next unless $row->{status} eq 'Dispatched';


    # fake dispatch!
    $factory->send(
        '/queue/dc1/iws_fulfulment',
        {
            type => 'shipment_packed',
        },
        {
            shipment_id => "s-$sid",
            containers => [],
            version => '1.0',
            spur => 0,
        },
    );

    $messages_sent++;
}

if ($opt{outputformat} eq 'csv'){
    (my $newfilename = $opt{shipmentfile}) =~ s/\.csv$/-output\.csv/;
    my $out = file($newfilename)->openw || die "failed to open file $newfilename for writing";
    $csv->print ($out, $_) for @$data;
    print "new file $newfilename written\n";
} else {
    print pp($data);
}
print "\n******************\nmessages sent $messages_sent\n******************\n";







