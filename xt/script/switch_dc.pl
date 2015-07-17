#!/usr/bin/env perl
# Script to ease effort of switching between DCs on a single dev vm.
use strict;
use warnings;

use FindBin;
use Getopt::Long;

my ($nodbreset, $db_name, $email_address, $verbose);
GetOptions(
    "nodbreset" => \$nodbreset,
    "dbname=s"  => \$db_name,
    "email=s"  => \$email_address,
    "verbose" => \$verbose,
);
$nodbreset //= 0;
$verbose //= 0;
$email_address //= $ENV{USER} . '@net-a-porter.com';

# TODO: Move this to a config file or something
my $DEFAULT_DB_NAME = 'xt';

my ($dc, $prl) = @ARGV;
$prl //= 0;
if(!$dc) {
    print "USAGE: switch_dc.pl <DC> <PRL PHASE (Default=0)>\n";
    exit 0;
}

$db_name //= $DEFAULT_DB_NAME;

# Download a blank db
unless($nodbreset) {
    print 'Downloading blank db... ';
    execute("$FindBin::Bin/download_blank_db.pl -d $dc -t $db_name");
}

print "OK\nmake pre-work... ";
execute("perl $FindBin::Bin/../Makefile.PL");

# Regenerate ENV file
print "OK\nRegenerating ENV file... ";
my $output = execute("$FindBin::Bin/update_test_config_noddy.pl  --temp=\"$FindBin::Bin/../conf/nap_dev.properties\" --email='$email_address' --hosttype=XTDC$dc --db=$db_name --host=localhost --prl=$prl");

print "OK\nRunning make setup... ";
if($output =~ /FILE\: (.+)/) {
    my $tmp_file = $1;
    chdir("$FindBin::Bin/../");
    execute("make setup NAP_PROPERTIES_FILE=$tmp_file");
} else {
    die 'Could not parse generated properties-file file-name';
}

print "OK\nGranting super powers... ";
my $username = $ENV{USER};
execute("psql -U postgres -d $db_name -c \"select superpowers('$username','$email_address',1);\"");

my ($dev_root) = $FindBin::Bin =~ /(.+)\/script/;
print "OK\nAll done! (Don't forget to 'source $dev_root/xtdc/xtdc.env')\n";

sub execute {
    my ($command) = @_;
    print "$command\n\n" if $verbose;
    $command = "$command 2>&1";
    my $stdout = `$command`; ## no critic(ProhibitBacktickOperators)
    print $stdout if $verbose;
    return $stdout;
}
