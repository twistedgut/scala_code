#!/opt/xt/xt-perl//bin/perl -w
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;
use Log::Log4perl qw(get_logger);

use XTracker::Database qw( get_database_handle );
use XTracker::Database::Product qw( get_product_channel get_product_channel_info create_variant set_product_standardised_sizes );
use XTracker::Database::Channel qw(get_channel);
use XTracker::Comms::DataTransfer qw(:transfer_handles :transfer :upload_transfer list_pids_to_upload set_pws_visibility set_xt_product_status);
use XTracker::Constants::FromDB qw(:pws_action);


my ($filename);

GetOptions(
    'filename=s' => \$filename,
);

if (!defined($filename)) {
    print "Usage: $0 --filename [sizes.txt] - filename consists of a comma delimitered file of product_id,size_variant_id (from fulcrum:size_scheme_variant_size.id)\n";
    exit 1;
}

my $logger = _init_logger();

# set up DC and Fulcrum db handles
my %dbh = (
    'xt_central' => get_database_handle( { name => 'Fulcrum', type => 'transaction' } ),
    'xt_dc1'     => get_database_handle( { name => 'XTracker_DC1', type => 'transaction' } ),
    'xt_dc2'     => get_database_handle( { name => 'XTracker_DC2', type => 'transaction' } ),
    'xt_dc3'     => get_database_handle( { name => 'XTracker_DC3', type => 'transaction' } ),
);

my @dcs = (
    { number => 1, short => 'INTL', website => 1 },
    { number => 2, short => 'AM',   website => 1 },
    { number => 3, short => 'APAC', website => 0 },
);

# read in data
open (my $fh, "<", $filename) or die "Cannot open input file: $!";

my $count=1;

while ( my $line = <$fh> ) {

    $logger->info('-' x 80);
    $logger->info("Processing line $count");

    chomp($line);

    my ($product_id, $size_variant_id) = split(/,/, $line);

    # skip lines not in format
    if ((!defined($product_id)) || (!defined($size_variant_id))) {
        $logger->info('Invalid line in file, skipping ..');
        next;
    }

    eval {

        # verify size id exists in fulcrum
        my $product = _fulcrum_product_details( $dbh{xt_central}, $product_id, $size_variant_id );
        $product->{name} ||= '';

        die 'Could not find product details in Fulcrum' if !$product;

        $logger->info("PID: $product->{id}, $product->{name}, SIZE: $product->{size}, DESIGNER SIZE: $product->{designer_size}");

        # create source variant n fulcrum
        my $variant_id = _create_source_variant ( $dbh{xt_central}, $product_id, $size_variant_id);

        die 'Unable to create source variant id in Fulcrum' if !$variant_id;

        $logger->info("New variant ID created $variant_id in Fulcrum");

        for my $dc (@dcs) {

            my $db = "xt_dc$dc->{number}";

            # check product in DC and web status
            my $dc_active_channel = get_product_channel( $dbh{$db}, $product_id );
            my $dc_channel_data = get_product_channel_info( $dbh{$db}, $product_id );

            if ($dc_active_channel) {

                # verify size ids exist in xt
                die "Could not find size in DC$dc->{number}" if !_verify_size_id( $dbh{$db}, $product->{size_id});
                die "Could not find designer size in DC$dc->{number}" if !_verify_size_id( $dbh{$db}, $product->{designer_size_id} );

                $logger->info("Creating variant in DC$dc->{number}");
                # create variant on DC db
                create_variant (
                        $dbh{$db},
                        $product_id,
                        {
                            'legacy_sku'        => _legacy_sku($dbh{$db},$product_id),
                            'type_id'           => 1,
                            'size_id'           => $product->{size_id},
                            'designer_size_id'  => $product->{designer_size_id},
                            'variant_id'        => $variant_id,
                        }
                );

                # safety check
                die "Variant not created in DC$dc->{number} aborting" if (!_check_variant($dbh{$db},$variant_id));

                set_product_standardised_sizes($dbh{$db},$product_id);

                $logger->info("DC$dc->{number} Active Channel - $dc_active_channel - Live = $dc_channel_data->{ $dc_active_channel }{live} , Visible = $dc_channel_data->{ $dc_active_channel }{visible} ");

            }

            # push new size to DC websites if required
            # product is live on active channel - update site
            if (($dc->{website}) && ( $dc_channel_data->{ $dc_active_channel }{live} == 1 )) {

                my $channel_data = get_channel( $dbh{$db}, $dc_channel_data->{ $dc_active_channel }{channel_id} );

                my $transfer_dbh_ref;

                $transfer_dbh_ref = get_transfer_db_handles({source_type => 'transaction', environment => 'live', channel => $channel_data->{config_section}});

                eval {
                    transfer_product_data({
                        dbh_ref             => $transfer_dbh_ref,
                        channel_id          => $dc_channel_data->{ $dc_active_channel }{channel_id},
                        product_ids         => $product_id,
                        transfer_categories => ['catalogue_sku', 'catalogue_pricing', 'catalogue_markdown'],
                        sql_action_ref      => {
                                                    catalogue_sku           => {insert => 1, update => 1},
                                                    catalogue_pricing       => {insert => 1, update => 1},
                                                    catalogue_markdown      => {insert => 1, update => 1},
                                               }
                    });

                    transfer_product_inventory({
                        dbh_ref         => $transfer_dbh_ref,
                        channel_id      => $dc_channel_data->{ $dc_active_channel }{channel_id},
                        product_ids     => $product_id,
                        new_variant     => 1,
                        sql_action_ref  => { saleable_inventory => { insert => 1, update => 1 } },
                    });

                    $transfer_dbh_ref->{dbh_sink}->commit();
                };

                if ($@) {
                    $transfer_dbh_ref->{dbh_sink}->rollback();
                    die "Could not push size to $dc->{short} website - $@";
                }
                else {
                    $logger->info("Size pushed to $dc->{short} website");
                }

                $transfer_dbh_ref->{dbh_source}->disconnect();
                $transfer_dbh_ref->{dbh_sink}->disconnect();

            }

        }
        $_->commit() foreach (values %dbh);

    };

    if ($@) {
        $logger->error("Error creating new variant ($product_id,$size_variant_id) - $@ ");
        $_->rollback() foreach (values %dbh);
    }
    else {
        $logger->info("New size variant for $product_id created");
    }

    $count++;
}

