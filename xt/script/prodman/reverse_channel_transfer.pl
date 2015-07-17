#!/opt/xt/xt-perl/bin/perl
use NAP::policy;

use lib '/opt/xt/deploy/xtracker/lib';
use lib '/opt/xt/deploy/xtracker/lib_dynamic';

=head1 NAME

    reverse_channel_transfer.pl

=head1 SYNOPSIS

    sudo -u xt-web perl -I/opt/xt/deploy/xtracker/lib -I/opt/xt/deploy/xtracker/lib_dynamic reverse_channel_transfer.pl --pids 445280 445279 445275 --prefix=PM-666 --output_base_dir=/tmp

    # Or run it with no --pids and feed a list of PIDs on STDIN
    reverse_channel_transfer.pl < pids.txt

    # Or specifiy a filename containing a list of PIDs
    reverse_channel_transfer.pl pids.txt

=head1 DESCRIPTION

Build the required components for a jira ticket to reverse a channel transfer
(takes products from OUTNET back to NAP) for the specified PIDs.

This script should be run on the relevant XTDC.

As this operation requires co-ordination over multiple boxes, we're not
actually automating it (yet) but there are some ideas in the script.

=head1 USAGE

The script will print out some Jira markup on STDOUT containing the instructions
for TechOps to be copy-n-pasted into a comment.

On STDERR it will output a commentary of what it is doing, any warnings and
diagnostics and the name of a temporary directory. All of the files in the
temporary directory should be attached to the Jira ticket.

If the script doesn't find any transfer record in the XT that it's run on, it
will skip the PID in question. In some cases, this is not what you want because
transfers have been created in Fulcrum but not made it to XT. In this case, use
the --fulcrum flag and it will output the SQL needed for Fulcrum without
checking anything in XT.

=head1 LIMITATIONS / TODO

Product service is only updated with stock level changes, but really it should
have the product status changed back to 'normal' etc. too. Probably a general
broadcast from Fulcrum for each product would do it.

=head1 AUTHOR

Johnathan Swan L<johnathan.swan@net-a-porter.com>

=cut

use XTracker::Database qw( get_database_handle get_schema_using_dbh );
use XT::Warehouse;
use XTracker::Constants::FromDB qw( :business );

use Getopt::Long;
use POSIX qw( strftime );
use File::Temp qw( tempdir );
use autodie;
use File::Spec::Functions qw/ catfile /;

my ($product_id, $prefix, $output_base_dir, @pids, $fulcrum);
GetOptions(
    'pids=i{1,}' => \@pids,
    'prefix=s' => \$prefix,
    'output_base_dir=s' => \$output_base_dir,
    'fulcrum' => \$fulcrum,
);

unless ( @pids ) {
    say STDERR "Reading PIDs from input";
    while (<>) {
        chomp;
        my $line = $_;
        foreach my $number (split /\D+/, $line) {
            warn "add pid $number";
            push @pids, $number;
        }
    }
}

my $dbh = get_database_handle( { name => 'xtracker' } );
my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');

my @products;

# Hard-code to deal with reversing NAP->OUTNET channel transfers for now
# But only here, so we can try making these options and testing them
# sometime if we feel the need
my $was_transferred_from_business_id = $BUSINESS__NAP;
my $was_transferred_to_business_id = $BUSINESS__OUTNET;
my $was_transferred_to_channel = $schema->resultset('Public::Channel')->search({
    business_id => $was_transferred_to_business_id,
})->single;

my $was_transferred_from_channel = $schema->resultset('Public::Channel')->search({
    business_id => $was_transferred_from_business_id,
})->single;

say sprintf(
    "Reversing channel transfer from %s to %s for the specified products",
    $was_transferred_from_channel->name,
    $was_transferred_to_channel->name,
);

my $was_transferred_to_channel_id = $was_transferred_to_channel->id;
my $was_transferred_from_channel_id = $was_transferred_from_channel->id;

my $was_transferred_to_channel_name = $was_transferred_to_channel->name;
my $was_transferred_from_channel_name = $was_transferred_from_channel->name;

my $dc_name = $was_transferred_to_channel->distrib_centre->name;

my %transfer;

PID: foreach my $pid (@pids){
    my $product = $schema->resultset('Public::Product')->find($pid);
    unless ($product) {
        warn "No such Product with pid $pid; skipped";
        next PID;
    }
    say STDERR "Product $pid - ".$product->name;

    # Find transfer
    my $transfers_rs = $product->channel_transfers->search({
        from_channel_id => $was_transferred_from_channel_id,
    });
    if ( $transfers_rs->count > 1 ) {
         warn "Multiple transfers found for product $pid";
         next PID;
    }
    if ( $transfers_rs->count == 0 ) {
        warn "No transfers found for product $pid";
        next PID;
    }

    $transfer{$pid} = $transfers_rs->single;
}

