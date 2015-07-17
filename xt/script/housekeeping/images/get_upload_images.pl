#!/opt/xt/xt-perl/bin/perl
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use lib "/opt/xt/deploy/xtracker/lib";
use FindBin::libs qw( base=lib_dynamic );

use warnings;
use strict;
use Carp;

use XTracker::Database qw(get_database_handle);
use LWP::Simple;

my %sku = ();
my $debug = $ENV{'DEBUG'} || 0;

my $ful_dbh = get_database_handle( { name => 'Fulcrum', type => 'readonly' } );

my $ful_qry = "select product_id from product.product_channel
where id in (select product_channel_id from list.item where list_id in
(select id from list.list where status_id < 6 and type_id = 3 and due is
null)) group by product_id";
my $ful_sth = $ful_dbh->prepare( $ful_qry );
$ful_sth->execute();
while ( my $row = $ful_sth->fetchrow_hashref() ){
    # $sku{ $row->{product_id} } = $row->{product_id};
}

# get sku to product_id mapping from xtracker db

my %dbh = (
    'DC1' => get_database_handle( { name => 'XTracker_DC1', type => 'readonly' } ),
    'DC2' => get_database_handle( { name => 'XTracker_DC2', type => 'readonly' } ),
);

# some old queries below for various purposes
#my $dbh = get_database_handle( { name => 'Fulcrum', type => 'readonly' } );

#Fulcrum list based query
#my $qry = "select product_id as id, product_id as legacy_sku from product.product_channel where id in
#(select product_channel_id from list.item where list_id in (1144, 1145))";

#my $qry = "select id, legacy_sku from product where id in (select
#product_id from product_channel where upload_date > current_timestamp - interval '1 day')";

#my $qry = "select id, id as legacy_sku from product where id in (select
#product_id from product_channel where product_id between 40000 and 70000
#and live = true and visible = true and channel_id in (1,2))";


foreach my $dc (keys %dbh) {
    print "Gathering $dc PID's...\n" if $debug;

    my $qry = "select id from product where id in (select product_id from product_channel where upload_date > current_timestamp - interval '1 day')";
    my $sth = $dbh{$dc}->prepare( $qry );
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
        $sku{ $row->{id} } = $row->{id};
    }
}
my $bob = keys(%sku);
#die $bob;
print "Done, now get images...\n\n" if $debug;

# check current image
# read the directory for image 12.jpg

# check live images

# download live image if not present

my %file_types = ( in => '12', 'fr' => '68', 'bk' => '36', 'cu' => '66', );

# initialise base directories

my $base     = '/var/data/xt_static/images/product';
#my $url_base = 'http://www.net-a-porter.com/pws/images/product';
my $url_base = 'http://cache.net-a-porter.com/images/products/';

# grab images for each sku and write out to local directory structure

SKU:
foreach my $id ( keys %sku ){

    print "[ ** $id ** ]\n" if $debug;

    # create base directory
    my $local_dir = "$base/$id";

    unless( -e $local_dir  ){
        mkdir("$local_dir");
        print "[ CREATE ] $local_dir\n" if $debug;
    }


    TYPE:
    foreach my $type ( keys %file_types  ){

        # check for both NAP and MRP file naming conventions
        NAMING:
        for my $naming ('','mrp_') {
            my $file_path = $url_base.'/'.$id.'/'.$id.'_'.$naming.$type.'_l.jpg';
            my $local_file = "$base/$id/$file_types{$type}.jpg";

            if( -e $local_file){
                #print "[ SKIPPED $local_file ] already present\n\n";
                next NAMING;
            }

            print "[ TRYING ] $file_path\n" if $debug;

            if( my $image = get($file_path) ){

                my $local_file = "$base/$id/$file_types{$type}.jpg";

                print "[ RETRIEVED ] $file_path\n" if $debug;

                # write file into directory structure
                open my $fh, '>', "$local_file";
                print $fh $image;
                close $fh;
                chmod 0744,$local_file;

                print "[ WRITTEN ] $local_file\n" if $debug;
            }
            else{
                print "[ SKIPPED ] $file_path not present\n" if $debug;
            }
            print "\n" if $debug;
        }
    }
}


__END__
