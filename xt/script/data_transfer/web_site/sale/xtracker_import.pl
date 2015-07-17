#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib";
use FindBin::libs qw( base=lib_dynamic );

use DBI;
use XTracker::Database 'xtracker_schema';
use Getopt::Long;

# start date passed through by user
my $start_date                  = undef;
my $input                       = undef;

GetOptions( 'start_date=s'                      => \$start_date,
                        'input=s'               => \$input);

die 'Please specify ain input file for markdowns' if !defined $input;
die 'Please specify a start date for markdowns' if !defined $start_date;

print "Input File: $input\n";
print "Start Date: $start_date\n";

my $ckqry ="select id from price_adjustment where product_id = ? and percentage = ?";
my $insqry ="insert into price_adjustment (id, product_id, percentage, date_start, exported, date_finish, category_id) values (default, ?, ?, ?, false, '2100-01-01', (select id from price_adjustment_category where category = ?))";
my $upqry = "update price_adjustment set date_finish = ? where product_id = ? and date_finish = '2100-01-01'";

my $file = $input;

open (my $IN,'<',$file) || warn "Cannot open site input file: $!";

my $schema = xtracker_schema || die print "Error: Unable to connect to DB";
eval {
    $schema->txn_do(sub{
        my $dbh = $schema->storage->dbh;
        my $cksth = $dbh->prepare($ckqry);
        my $inssth = $dbh->prepare($insqry);
        my $upsth = $dbh->prepare($upqry);
        while (my $line = <$IN>) {

            $line =~ s/\r//gi;
            $line =~ s/\n//gi;

            my ($prod_id, $perc, $category) = split(/\t/, $line);

            if ($prod_id > 0) {

                # clean up percentage value
                $perc =~ s/%//gi;

                print "$prod_id, $perc, $category\n";

                # check if it's a duplicate markdown
                my $duplicate = 0;

                $cksth->execute($prod_id, $perc);
                while ( my $row = $cksth->fetchrow_arrayref() ) {
                    $duplicate = $row->[0];
                }

                # existing entry found for same percentage - ignore
                if ($duplicate > 0) {
                    print "Skipped - existing markdown found\n";
                }
                else {
                    # set finish date for any previous markdowns
                    $upsth->execute($start_date, $prod_id);

                    ### import markdown
                    $inssth->execute($prod_id, $perc, $start_date, $category);
                }
            }
            else {
                print "ERROR - could not find product\n";
            }
        }
        print "Completed okay\n";
    });
};
if ($@) {
    print $@."\n";
}

close(IN);