my $num_pids = keys %transfer;

if ( $num_pids ) {

    say STDERR "Reverse channel transfers for the following $num_pids PIDs: "
        . join ", ", keys %transfer;
}
elsif ( $fulcrum ) {
    say STDERR "No transfers found in XT to reverse, but --fulcrum flag specified";
    say STDERR "Creating Fulcrum SQL";
    $transfer{$_} = undef foreach (@pids);
}
else {
    say STDERR "No transfers found in XT and --fulcrum not specified. Exit.";
    exit 0;
}

my $output_dir = tempdir(
    DIR => $output_base_dir,
    CLEANUP => 0,
    TEMPLATE => "${prefix}_XXXXXXXXXX",
);

# If this warehouse has IWS, we need to tell it about the reversal
if ( $num_pids && XT::Warehouse->has_iws ) {
    # loop through PIDs/transfers and send iws reversal messages

    open my $iws_script_fh, '>', catfile($output_dir, "${prefix}_${dc_name}_notify_iws_of_reversal.sh");

    foreach my $pid (keys %transfer) {
        say STDERR "Send IWS reversal message for pid $pid";
        my $channel_transfer_id = $transfer{$pid}->id;
        say $iws_script_fh "sudo -u xt-web /opt/xt/xt-perl/bin/perl -I/opt/xt/deploy/xtracker/lib -I/opt/xt/deploy/xtracker/lib_dynamic /opt/xt/deploy/xtracker/script/iws_utils/rev_channel_transfer.pl --transfer_id $channel_transfer_id";
    }

    $iws_script_fh->close;
}

if ( $num_pids ) {
    open my $xtdb_script_fh, '>',  catfile($output_dir, "${prefix}_${dc_name}_reverse_channel_transfer_xt_db.sql");
    say STDERR "Reverse channel transfer in XT DB";
    $xtdb_script_fh->print( mk_xt_sql(keys %transfer) );
    $xtdb_script_fh->close();
}

open my $fulcrum_script_fh, '>', catfile($output_dir, "${prefix}_${dc_name}_reverse_channel_transfer_fulcrum_db.sql");
say STDERR "Reverse channel transfer in Fulcrum DB";
$fulcrum_script_fh->print( mk_fulcrum_sql(keys %transfer) );
$fulcrum_script_fh->close;

    # HACK
    my $web_db_name = $was_transferred_to_channel->web_name;
    $web_db_name =~ s/-/_/g;
    $web_db_name =~ s/NAP/ice_netaporter/;
    $web_db_name =~ s/OUTNET/OUT/;
    $web_db_name = lc $web_db_name;

if ( $num_pids ) {
    open my $webdb_script_fh, '>', catfile($output_dir, "${prefix}_${dc_name}_reverse_channel_transfer_web_db.sql");
    say STDERR "Reverse channel transfer in Web DB (remove stock from $was_transferred_to_channel_name)";
    print $webdb_script_fh mk_webdb_sql($web_db_name, keys %transfer);
    $webdb_script_fh->close;

    open my $prodserv_script_fh, '>', catfile($output_dir, "${prefix}_${dc_name}_prodserv_sync.sh");
    say STDERR "Reverse channel transfer in product service (update stock levels)";
    print $prodserv_script_fh mk_prodserv_sql(keys %transfer);
    close $prodserv_script_fh;
}

# TODO: Output tech ops instructions to STDOUT
say "TechOps instructions markdown (paste into Jira --- cut here ---";
say mk_techops_instructions();
say "--- cut here ---";


say STDERR "Done. Scripts in $output_dir should be attached to the ticket.";
# say STDERR "Will wait 1 hour before cleaning up the $output_dir...";

# sleep 3600;

say STDERR "Cleaning up... Goodbye";

sleep 10;

# Output dir should auto-cleanup

