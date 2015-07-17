#!/opt/xt/xt-perl/bin/perl -w
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use English qw( -no_match_vars );

use XTracker::Database qw ( get_database_handle );
use XTracker::Database::Stock qw ( get_saleable_item_quantity );
use XTracker::Database::Invoice qw( get_invoice_country_info );
use Encode;
use Getopt::Long;
use HTML::Strip;

$OUTPUT_AUTOFLUSH = 1;

my @channels;
my $quiet;
GetOptions ("channel=i{1,}" => \@channels,
            "quiet" => \$quiet);

# class id defined in LinkShare Merchandiser Program doc (see EN-675)
# we only sell clothing and accessories
my $CLASS_ID = 60;

my %gender_map = (
    # channel_id => "Gender"
    1 => "Female",
    2 => "Female",
    3 => "Female",
    4 => "Female",
    5 => "Male",
    6 => "Male",
);

my $age = 'Adult'; # this may need to be channel specific at some stage

# hash of designers to exclude from feed
my %designer_exclusion = (
    'Mulberry' => 1,
    'Gucci' => 1,
    'Loro Piana' => 1,
    'Chanel Fine Jewelry' => 1,
);

### Linkshare account numbers for INTL and AM
my %accounts = (
    'NET-A-PORTER.COM'  => { 'DC1' => '24448', 'DC2' => '24449' },
    'theOutnet.com'    => { 'DC1' => '35290', 'DC2' => '35291' },
    'MRPORTER.COM'    => { 'DC1' => '36586', 'DC2' => '36592' },
);


### db handles
my %dcs = (
    'DC1'   => {
        'accounts'  => {
            'NET-A-PORTER.COM'  => {
                'channel_id'        => 1,
                'short_name'        => 'NETAPORTER',
                'account_number'    => 24448,
                'url'               => 'http://www.net-a-porter.com/intl/product/PRODID?cm_mmc=ProductFeed-_-DESIGNERNAME',
            },
            'theOutnet.com'  => {
                'channel_id'        => 3,
                'short_name'        => 'THEOUTNET',
                'account_number'    => 35290,
                'url'               => 'http://www.theoutnet.com/intl/product/PRODID?cm_mmc=ProductFeed-_-DESIGNERNAME',
            },
            'MRPORTER.COM'  => {
                'channel_id'        => 5,
                'short_name'        => 'MRPORTER',
                'account_number'    => 36586,
                'url'               => 'http://www.mrporter.com/intl/product/PRODID?cm_mmc=ProductFeed-_-DESIGNERNAME',
            },
        },
    },
    'DC2'   => {
        'accounts'  => {
            'NET-A-PORTER.COM'  => {
                'channel_id'        => 2,
                'short_name'        => 'NETAPORTER',
                'account_number'    => 24449,
                'url'               => 'http://www.net-a-porter.com/am/product/PRODID?cm_mmc=ProductFeed-_-DESIGNERNAME',
            },
            'theOutnet.com'  => {
                'channel_id'        => 4,
                'short_name'        => 'THEOUTNET',
                'account_number'    => 35291,
                'url'               => 'http://www.theoutnet.com/am/product/PRODID?cm_mmc=ProductFeed-_-DESIGNERNAME',
            },
            'MRPORTER.COM'  => {
                'channel_id'        => 6,
                'short_name'        => 'MRPORTER',
                'account_number'    => 36592,
                'url'               => 'http://www.mrporter.com/am/product/PRODID?cm_mmc=ProductFeed-_-DESIGNERNAME',
            },
        },
    }
);

# Based on which channels we got as input, we'll now clean the %dcs hash - not
# the best thing to do but considering the mess scrip is, it's the most safe
# alternative

for my $dc(keys %dcs){
    for my $account (keys %{$dcs{$dc}->{accounts}}){
        my $this_channel_id = $dcs{$dc}->{accounts}->{$account}->{channel_id};
        unless (grep {$_ eq $this_channel_id} @channels) {
            delete $dcs{$dc}->{accounts}->{$account};
        }
    }
    if (keys %{$dcs{$dc}->{accounts}}){
        # When we're sure we'll use this DC then we'll get the DB handle
        $dcs{$dc}{db_handle} = get_database_handle( { name => 'XTracker_'.$dc, type => 'readonly' } );
    }else{
        delete $dcs{$dc};
    }
}

