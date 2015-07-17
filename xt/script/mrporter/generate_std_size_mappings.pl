#!/opt/xt/xt-perl/bin/perl
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use warnings;
use strict;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw(get_database_handle get_schema_using_dbh);
use XTracker::Config::Local qw( config_var );
use XTracker::Comms::DataTransfer qw( get_transfer_sink_handle );
use XTracker::Logfile qw(xt_logger);
use XT::JQ::DC::Send::Product::WebUpdate;
use Getopt::Long;
use Data::Dump qw(pp);

my ($logging,$input,$channel_id,$fudge,$skip);
GetOptions(
    'logging=s' => \$logging,
    'input=s' => \$input,
    'channel_id=s' => \$channel_id,
    'fudge=s' => \$fudge,
    'skip=s' => \$skip,
);

my $logger      = xt_logger('XTracker');

open(my $input_fh,"<",$input) or die $!;
my @mappings = <$input_fh>;
close $input_fh;

my $class = ($input =~m/shoes/) ? "Shoes" : "Clothing"; 

my $schema      = get_database_handle( { name => 'xtracker_schema', type => 'transaction' } );

my $size_schemes        = $schema->resultset('Public::SizeScheme');
my $std_size_mappings   = $schema->resultset('Public::StdSizeMapping');
my $sizes               = $schema->resultset('Public::Size');
my $classifications     = $schema->resultset('Public::Classification');
my $std_sizes           = $schema->resultset('Public::StdSize');
my $products            = $schema->resultset('Public::Product');
my $variants            = $schema->resultset('Public::Variant');
my $channels            = $schema->resultset('Public::Channel')->get_channels();
my $product_attributes  = $schema->resultset('Public::ProductAttribute');


$logger->warn("CONNECTED") if ($schema && $logging);

my $classification = $classifications->search({classification=>$class})->single or die $!;

foreach my $mapping (@mappings){
    next if $skip;
    my ($scheme_id,$scheme_name,$size_name,$std_size_name)=split(/,/,$mapping);
    chomp($scheme_id,$scheme_name,$size_name,$std_size_name);
    my $std_size = $std_sizes->search({name=>$std_size_name})->single or die $!;
    my $size_scheme = $size_schemes->find($scheme_id) or die $!;
    $logger->warn("Processing ".$size_scheme->id."-".$size_scheme->name." - ".$size_name) if ($logging);    
    my $size = $size_scheme->size_scheme_variant_sizes->search_related('size',{size=>$size_name})->single()
        or die "Could not find a size named $size_name in $scheme_name\nError:";
    
    $std_size_mappings->search({
        size_scheme_id      =>  $scheme_id,
        size_id             =>  $size->id,
        classification_id   =>  $classification->id,
        product_type_id     =>  undef,
    })->delete;

    $std_size_mappings->create({
        size_scheme_id      =>  $scheme_id,
        size_id             =>  $size->id,
        classification_id   =>  $classification->id,
        product_type_id     =>  undef,
        std_size_id         =>  $std_size->id,
    });

    foreach my $product_attribute ($product_attributes->search({size_scheme_id=>$scheme_id})->all()){ 
        foreach my $variant ($product_attribute->product->search_related('variants',{size_id=>$size->id})->all()){
            $logger->warn("\tProcessing ".$variant->product_id." size ".$variant->size->size." to std_size_id:".$std_size->id) if ($logging);    
            $variant->update({
                        std_size_id     => $std_size->id,
            });
        }    
    }
}

next unless $fudge; 

# This section should only be activated when fudging a dav env that's already had products created/pushed
# without a standard size mapping. This is very ugly DON'T LOOK!

my %product_hash;
die "No channel id provided (--channel_id)" unless $channel_id;
my $dbh     = get_database_handle({ name => 'Web_Live_'.$channels->{$channel_id}{config_section}, type => 'transaction' });
my $sql     = "SELECT * FROM product WHERE sku not like '9%'";
my $sth     = $dbh->prepare($sql);
$sth->execute();
my $res     = $sth->fetchall_hashref("sku");

foreach my $sku (keys %{$res}){
    my ($product_id,$size_id)=split(/-/,$sku);
    my $variant = $variants->search({product_id=>$product_id,size_id=>$size_id})->single;
    unless ($variant->std_size_id()){
        $logger->warn("SKIPPING $sku as no std_size_id set") if ($logging);
        next;
    }
    $sql    = "UPDATE product SET standardised_size_id = ".$variant->std_size_id()." WHERE sku='$sku'";
    $logger->warn($sql) if ($logging);
    my $rows_affected = $dbh->do($sql); 
    $logger->warn("SUCCESS") if ($logging && $rows_affected);
    $dbh->commit();
}                          

$dbh->disconnect();