sub mk_techops_instructions {

    my $dc = lc $was_transferred_to_channel->distrib_centre->name;
    my $xt_box = "xtweb01.$dc.nap";
    my $xt_db_name = $dbh->{Name};
    $xt_db_name =~ s/\A.*dbname=//;
    $xt_db_name =~ s/;.*\z//;


    my @steps;
    if ( $num_pids && XT::Warehouse->has_iws ) {
        push @steps, {
            target => $xt_box,
            script => "notify_iws_of_reversal.sh",
            when => 'TODAY',
        };
    }

    push @steps, {
        target => $xt_db_name,
        script => "reverse_channel_transfer_xt_db.sql",
        when => 'TODAY',
    } if $num_pids;

    push @steps, {
        target => 'xt_central',
        script => 'reverse_channel_transfer_fulcrum_db.sql',
        when => 'TODAY',
    };

    push @steps, {
        target => $web_db_name,
        script => "reverse_channel_transfer_web_db.sql",
        when => 'TODAY',
    } if $num_pids;

    push @steps, {
        target => $xt_box,
        script => "prodserv_sync.sh",
        when => 'TODAY',
    } if $num_pids;

    my $steps_markup = "";
    my $n = 1;
    foreach my $step ( @steps ) {
        my $markup = sprintf(<<'STEP', $n, $step->{target}, $prefix, $dc_name, $step->{script});
\\
(*r)
|{color:#800000}*TARGET %s:*{color} | %s |
|{color:#800000}*SCRIPT:*{color} |  [^%s_%s_%s] |
|{color:#800000}*WHEN:*{color} | *TODAY* |

\\
\\

STEP
        $steps_markup .= $markup;
        $n++;
    }

    return sprintf(<<'EOTOI', $steps_markup);

{panel: borderStyle=solid}{color:white}{panel:title=INSTRUCTIONS FOR TECH OPS : | borderStyle=solid| borderColor=#ccc| titleBGColor=#800000| bgColor=white}{color}

h2. {color:#800000}Instructions For TechOps:{color}

- Please run the scripts in the order stated below.

\\
h4. {color:#800000}Run Scripts:{color}
\\
%s
\\
h2. {color:#800000}Additional Actions Required:{color}

- Please attach any script output to the Jira ticket.

\\
\\
h2. {color:#800000}Post completion instructions:{color}

- n/a

{panel}
EOTOI
}

sub mk_prodserv_sql {
    my ( @pids ) = @_;

    my @commands;
    foreach my $pid ( @pids ) {
        push @commands, qq{sudo -u xt-web perl -I/opt/xt/deploy/xtracker/lib -I/opt/xt/deploy/xtracker/lib_dynamic  /opt/xt/deploy/xtracker/script/sync_sizes_with_ps.pl --pid $pid};
    }

    return join(qq{\n}, @commands) . "\n";
}

sub mk_webdb_sql {
    my ( $db, @pids ) = @_;

    my @statements;

    push @statements, "USE $db;";

    push @statements, "START TRANSACTION;";

    foreach my $pid (@pids) {
        push @statements, qq{UPDATE stock_location SET no_in_stock = 0 WHERE sku LIKE "$pid%";};
    }

    push @statements, "COMMIT;";

    return join(qq{\n}, @statements) . "\n";
}

sub mk_xt_sql {
    my ( @pids ) = @_;

    my $comma_separated_pids = join q{,}, @pids;

    return <<EOXTSQL;
-- $prefix - reverse channel transfers in XT

\\set pid $comma_separated_pids

BEGIN;
-- set status on NAP back from 'Transfer Requested'
UPDATE product_channel
   SET transfer_status_id = ( SELECT id FROM product_channel_transfer_status WHERE status='None' )
 WHERE product_id IN ( :pid )
   AND channel_id = ( SELECT id FROM channel WHERE name='NET-A-PORTER.COM' );


-- put stock back in NAP from Outnet
UPDATE quantity
    SET channel_id = ( SELECT id FROM channel WHERE name='NET-A-PORTER.COM' ), quantity = quantity
WHERE variant_id IN (SELECT id FROM variant WHERE product_id in ( :pid ));


-- remove the Outnet channel record created as part of the request
DELETE FROM product.stock_summary
    WHERE product_id IN ( :pid ) AND channel_id = ( SELECT id FROM channel WHERE name='theOutnet.com' );
DELETE FROM product_channel
    WHERE product_id IN ( :pid ) AND channel_id = ( SELECT id FROM channel WHERE name='theOutnet.com' );


DELETE FROM channel_transfer_pick ctp
    WHERE ctp.channel_transfer_id IN
        (SELECT id FROM channel_transfer WHERE
            product_id IN ( :pid ) AND
            from_channel_id = (SELECT id FROM channel WHERE name='NET-A-PORTER.COM') AND
            to_channel_id  = (SELECT id FROM channel WHERE name='theOutnet.com')
        );

DELETE FROM channel_transfer_putaway ctp
    WHERE ctp.channel_transfer_id IN
        (SELECT id FROM channel_transfer WHERE
            product_id IN ( :pid ) AND
            from_channel_id = (SELECT id FROM channel WHERE name='NET-A-PORTER.COM') AND
            to_channel_id  = (SELECT id FROM channel WHERE name='theOutnet.com')
        );

DELETE FROM  log_channel_transfer lct
    WHERE lct.channel_transfer_id IN
        (SELECT id FROM channel_transfer WHERE
            product_id IN ( :pid ) AND
            from_channel_id = (SELECT id FROM channel WHERE name='NET-A-PORTER.COM') AND
            to_channel_id  = (SELECT id FROM channel WHERE name='theOutnet.com'));

DELETE FROM log_pws_stock where variant_id in (select id from variant where product_id IN (:pid)) and channel_id=(select id from channel where business_id=(select id from business where config_section='OUTNET'));

DELETE FROM channel_transfer
    WHERE product_id IN ( :pid ) AND
    from_channel_id = (SELECT id FROM channel WHERE name='NET-A-PORTER.COM') AND
    to_channel_id  = (SELECT id FROM channel WHERE name='theOutnet.com');

COMMIT;
EOXTSQL
}

sub mk_fulcrum_sql {
    my ( @pids ) = @_;

    my $comma_separated_pids = join q{,}, @pids;

    # HACK HACK HACKEDY HACK
    # Fulcrumification of the names...
    my $was_transferred_from_channel_fulcrum_name = $was_transferred_from_channel->web_name;
    my $was_transferred_to_channel_fulcrum_name = $was_transferred_to_channel->web_name;
    for ( $was_transferred_from_channel_fulcrum_name, $was_transferred_to_channel_fulcrum_name ) {
        s/OUTNET/Outnet/;
        s/-/ /;
        s/INTL/Intl/;
    }

    return <<EOFULSQL;
-- $prefix - reverse channel transfers in Fulcrum

\\set pid $comma_separated_pids

\\set source_channel_name '''$was_transferred_from_channel_fulcrum_name'''
\\set target_channel_name '''$was_transferred_to_channel_fulcrum_name'''


BEGIN;

-- Revert Trf Status of Product
DELETE FROM product.transfer WHERE source_product_channel_id IN (
    SELECT id FROM product.product_channel
     WHERE product_id IN (:pid)
       AND channel_id = ( SELECT id FROM channel WHERE name=:source_channel_name )
);

-- FK list.item
DELETE FROM list.item WHERE (list_id, product_channel_id) IN (
    SELECT list_id,
           id
     FROM product.product_channel
    WHERE product_id IN (:pid)
      AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name )
);

-- FK product.landing_price
DELETE FROM product.landing_price WHERE product_channel_id IN (
    SELECT id
      FROM product.product_channel
     WHERE product_id IN (:pid)
       AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name )
);

-- FK price_country_override
DELETE FROM product.price_country_override WHERE product_channel_id IN (
    SELECT id
      FROM product.product_channel
     WHERE product_id IN (:pid)
       AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name )
);

-- FK price_default
DELETE FROM product.price_default WHERE product_channel_id IN (
    SELECT id
      FROM product.product_channel
     WHERE product_id IN (:pid)
       AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name )
);

-- FK price_region_override
DELETE FROM product.price_region_override WHERE product_channel_id IN (
    SELECT id
      FROM product.product_channel
     WHERE product_id IN (:pid)
       AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name )
);

-- FK product_attribute
DELETE FROM product_attribute WHERE product_channel_id IN (
    SELECT id
      FROM product.product_channel
     WHERE product_id IN (:pid)
       AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name )
);

-- Remove from markdowns
DELETE FROM product.markdown WHERE product_channel_id IN (
    SELECT id
      FROM product.product_channel
     WHERE product_id IN (:pid)
       AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name )
);

-- Remove from the stock_summary table
DELETE FROM product.stock_summary
    WHERE product_id IN (:pid) AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name );

-- Remove from the stock_summary_history table
DELETE FROM product.stock_summary_history WHERE product_channel_id IN (
    SELECT id
      FROM product.product_channel
     WHERE product_id IN (:pid)
       AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name )
);

-- Remove buying.product_channel record
DELETE FROM buying.product_channel WHERE product_channel_id IN (
    SELECT id
      FROM product.product_channel
     WHERE product_id IN (:pid)
       AND channel_id = ( SELECT id FROM channel WHERE name= :target_channel_name )
);

-- Remove product.product_navigation_tag record
DELETE FROM product.product_navigation_tag
	WHERE product_id IN (:pid) AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name );

-- Remove product.wearitwith for the product
DELETE FROM product.wearitwith
	WHERE product_id IN (:pid) AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name );

-- Remove product.wearitwith for the product on other wearitwiths
DELETE FROM product.wearitwith
	WHERE wearitwith_product_id IN (:pid) AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name );

-- Remove product.lifecycle_event for the product
DELETE FROM product.lifecycle_event WHERE product_channel_id IN (
    SELECT id
      FROM product.product_channel
     WHERE product_id IN (:pid)
       AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name )
);

-- The ultimate query now...
DELETE FROM product.product_channel
    WHERE product_id IN (:pid) AND channel_id = ( SELECT id FROM channel WHERE name=:target_channel_name );

COMMIT;
EOFULSQL
}
