#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib/";
use FindBin::libs qw( base=lib_dynamic );

use DBI;
use XTracker::Database qw( read_handle fcp_handle fcp_staging_handle );
use Mail::Sendmail;

### connect to database
my $dbh = read_handle() || die print "Error: Unable to connect to DB";

my $dbh_fcp = fcp_handle() || die print "Error: Unable to connect to FCP DB";

#my $dbh_fcp = fcp_staging_handle() || die print "Error: Unable to connect to FCP DB";

my %orders = ();

my $qry = "select order_nr from orders where date > current_timestamp - interval '2 days'";
my $sth = $dbh->prepare($qry);
$sth->execute();
while ( my $row = $sth->fetchrow_hashref() ) {
    $orders{$$row{order_nr}} = 1;
}

my $upqry ="select id from orders where order_date between date_sub(current_timestamp, interval 1 day) and date_sub(current_timestamp, interval 2 hour)";
my $upsth = $dbh_fcp->prepare($upqry);
$upsth->execute();

while ( my $row = $upsth->fetchrow_hashref() ) {
    if (!$orders{$$row{id}}) {
        print $$row{id}."\n";
        #send_email("ben.galbraith\@net-a-porter.com", "Missing Order", "\nOrder ID: ".$$row{id}."\n\nHave a nice day,\nxTracker");
    }    
}


$dbh->disconnect();
$dbh_fcp->disconnect();


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

