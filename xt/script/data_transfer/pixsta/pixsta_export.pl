#!/usr/bin/perl 

use warnings;
use strict;
use Carp;

use LWP::Simple;
use XML::Writer;
use IO::File;
use Getopt::Long;
use Net::FTP;

use lib qw( /var/data/xtracker/perl );
use XTracker::Database qw( read_handle us_handle );

my $server = 'intl';
GetOptions( 'server=s' => \$server );

my @ids     = qw( );
my %product = ();

# which server to use
my $dbh = $server eq 'intl' ? read_handle() : us_handle();

# get sku to product_id mapping from xtracker db
my $placeholder = ' ?,' x @ids;
chop $placeholder;

my $qry = q{ select p.id, pa.short_description, pd.price, c.classification, d.designer
             from product p, product_attribute pa, price_default pd, classification c, designer d
             where p.id = pa.product_id
             and   p.id = pd.product_id
             and   p.classification_id = c.id
             and   p.designer_id = d.id
             and   p.live    = 't'
             and   p.visible = 't'
           };
my $sth = $dbh->prepare( $qry);
$sth->execute();

while ( my $row = $sth->fetchrow_hashref() ){
    $product{ $row->{id} } = { short_desc => $row->{short_description},
                               price      => $row->{price},
                               class      => $row->{classification},
                               designer   => $row->{designer} };
}

$dbh->disconnect();

# initialise base directories


chdir( '/var/data/xtracker/utilities/affiliates/pixsta' );

# grab images for each sku and write out to local directory structure
# open my $fh, '>', 'pixsta_products.xml' || die "can't open file: $!";

my $dirname  = 'pixsta_export';
my $filename = 'pixsta_products';
$dirname     .= $server eq 'intl' ? '_intl' : '_am'; 
$filename    .= $server eq 'intl' ? '_intl.xml' : '_am.xml'; 

my $base     = "/var/data/xtracker/utilities/affiliates/pixsta/$dirname";
my $url_base = 'http://staging.net-a-porter.com/intl/images/product/';
mkdir $dirname;

my $fh = IO::File->new(">$base/$filename");

# set up xml document
my $writer = XML::Writer->new( OUTPUT   => $fh,
                               # ENCODING => 'utf-8',
                               NEWLINES => 1,
                             );

$writer->xmlDecl("UTF-8");
# $writer->doctype("xml");
$writer->startTag("xml");

foreach my $pid ( keys %product ){

    my $file_path = qq{ $url_base/$pid/large/index.jpg };
    
    if( my $image = get($file_path) ){

        my $local_file = "$base/$pid.jpg";

        # write file into directory structure
        open my $ifh, '>', "$local_file" || die qq{ can't open image file: $! };
        print $ifh $image;
        close $ifh;

        if( $product{$pid}->{short_desc} =~ s/&Atilde;&copy;/é/xmsg ){ print "[ Fixed Bad Chars ]" }

        $writer->emptyTag('image', filename    => "$pid.jpg",
                                   url         => "http://www.net-a-porter.com/product/$pid",
                                   price       => "£$product{$pid}->{price}",
                                   description => "$product{$pid}->{short_desc}",
                                   category    => "$product{$pid}->{class}",
                                   brand       => "$product{$pid}->{designer}" );


        print "[ OK ] $pid\n";
    }
    else{
        print "[ FAILED ] $pid\n"
    }
}

$writer->endTag();
$writer->end();
$fh->close();

# tar and gzip
## no critic(ProhibitBacktickOperators)
my $tarfile = "netaporter_$server.tar";
`tar cvf $tarfile $dirname`;
`gzip $tarfile`;

## ftp to pixsta
my $ftp = Net::FTP->new("ftp.pixsta.com", Debug => 0) or die "Cannot connect to ftp.pixsta.com: $@";
$ftp->login("nap.ftp",'gh!3KzL*') or die "Cannot login ", $ftp->message;
$ftp->binary;
$ftp->put("$tarfile.gz") or die "get failed ", $ftp->message;
$ftp->quit;

`mv "$tarfile.gz" archive`;

__END__


