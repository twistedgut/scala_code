#!/opt/xt/xt-perl/bin/perl -w

use strict;
use lib "/opt/xt/deploy/xtracker/lib";
use FindBin::libs qw( base=lib_dynamic );
use warnings;

use XTracker::Database qw( :common );
use XTracker::Comms::DataTransfer   qw(:transfer_handles);

use XTracker::DB::Factory::Designer;
use XTracker::DB::Factory::CMS;

use XTracker::Constants::FromDB qw( :web_content_field :page_instance_status :web_content_type :web_content_template );

use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Session;

my $dbh = read_handle();

my $schema      = get_database_handle( { name => 'xtracker_schema', type => 'transaction' } );  # get schema
my $transfer_dbh_ref                    = get_transfer_sink_handle({ environment => 'live', channel => 'NAP' });          # get web transfer handles
$transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;                  # pass the schema handle in as the source for the transfer

# get CMS object
my $factory = XTracker::DB::Factory::CMS->new({ schema => $schema });

# get list of applicable designers
my $qry = "
select p.page_key, i.id as instance_id, c.id as content_id, c.content
from designer d, web_content.page p, web_content.instance i, web_content.content c
where p.type_id = 16
and p.id = i.page_id
and i.status_id = 2
and i.id = c.instance_id
and c.field_id in (72,73,74,75,76,77)
and c.content != ''
and p.page_key = d.url_key
and (lower(c.content) like '%shop the collection%' or lower(c.content) like '%/shop/designers/%')
and d.id not in (select designer_id from product where id in (select product_id from product_channel where channel_id = (select id from channel where name = 'NET-A-PORTER.COM') and live = true and visible = true) and id not in (select product_id from price_adjustment) group by designer_id)
order by p.page_key asc
--limit 1
";
my $sth = $dbh->prepare($qry);
$sth->execute();

eval {
    $schema->txn_do( sub {

                         while ( my $row = $sth->fetchrow_hashref() ) {

                             print $row->{page_key}." - ". $row->{content}."\n";

                             $factory->set_content( 
                                 {
                                     'content_id' => $row->{content_id}, 
                                     'content' => '', 
                                     'category_id' => '', 
                                     'transfer_dbh_ref' => $transfer_dbh_ref }
                             );

                             $factory->set_instance_last_updated( 
                                 {
                                     'instance_id' => $row->{instance_id}, 
                                     'operator_id' => 1, 
                                     'transfer_dbh_ref' => $transfer_dbh_ref }
                             );

                         }

                         $transfer_dbh_ref->{dbh_sink}->commit();
                     } );

};

if ($@) {
    # rollback website updates on error - XT updates rolled back as part of txn_do
    $transfer_dbh_ref->{dbh_sink}->rollback();

    die $@;
} else {
    print "All done\n\n";
}

# disconnect website transfer handles
$transfer_dbh_ref->{dbh_source}->disconnect() if $transfer_dbh_ref->{dbh_source};
$transfer_dbh_ref->{dbh_sink}->disconnect() if $transfer_dbh_ref->{dbh_sink};



1;