unless (keys %dcs){
    die("Nothing to connect to, please check script input parameters");
}

my ($default_dc) = sort keys %dcs;

print "Using default DC $default_dc\n";

### db query to get date in correct formats
my $dt_qry = "select to_char(current_timestamp, 'YYYYMMDD') as short_date, to_char(current_timestamp, 'YYYY-MM-DD/HH24:MI:SS') as long_date";
#This is just to get the appropriate date string to put on each filename
my $dt_sth = $dcs{$default_dc}{db_handle}->prepare($dt_qry);
$dt_sth->execute();
my $row = $dt_sth->fetchrow_hashref();
my $short_date  = $row->{short_date};
my $long_date   = $row->{long_date};

### set up queries

### original per product query - keeping to cross check new query below?
my $prod_qry = "
    select p.id, pd.currency_id, pd.price, cur.currency, pa.name, pa.short_description, pa.long_description, pa.keywords, d.designer, d.url_key, pt.product_type, st.sub_type, pch.visible,
        p.colour_filter_id, p.colour_id, pa.designer_colour, sa.fabric_content
    from product p, product_channel pch, price_default pd, product_attribute pa, designer d, product_type pt, sub_type st, currency cur, shipping_attribute sa
    where p.id = pch.product_id
    and pch.channel_id = ?
    and pch.live = true
    and pch.visible = true
    and p.id = pd.product_id
    and p.id = pa.product_id
    and p.designer_id = d.id
    and p.product_type_id = pt.id
    and p.sub_type_id = st.id
    and pd.currency_id = cur.id
    and sa.product_id = p.id";

my $saleqry = "select product_id, percentage from price_adjustment where current_timestamp between date_start and date_finish order by date_start asc";

# for now we are keeping the original query to ensure consistency so we only need to bring back the variant specific info for each pid -
# also we can use this to cross check with the saleable quantities
# POSSIBLE ERROR IN GETTING US SIZE
my $variant_qry = "
    select v.id, ss.short_name as size_scheme, sd.size as designer_size
    from product p, product_channel pch, product_attribute pa, designer d, product_type pt,
        variant v, size sd, size_scheme ss
    where p.id = pch.product_id
    and pch.channel_id = ?
    and pch.live = true
    and pch.visible = true
    and p.id = pa.product_id
    and p.designer_id = d.id
    and p.product_type_id = pt.id
    and v.product_id = p.id
    and v.designer_size_id = sd.id
    and pa.size_scheme_id = ss.id
    and p.id = ?";

my $uk_price_qry = "
    select pc.price, cu.currency, co.country
    from price_country pc, currency cu, country co
    where pc.currency_id = cu.id
    and pc.country_id = co.id
    and co.country = 'United Kingdom'
    and pc.product_id = ?";