$_->disconnect() foreach (values %dbh);

sub _fulcrum_product_details {

    my ( $dbh, $product_id, $size_variant_id ) = @_;

    my $qry = '
        SELECT
            p.id,
            p.name,
            v.size_id,
            (select size from size where id = v.size_id) size,
            v.designer_size_id,
            (select size from size where id = v.designer_size_id) designer_size
        FROM
            product p,
            size_scheme_variant_size v
        WHERE
            p.id = ?
            AND v.id = ?
    ';

    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id, $size_variant_id );

    my $data = $sth->fetchrow_hashref();

    return $data;
}

sub _verify_size_id {

    my ( $dbh, $size_id ) = @_;

    my $qry = 'SELECT id FROM size WHERE id = ?';

    my $sth = $dbh->prepare($qry);
    $sth->execute( $size_id );

    return($sth->fetchrow());
}

sub _create_source_variant {

    my ( $dbh, $product_id, $size_variant_id ) = @_;

    my $var_id;

    my $qry = 'SELECT id FROM product.variant WHERE product_id = ? AND size_variant_id = ?';

    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id, $size_variant_id );

    if (!$sth->fetchrow()) {

        my $sql = 'INSERT INTO product.variant(id,product_id,size_variant_id) VALUES (default,?,?) RETURNING id';

        my $sth = $dbh->prepare($sql);
        $sth->execute( $product_id, $size_variant_id );

        my $data = $sth->fetchrow_hashref();

        if ($data->{id}) {
           $var_id = $data->{id}
        }
    } else {
        $logger->error('Variant for product_id and size_variant_id already exist!');
    }

    return $var_id;
}

sub _legacy_sku {
    my ( $dbh, $product_id ) = @_;

    my $qry = 'SELECT count(*) FROM variant WHERE product_id = ?';
    my $sku = $product_id;

    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id );

    if (my $count = $sth->fetchrow()) {
       $sku .= "_$count";
    }

    return ($sku);
}

sub _check_variant {

    my ( $dbh, $variant_id ) = @_;

    my $qry = 'SELECT id FROM variant WHERE id = ?';

    my $sth = $dbh->prepare($qry);
    $sth->execute( $variant_id );

    return ($sth->fetchrow() || 0);
}


sub _init_logger {

    my $log_conf = q(
        log4perl.category = INFO, Logfile, Screen

        log4perl.appender.Logfile = Log::Log4perl::Appender::File
        log4perl.appender.Logfile.filename = /tmp/create_variant.log
        log4perl.appender.Logfile.mode = write
        log4perl.appender.Logfile.layout = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Logfile.layout.ConversionPattern = [ %d %-5p ] %m%n

        log4perl.appender.Screen        = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Screen.layout.ConversionPattern = [ %d %-5p ] %m%n
    );

    Log::Log4perl::init( \$log_conf );
    return (get_logger());
}
