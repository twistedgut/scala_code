#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib";
use FindBin::libs qw( base=lib_dynamic );

use DBI;

use Getopt::Long;

use XTracker::Database qw( transaction_handle fcp_handle fcp_staging_handle );

## db handles
my $dbh;
my $dbh_fcp;

# option variables
my $start_date = undef;
my $copy_to_live = undef;
my $copy_to_staging = undef;

GetOptions( 'start_date=s' => \$start_date,
            'copylive' => \$copy_to_live,
            'copystaging' => \$copy_to_staging );

die 'Please specify a start date for markdowns' if !defined $start_date;

### connect to XT database
$dbh = transaction_handle() || die print "Error: Unable to connect to DB";

### connect to FCP database
if( $copy_to_live ){
     $dbh_fcp = fcp_handle() || die print "Error: Unable to connect to FCP DB";
}
elsif( $copy_to_staging ){
    $dbh_fcp = fcp_staging_handle() || die print "Error: Unable to connect to FCP DB";
}

my $qry ="select v.product_id, sku_padding(v.size_id) as size_id, pa.id,
pa.percentage, pa.date_start from price_adjustment pa, variant v where
pa.date_start = ? and pa.exported is false and pa.product_id = v.product_id
and v.type_id = 1
";
my $sth = $dbh->prepare($qry);

my $insqry ="insert into price_adjustment values('', ?, ?, '2105-06-01', 'Main Sale', ?)";
my $inssth = $dbh_fcp->prepare($insqry);

my $upqry ="update price_adjustment set exported = true where id = ?";
my $upsth = $dbh->prepare($upqry);

my $qry_cur = "select id from price_adjustment where sku = ? and end_date > ?";
my $sth_cur = $dbh_fcp->prepare($qry_cur);

my $qry_curup = "update price_adjustment set end_date = DATE_ADD(?, INTERVAL -1 MINUTE) where id = ?";
my $sth_curup = $dbh_fcp->prepare($qry_curup);

my $qry_attr = "update attribute_value set value = 'T' where pa_id = 'SALE' and search_prd_id = ?";
my $sth_attr = $dbh_fcp->prepare($qry_attr);


$sth->execute($start_date);

while ( my $row = $sth->fetchrow_hashref() ) {

    $$row{percentage} = $$row{percentage} * -1;

    my $sku = $$row{product_id}."-".$$row{size_id};

    eval {

        # current markdown?
        $sth_cur->execute( $sku, $start_date );

        my @current_markdowns = ();
        while ( my $row = $sth_cur->fetchrow_hashref() ){
            push @current_markdowns, $row->{id};
        }

        if( @current_markdowns ){
            foreach my $markdown_id ( @current_markdowns ){
                $sth_curup->execute( $start_date, $markdown_id );
                print "previous markdown $markdown_id updated\n";
            }
        }

        ### fcp insert
        $inssth->execute($$row{percentage}, $$row{date_start}, $sku);

        ### fcp attribute update
        $sth_attr->execute($$row{product_id});

        ### xtracker update
        $upsth->execute($$row{id});

        print "$sku $$row{percentage}, $$row{date_start}\n";

        if( $copy_to_live ){
            $dbh->commit();
            $dbh_fcp->commit();
        }
        elsif( $copy_to_staging ){
            $dbh_fcp->commit();
        }
    };

    if ($@) {
        $dbh->rollback();
        $dbh_fcp->rollback();

        print $@."\n";

    }
}

$dbh->disconnect();
$dbh_fcp->disconnect();


__END__

