#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database qw( :common );
use XTracker::Comms::DataTransfer qw(:transfer_handles);

use XTracker::DB::Factory::Designer;
use XTracker::DB::Factory::CMS;

use XTracker::Constants::FromDB qw(
    :web_content_field
    :page_instance_status
    :web_content_type
    :web_content_template
);

my $dbh = read_handle();

# Get schema
my $schema = get_database_handle({
    name => 'xtracker_schema',
    type => 'transaction'
});
# Get web transfer handles
my $transfer_dbh_ref = get_transfer_sink_handle({
    environment => 'live',
    channel => 'NAP',
});
# Pass the schema handle in as the source for the transfer
$transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;

# Get Designer object
my $factory = XTracker::DB::Factory::Designer->new({ schema => $schema });

# Get CMS object
my $cms_factory = XTracker::DB::Factory::CMS->new({ schema => $schema });

# Set CMS field id we're updating
my $field_id = 102;

# What we're updating it to
my $content = '<a href="/Content/video#/runway-by-trend"><img src="/images/designerlanding/runwaytrenddlp.jpg" class="notes-promo" alt=" WATCH & SHOP 10 NEW SEASON TRENDS TODAY " /></a>';

my $qry = "SELECT d.designer,
                  c.id
           FROM   designer d,
                  web_content.page p,
                  web_content.instance i,
                  web_content.content c
           WHERE  d.url_key = p.page_key
           AND    p.id = i.page_id
           AND    i.id = c.instance_id
           AND    c.field_id = ?";
my $sth = $dbh->prepare($qry);
$sth->execute($field_id);

while(my $row = $sth->fetchrow_hashref){

    print $row->{designer}."\n";

    eval {
        $schema->txn_do(sub {
            $cms_factory->set_content({
                content_id       => $row->{id},
                content          => $content,
                field_id         => $field_id,
                category_id      => q{},
                transfer_dbh_ref => $transfer_dbh_ref,
            });
            $transfer_dbh_ref->{dbh_sink}->commit();
        });
    };
    if ($@) {
        # rollback website updates on error - XT updates rolled back as part of txn_do
        $transfer_dbh_ref->{dbh_sink}->rollback();
        die $@;
    }
    else {
        print "Content updated\n\n";
    }
}

$transfer_dbh_ref->{dbh_source}->disconnect()
    if $transfer_dbh_ref->{dbh_source};
$transfer_dbh_ref->{dbh_sink}->disconnect()
    if $transfer_dbh_ref->{dbh_sink};

$dbh->disconnect();
