#!/opt/xt/xt-perl/bin/perl -w

use strict;
use lib "/opt/xt/deploy/xtracker/lib";
use FindBin::libs qw( base=lib_dynamic );
use warnings;

use XTracker::Database qw( :common );
use XTracker::Comms::DataTransfer qw(:transfer_handles);
use Data::Dump qw/pp/;


use XTracker::DB::Factory::Designer;
use XTracker::DB::Factory::CMS;
use XTracker::Constants::FromDB qw(
    :channel
    :page_instance_status
    :web_content_field
    :web_content_template
    :web_content_type
);

use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Session;

my $dbh = read_handle();

# Get schema
my $schema = get_database_handle({
    name => 'xtracker_schema',
    type => 'transaction',
});

# Get the NAP channel id
my $channel = $schema->resultset('Public::Channel')->get_channel_details('NET-A-PORTER.COM');
print 'Creating shop sale left-nav for: '. pp($channel)."\n";
my $channel_id = $channel->{id};



# Get web transfer handles
my $transfer_dbh_ref = get_transfer_sink_handle({
    environment => 'live',
    channel => 'NAP',
});
# Pass the schema handle in as the source for the transfer
$transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;

# get CMS object
my $factory = XTracker::DB::Factory::CMS->new({ schema => $schema });

# get list of applicable designers
my $qry = "
SELECT p.page_key,
       i.id as instance_id,
       CASE WHEN content1.content = '' THEN content1.id
            WHEN content2.content = '' THEN content2.id
            WHEN content3.content = '' THEN content3.id
            ELSE 0
       END AS text_content_id,
       CASE WHEN content11.content = '' THEN content11.id
            WHEN content22.content = '' THEN content22.id
            WHEN content33.content = '' THEN content33.id
            ELSE 0
       END AS url_content_id
FROM designer d,
     designer_channel dc,
     web_content.page p,
     web_content.instance i,
     web_content.content content1,
     web_content.content content2,
     web_content.content content3,
     web_content.content content11,
     web_content.content content22,
     web_content.content content33
WHERE d.id = dc.designer_id
AND dc.channel_id = $channel_id
AND p.id = dc.page_id
AND p.type_id = $WEB_CONTENT_TYPE__DESIGNER_FOCUS
AND p.id = i.page_id
AND i.status_id = $WEB_CONTENT_INSTANCE_STATUS__PUBLISH
AND i.id = content1.instance_id
AND content1.field_id = $WEB_CONTENT_FIELD__LINK_1_TEXT
AND i.id = content11.instance_id
AND content11.field_id = $WEB_CONTENT_FIELD__LINK_1_URL
AND i.id = content2.instance_id
AND content2.field_id = $WEB_CONTENT_FIELD__LINK_2_TEXT
AND i.id = content22.instance_id
AND content22.field_id = $WEB_CONTENT_FIELD__LINK_2_URL
AND i.id = content3.instance_id
AND content3.field_id = $WEB_CONTENT_FIELD__LINK_3_TEXT
AND i.id = content33.instance_id
AND content33.field_id = $WEB_CONTENT_FIELD__LINK_3_URL
AND i.id NOT IN (
    SELECT instance_id
    FROM  web_content.content
    WHERE content = 'SALE'
    AND field_id in (
        $WEB_CONTENT_FIELD__LINK_1_TEXT,
        $WEB_CONTENT_FIELD__LINK_2_TEXT,
        $WEB_CONTENT_FIELD__LINK_3_TEXT
    )
)
AND d.id IN (
    SELECT designer_id
    FROM product WHERE id IN (
        SELECT product_id
        FROM product_channel
        WHERE channel_id = $channel_id
        AND visible = true
    )
    AND id IN
        ( SELECT product_id FROM price_adjustment )
    GROUP BY designer_id
)
ORDER BY p.page_key ASC
";

my $sth = $dbh->prepare($qry);
$sth->execute();

eval {
    $schema->txn_do(sub {
        while ( my $row = $sth->fetchrow_hashref() ) {
            if ($row->{text_content_id} != 0 && $row->{url_content_id} != 0){
                print $row->{page_key}."\n";

                $factory->set_content({
                    content_id       => $row->{text_content_id},
                    content          => 'SALE',
                    category_id      => q{},
                    transfer_dbh_ref => $transfer_dbh_ref,
                });

                $factory->set_content({
                    content_id       => $row->{url_content_id},
                    content          => 'http://www.net-a-porter.com/Shop/Sale/Designers/'.$row->{page_key},
                    category_id      => q{},
                    transfer_dbh_ref => $transfer_dbh_ref,
                });

                $factory->set_instance_last_updated({
                    'instance_id'      => $row->{instance_id},
                    'operator_id'      => 1,
                    'transfer_dbh_ref' => $transfer_dbh_ref,
                });
            }
        }
        $transfer_dbh_ref->{dbh_sink}->commit();
    });
};
if ($@) {
    # rollback website updates on error - XT updates rolled back as part of txn_do
    $transfer_dbh_ref->{dbh_sink}->rollback();
    die $@;
}
else {
    print "All done\n\n";
}

# disconnect website transfer handles
$transfer_dbh_ref->{dbh_source}->disconnect()
    if $transfer_dbh_ref->{dbh_source};
$transfer_dbh_ref->{dbh_sink}->disconnect()
    if $transfer_dbh_ref->{dbh_sink};

1;
