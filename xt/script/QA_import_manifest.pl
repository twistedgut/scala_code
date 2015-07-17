#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;

=head1 NAME

QA_import_manifest.pl

=cut

use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use FindBin::libs qw( base=lib_dynamic );
use utf8;

use DBI;

my $HOSTNAME;

BEGIN {
  use Sys::Hostname;
  # Only edit the next 3 lines
  ($HOSTNAME = hostname) =~ s/\..*$//;
}

my $manifest_id =  shift or usage();

my %known_am_hosts = (
   'vaderv02' => 1,
   'kingpinv10' => 1,
   'kingpinv05' => 1
);

my $db;

if (exists $known_am_hosts{$HOSTNAME}) {
    $db = 'xtracker_dc2';
}
$db ||= 'xtracker';


my $DSN     = 'dbi:Pg:dbname='. $db . ";host=localhost";
my $PGUSER  = 'postgres';
print "Connecting to $db.... ";
my $dbh = DBI->connect($DSN, $PGUSER)
    or die "Failed to connect to temp database " . $db . " .. " . $DBI::errstr;

my $up_man_sql=<<EOF;

update manifest set status_id  = 5 where id in ($manifest_id);

EOF

my $up_man_sth=$dbh->prepare($up_man_sql)
    or die "Could not prepare query " . $db . " .. " . $DBI::errstr;

$up_man_sth->execute()
    or die "Couldn't execute statement: " . $up_man_sth->errstr;

my $up_ship_sql=<<EOF;
update shipment set shipment_status_id = 2
where id in (select shipment_id from link_manifest__shipment where manifest_id in ($manifest_id) );
EOF

my $up_ship_sth=$dbh->prepare($up_ship_sql)
    or die "Could not prepare query " . $db . " .. " . $DBI::errstr;

$up_ship_sth->execute()
    or die "Couldn't execute statement: " . $up_ship_sth->errstr;
print "Done!\n";

exit;

sub usage {
  print STDERR "Usage: $0 manifest_id\n";
  exit 1;
}