# loop over each DC and produce files
foreach my $dc ( keys %dcs ) {
    ## no critic(ProhibitDeepNests)
    my $dbh = $dcs{$dc}{db_handle};
    my $queries = {
        variant_sth => $dbh->prepare($variant_qry),
    }; # We'll save the prepared queries here so we don't have to prepare them over and over again

    my $colour_ref = get_lookup ($dbh, "select id, colour from colour");
    my $colour_filter_ref = get_lookup ($dbh, "select id, colour_filter from colour_filter");

    ### get markdowns
    my %markdowns = ();

    my $salesth = $dbh->prepare($saleqry);
    $salesth->execute();
    while ( my $item = $salesth->fetchrow_hashref() ) {
        $markdowns{ $item->{product_id} } = $item->{percentage};
    }

    # # If you want to test if a pid is going to be left out
    # # forcing markdowns on two MRP pids...
    # $markdowns{335039} = 99; #MRP
    # $markdowns{335655} = 88; #MRP
    # $markdowns{330676} = 77; #NAP - Shouldn't be skipped
    # # Or you can just insert the appropriate row into the price_adjustment
    # # table so it forces a sale on that item

    my $vat_rate    = 1;
    if ( $dc eq "DC1" ) {
        my $uk_tax  = get_invoice_country_info( $dbh, 'United Kingdom' );
        $vat_rate   = 1 + $uk_tax->{rate};
    }

    print "Got Markdowns...\n";
    foreach my $channel ( keys %{ $dcs{$dc}{accounts} } ) {

        my $account = $dcs{$dc}{accounts}{$channel};
        open (my $OUT,">:utf8", "/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/".$account->{account_number}."_nmerchandis".$short_date.".txt") || warn "Cannot open output file: $!";
        open (my $ATT_OUT,">:utf8","/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/".$account->{account_number}."_nattributes".$short_date.".txt") || warn "Cannot open output file: $!";


        # header record
        print $OUT "HDR|$account->{account_number}|$account->{short_name}|$long_date\n";
        print $ATT_OUT "HDR|$account->{account_number}|$account->{short_name}|$long_date\n";

        my $prod_sth = $dbh->prepare($prod_qry);
        $prod_sth->execute( $account->{channel_id} );

        my $record_count = 0;
        my $products_found = $prod_sth->rows();
        my $products_processed = 0;
        my $t0 = time();
        print "Checking variants in $channel ($account->{channel_id}): $products_found pids\n";

        PRODUCT: while(my $row = $prod_sth->fetchrow_hashref){
            $products_processed++;
            if($products_processed % 100 == 0){
                # For every 100 pids we'll print something
                my $elapsed = time() - $t0;
                my $time_per_pid = $elapsed/$products_processed;
                my $remaining = $time_per_pid*$products_found-$elapsed;
                printf "$channel:$dc: %d/%d, elapsed %s (%.03fs p/pid, etr: %s)\n", $products_processed, $products_found, sec2human($elapsed), $time_per_pid, sec2human($remaining);
            }
            my $product_name =  $row->{name};

            # Strip any HTML tags from the description
            my $description = $row->{long_description};
            # Temporarely strip out HTML tag this way since HTML::Strip is causing the script to die :/
            # The root cause need to be investigated.
            $description =~ s{<[^><]*>}{}g;

            # Replacing links to other products by their names only
            $description =~ s/\[(.*?)\s*id\d+\]/$1/g;

            # Replacing "shown here with" for "Wear it with"
            $description =~ s/shown here with/Wear it with/ig;

            my $designer =  $row->{designer};
            my $material =  $row->{fabric_content};
            my $keywords =  $row->{keywords};

            my $saleable = get_saleable_item_quantity ($dbh, $row->{id} );

            $queries->{variant_sth}->execute( $account->{channel_id}, $row->{id} );
            my $variant = $queries->{variant_sth}->fetchall_hashref('id');
            # $variant_sth->finish;

            my $channel_id = $account->{channel_id};

            my $size_string = '';
            my $in_stock = 0;
            foreach my $variant_id ( sort keys %{ $saleable->{$channel} } ) {
                unless ( exists ( $variant->{$variant_id} ) ) {
                    warn "No matching size info for $variant_id (pid $$row{id}) in $channel : $dc" unless $quiet;
                }
                if ($saleable->{$channel}{$variant_id} > 0) {
                    $in_stock++;
                    $size_string .= ',' unless $size_string eq "";
                    no warnings; ## no critic(ProhibitNoWarnings)
                    # only prepend if there is a 'short_name' for the size sheme
                    if ( $variant->{$variant_id}{size_scheme} ) { $size_string .= $variant->{$variant_id}{size_scheme} . ' '; }
                    $size_string .= $variant->{$variant_id}{designer_size};
                }
            }

            # don't include products with no saleable variants
            unless ($in_stock) {
                warn "Product $$row{id} has no variants in stock" unless $quiet;
            };
            if ($size_string eq "") {
                warn "Couldn't get sizes for $$row{id} : $channel : $dc" unless $quiet;
            } elsif (length ($size_string) > 128) {
                warn "Size string $size_string  for $$row{id} : $channel : $dc too big - leave empty" unless $quiet;
                $size_string = "";
            }

            if (length ($material) > 128) {
                warn "Material ".encode("utf8", $material)." for $$row{id} : $channel : $dc too big - leave empty\n"  unless $quiet;;
                $material = "";
            }


            # find the best colour to use
            my $colour = "";
            if ( $row->{colour_filter_id} ) {
                $colour = $colour_filter_ref->{ $row->{colour_filter_id} }{colour_filter};
            } elsif ( $row->{colour_id} ) {
                $colour = $colour_ref->{ $row->{colour_id} }{colour};
            } elsif ( $row->{designer_colour} ) {
                $colour = $row->{designer_colour};
            } else {
                $colour = '';
            }

            # PM-1977 Free shipping text for NAP AM
            my $shipping_info = '';
            if ( $dc eq 'DC2' && $account->{short_name} eq 'NETAPORTER' ) {
                $shipping_info = 'Free shipping and returns in the U.S.';
            }

            my $retail_price = d2( $row->{price} );
            my $currency = $row->{currency};

            if ( $dc eq 'DC1' ) {
                my $uk_price_sth = $dbh->prepare($uk_price_qry);
                $uk_price_sth->execute( $row->{id} );
                my $uk_price = $uk_price_sth->fetchrow_hashref();
                $uk_price_sth->finish;
                if ($uk_price) {
                    $retail_price = $uk_price->{price};
                    $currency = $uk_price->{currency};
                } else {
                    $retail_price = d2( $retail_price * $vat_rate );
                }
            }

            my $sale_price      = "";
            my $discount        = "";
            my $discount_type   = "";

            if ($markdowns{ $row->{id} } ){
                $sale_price     = d2( $retail_price * ((100 - $markdowns{ $row->{id} }) / 100) );
                $discount       = $markdowns{ $row->{id} };
                $discount_type  = "percentage";
            }

            $keywords =~ s/\s+/~/g;

            # removed to test with proper utf-8 encoding - reinstall if test is not
            # strip accents out of designer names
            #if ($row->{designer} =~ m/^Chlo/){ $row->{designer} = "Chloe"; }
            #if ($row->{designer} =~ m/^See by Chlo/){ $row->{designer} = "See by Chloe"; }
            #if ($row->{designer} =~ m/^Herv/){ $row->{designer} = "Herve Leger"; }
            #if ($row->{designer} =~ m/^Vanessa Bruno Ath/){ $row->{designer} = "Vanessa Bruno Athe"; }

            my $url = $account->{url};
            $url    =~ s/PRODID/$row->{id}/;
            $url    =~ s/DESIGNERNAME/$row->{url_key}/; #TODO should use url_key here?
            $url    =~ s/PRODTYPE/$row->{product_type}/;

            if ( !$designer_exclusion{$row->{designer}} ){
                my $channel_prefix = ($account->{short_name} eq 'MRPORTER') ? "_mrp" : "";
                my $website = ($account->{short_name} eq 'MRPORTER') ? "mrporter.com" : "net-a-porter.com";
                my $merch_row =  "$$row{id}|$product_name|$$row{id}|$$row{product_type}|$$row{sub_type}|$url|http://www.$website/images/products/$$row{id}/$$row{id}".$channel_prefix."_in_l.jpg||$designer $product_name|$description|$discount|$discount_type|$sale_price|$retail_price|||$designer|10|N|$keywords|Y|||$shipping_info|||$CLASS_ID|Y|Y|Y|$currency|";
                $merch_row =~ s/[\n\r]//gm;
                print $OUT $merch_row . "\n";

                my $att_row = "$$row{id}|$CLASS_ID||$$row{product_type}|$size_string|$material|$colour|$gender_map{$channel_id}||$age";
                $att_row =~ s/[\n\r]//gm;
                print $ATT_OUT $att_row . "\n";
                $record_count++;
            }
        }

        # trailer record
        print $OUT "TRL|$record_count\n";
        print $ATT_OUT "TRL|$record_count\n";

        close($OUT);
        close($ATT_OUT);

        print "Finished generating files for $dc - $channel, elapsed time: ".sec2human(time - $t0)."\n";
    }
}


sub d2 {
        my $val = shift;
        my $n = sprintf("%.2f", $val);
        return $n;
}

sub get_lookup {

    my ($dbh, $qry) = @_;
    my $sth = $dbh->prepare( $qry );
    $sth->execute();
    my $ref = $sth->fetchall_hashref('id');
    $sth->finish;
    return $ref;

}

sub sec2human {
    my $secs = shift;
    if    ($secs >= 365*24*60*60) { return sprintf '%.1fy', $secs/(365*24*60*60) }
    elsif ($secs >=     24*60*60) { return sprintf '%.1fd', $secs/(24*60*60) }
    elsif ($secs >=        60*60) { return sprintf '%.1fh', $secs/(60*60) }
    elsif ($secs >=           60) { return sprintf '%.1fm', $secs/(60) }
    else                          { return sprintf '%.1fs', $secs }
}
