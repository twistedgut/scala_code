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
select p.page_key, i.id as instance_id, case when content1.content = '' then content1.id when content2.content = '' then content2.id when content3.content = '' then content3.id else 0 end as text_content_id, case when content11.content = '' then content11.id when content22.content = '' then content22.id when content33.content = '' then content33.id else 0 end as url_content_id  
from designer d, web_content.page p, web_content.instance i, web_content.content content1, web_content.content content2, web_content.content content3, web_content.content content11, web_content.content content22, web_content.content content33 
where p.type_id = 16 
and p.id = i.page_id
and i.status_id = 2
and i.id = content1.instance_id
and content1.field_id = 72
and i.id = content11.instance_id
and content11.field_id = 73
and i.id = content2.instance_id
and content2.field_id = 74
and i.id = content22.instance_id
and content22.field_id = 75
and i.id = content3.instance_id
and content3.field_id = 76
and i.id = content33.instance_id
and content33.field_id = 77
and i.id not in (select instance_id from web_content.content where lower(content) = 'shop the collection')
and p.page_key = d.url_key
and d.id in (select designer_id from product where id in (select product_id from product_channel where channel_id = (select id from channel where name = 'NET-A-PORTER.COM') and live = true and visible = true) and id not in (select product_id from price_adjustment) group by designer_id)
order by p.page_key asc
--limit 1
";
my $sth = $dbh->prepare($qry);
$sth->execute();

eval {
    $schema->txn_do( sub {

                         while ( my $row = $sth->fetchrow_hashref() ) {

                             if ($row->{text_content_id} != 0 && $row->{url_content_id} != 0) {

                                 print $row->{page_key}."\n";

                                 $factory->set_content( 
                                     {
                                         'content_id' => $row->{text_content_id}, 
                                         'content' => 'Shop the collection', 
                                         'category_id' => '', 
                                         'transfer_dbh_ref' => $transfer_dbh_ref }
                                 );

                                 $factory->set_content(
                                     {
                                         'content_id'            => $row->{url_content_id},
                                         'content'               => 'http://www.net-a-porter.com/Shop/Designers/'.$row->{page_key}.'/All',
                                         'category_id'           => '',
                                         'transfer_dbh_ref'      => $transfer_dbh_ref }
                                 );

                                 $factory->set_instance_last_updated( 
                                     {
                                         'instance_id' => $row->{instance_id}, 
                                         'operator_id' => 1, 
                                         'transfer_dbh_ref' => $transfer_dbh_ref }
                                 );

                             }
                         }

                         $transfer_dbh_ref->{dbh_sink}->commit();
                     } );

};

if ($@) {
    # rollback website updates on error - XT updates rolled back as part of txn_do
    $transfer_dbh_ref->{dbh_sink}->rollback();

    die $@;
}

# disconnect website transfer handles
$transfer_dbh_ref->{dbh_source}->disconnect() if $transfer_dbh_ref->{dbh_source};
$transfer_dbh_ref->{dbh_sink}->disconnect() if $transfer_dbh_ref->{dbh_sink};



1;
