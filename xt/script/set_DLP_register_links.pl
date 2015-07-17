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
    select d.designer, d.url_key, p.page_key, i.id as instance_id, content1.id as text_content_id, content1.content as text_content, content2.id as url_content_id, content2.content as url_content
    from designer d, web_content.page p, web_content.instance i, web_content.content content1, web_content.content content2
    where p.type_id = 16
    and p.id = i.page_id
    and i.status_id = 2
    and i.id = content1.instance_id
    and content1.field_id in (72, 73, 74, 75, 76, 77)
    and lower(content1.content) like '%sign up for%'
    and i.id = content2.instance_id
    and content2.field_id in (72, 73, 74, 75, 76, 77)
    and lower(content2.content) like '%page=designerregisterinterest%'
    and p.page_key = d.url_key
    order by p.page_key asc
";
my $sth = $dbh->prepare($qry);
$sth->execute();

eval {
    $schema->txn_do( sub {

        while ( my $row = $sth->fetchrow_hashref() ) {

            print $row->{page_key}."\n";

            $factory->set_content(
                {
                    'content_id' => $row->{text_content_id},
                    'content' => 'Sign up for '.$row->{designer}.' updates',
                    'category_id' => '',
                    'transfer_dbh_ref' => $transfer_dbh_ref
                }
            );

            $factory->set_content(
                {
                    'content_id'            => $row->{url_content_id},
                    'content'               => "javascript:designerEmailUpdate('".$row->{url_key}."')",
                    'category_id'           => '',
                    'transfer_dbh_ref'      => $transfer_dbh_ref
                 }
            );

            $factory->set_instance_last_updated(
                {
                    'instance_id' => $row->{instance_id},
                    'operator_id' => 1,
                    'transfer_dbh_ref' => $transfer_dbh_ref
                }
            );

        }

        $transfer_dbh_ref->{dbh_sink}->commit();
    } );

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
$transfer_dbh_ref->{dbh_source}->disconnect() if $transfer_dbh_ref->{dbh_source};
$transfer_dbh_ref->{dbh_sink}->disconnect() if $transfer_dbh_ref->{dbh_sink};



1;
