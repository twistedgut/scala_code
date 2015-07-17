#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;
use Mail::Sendmail;
use XTracker::Config::Local qw( config_var );

# whom to email
my %email_to = (
    'DC1'   => 'fulfilment@net-a-porter.com, customercare@net-a-porter.com',
    'DC2'   => 'customercare.usa@net-a-porter.com, shipping.usa@net-a-porter.com, DistributionUSA@net-a-porter.com',
    'DC3'   => 'CustomerCareCNEscalations@net-a-porter.com, shipping.hk@net-a-porter.com, DistributionAPAC@net-a-porter.com',
);

my $dbh = read_handle();

my $qry = "select shipment_id, to_char(release_date, 'DD-MM-YYYY') as date 
            from shipment_hold 
            where release_date < current_timestamp 
            and shipment_id in (select id from shipment where shipment_status_id = 3)";
my $sth = $dbh->prepare($qry);
$sth->execute();

while ( my $row = $sth->fetchrow_arrayref ){

    my %mail = (            To      => $email_to{ config_var('DistributionCentre', 'name') },
                            From    => "xtracker\@net-a-porter.com",
                            Subject => "Shipment On Hold Beyond Release Date",
                            Message => "\nShipment Number: ".$row->[0]."\nRelease Date: ".$row->[1]."\n\n",
                            );

    unless( sendmail(%mail) ){ warn "Couldn't send email: $!"; }

}

$sth->finish();
$dbh->disconnect();
