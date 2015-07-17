#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib/";
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database qw( get_database_handle );
use XTracker::Database::Channel qw( get_web_channels );
use Mail::Sendmail;
use Getopt::Long;

# connect to XT database
my $dbh     = get_database_handle( { name => 'xtracker', type => 'readonly' } );
my $output  = 'email';

GetOptions(
    'output=s' => \$output,
);

# get each web channel and check orders
my $channels = get_web_channels($dbh);

foreach my $channel_id ( keys %{$channels}) {

    my $missing_order   = 0;
    my %orders          = ();

    # get a web handle for channel
    my $dbh_web = get_database_handle( { name => 'Web_Live_'.$channels->{$channel_id}{config_section}, type => 'readonly' } ) || die print "Error: Unable to connect to website DB for channel: $channels->{$channel_id}{name}";

    # get last 31 days of XT orders
    my $qry = "select order_nr from orders where date > current_timestamp - interval '31 days' and channel_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $channel_id );
    while ( my $row = $sth->fetchrow_hashref() ) {
        $orders{ $row->{order_nr} } = 1;
    }

    # get last day of website orders
    my $upqry ="select id from orders where order_date between date_sub(current_timestamp, interval 30 day) and date_sub(current_timestamp, interval 30 minute)";
    my $upsth = $dbh_web->prepare($upqry);
    $upsth->execute();

    while ( my $row = $upsth->fetchrow_hashref() ) {
        
        # website order not in XT - alert
        if ( !$orders{ $row->{id} } ){

            $missing_order = 1;

            if ($output eq 'email') {        
                print "Sales Channel: ". $channels->{$channel_id}{name} .", Missing Order: ".$row->{id}."\n";
                send_email("ben.galbraith\@net-a-porter.com", "Missing Order on ".$channels->{$channel_id}{name}, "\nOrder Number: ".$row->{id}."\n\nHave a nice day,\nxTracker");
            }
        }    
    }

    if ( $output eq 'techops' ) {
        print $missing_order;
    }

    $dbh_web->disconnect();

}

$dbh->disconnect();

sub send_email {

    my ($to, $subject, $msg) = @_;

    my %mail = (
        To      => $to,
        From    => "order_import\@net-a-porter.com",
        Subject => "$subject",
        Message => "$msg",
    );

    unless ( sendmail(%mail) ) {
        print "no mail: $!";
    }

}

__END__

