#!/opt/xt/xt-perl/bin/perl
#
# Sync stuff to the web db after a load of fixes/changes
#

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Readonly;

use XTracker::Config::Local qw( config_var );
use XTracker::Database qw( get_database_handle );
use XTracker::Database::Channel qw( get_channels );
use XTracker::Comms::DataTransfer   qw(:transfer_handles :transfer);

# Which DC environment are we in
Readonly my $dc => config_var('DistributionCentre', 'name');
die q{Couldn't determine the DC} unless $dc;

my $channel_name = "MRP";

my $channel_id = 5;
if ($dc eq 'DC2') {
        $channel_id = 6;
}

my $dbh_xt = get_database_handle( { name => 'xtracker', type => 'transaction' } )
    || die print "Error: Unable to connect to DB";
my $schema = undef;

my $transfer_dbh_ref            = get_transfer_sink_handle({ environment => 'live', channel => $channel_name  });
$transfer_dbh_ref->{dbh_source} = $dbh_xt;

my $query = "
    select pc.product_id
    from product_channel pc, product_attribute pa
    where pc.product_id = pa.product_id and pc.channel_id = ? and pa.name is not null and pa.name != '' and pc.live = true
    order by pc.product_id
";

my $sth = $dbh_xt->prepare($query);

$sth->execute($channel_id);

while (my ($product_id) = $sth->fetchrow_array()) {

    print "Processing $product_id...\n";

    eval{

        my @fields = ('size_fit','editors_comments','long_description');
        transfer_product_data({
           dbh_ref             => $transfer_dbh_ref,
           product_ids         => $product_id,
           channel_id          => $channel_id,
           transfer_categories => 'catalogue_product',
           attributes          => \@fields,
           sql_action_ref      => { catalogue_attribute => {'insert' => 1, 'update' => 1, 'delete' => 0 } },
        });

        # only need to do size stuff for dc2, dc1 should be fine already
        if ($dc eq 'DC2') {
            my @attributes = ('SIZE_CHART_CM', 'SIZE_CHART_INCHES');
            transfer_product_data(
                {
                    dbh_ref             => $transfer_dbh_ref,
                    channel_id          => $channel_id,
                    product_ids         => $product_id,
                    transfer_categories => 'catalogue_attribute',
                    attributes          => \@attributes,
                    sql_action_ref      => { catalogue_attribute => {'insert' => 1, 'update' => 1, 'delete' => 0 } },
                }
            );
        }

        $transfer_dbh_ref->{dbh_sink}->commit();
    };

    if ($@) {
            $transfer_dbh_ref->{dbh_sink}->rollback();
            print $@."\n\n";
    }

}

$sth->finish();

$dbh_xt->rollback();
$dbh_xt->disconnect();

$transfer_dbh_ref->{dbh_sink}->disconnect();

exit;

