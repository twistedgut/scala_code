#!/usr/bin/env perl

#
# Test for receive RetailMgmt Desinger jobs including
# Receive::RetailMgmt::Designer and
# Receive::RetailMgmt::DesignerCategory
#

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::Hacks::isaFunction;
use Data::Dump qw(pp);
;
use Test::MockObject;

use Test::XTracker::Data;

use XTracker::Constants::FromDB     qw{ :channel :designer_website_state };
use Test::XTracker::RunCondition iws_phase => 0, database => 'full';

BEGIN {
    use_ok('XTracker::Schema');
    use_ok('XTracker::Database',':common');

    use_ok("XT::JQ::DC::Receive::RetailMgmt::Designer");
    use_ok("XT::JQ::DC::Receive::RetailMgmt::DesignerCategory");
}

my $fake_job    = _setup_fake_job();
my $schema = xtracker_schema;
isa_ok( $schema, 'XTracker::Schema' );

#--------------- Run TESTS ---------------

_test_designer( $schema, $fake_job, 'Téèst designer 1', 1 );
_test_designer_category( $schema, $fake_job, 1 );

#--------------- END TESTS ---------------

done_testing;

#----------------------- Test Functions -----------------------

sub _test_designer {
    my $schema          = shift;
    my $fake_job        = shift;
    my $designer_name   = shift;

    my ($payload, $ret, $designer_rs, $designer, $dc_rs, $supplier);

    SKIP: {
        skip "_test_designer",1 if (!shift);

        $schema->txn_do( sub {
            # create with no url_key
            $payload = {
                action          => 'add',
                designer_id     => 99423,
                designer_name   => $designer_name,
                supplier_code   => '1234',
                supplier_name   => 'IMA supplier'
            };
            $ret = execute_designer_job( $schema, $fake_job, [ $payload ] );
            like($ret, qr/Must have a url_key for designer '$payload->{designer_name}'/, "Need URL key");

            # no channelisation info
            $payload->{url_key} = 'Teest_designer_1';
            $ret = execute_designer_job( $schema, $fake_job, [ $payload ] );
            like($ret, qr/No channelisation found for addition of designer '$payload->{designer_name}'/, "No channel details included in payload");

            # add some channelisation infor but not enough
            $payload->{channel} = [ map { channel_id => $_ },
                Test::XTracker::Data->get_web_channel_ids() ];
            $ret = execute_designer_job( $schema, $fake_job, [ $payload ] );
            like($ret, qr/No visibility defined for designer/, "Visibility is mandatory");

            # should work this time
            $payload->{channel} = [ map { channel_id => $_, visibility => 'Invisible' },
                Test::XTracker::Data->get_web_channel_ids() ];
            $ret = execute_designer_job( $schema, $fake_job, [ $payload ] );
            is($ret,undef,"Job Executed");

            # check it's in the DB
            $designer_rs = $schema->resultset('Public::Designer')->search({url_key => $payload->{url_key}});
            is($designer_rs->count, 1, 'Designer found in DB');
            $designer = $designer_rs->first;
            is($designer->suppliers->count, 1, 'got a supplier');
            $supplier = $designer->suppliers->first;
            is($supplier->description, $payload->{supplier_name}, 'supplier name updated OK');
            is($supplier->code, $payload->{supplier_code}, 'supplier code updated OK');
            note "Designer ID is '".$designer->id."'\n";

            # should have 2 designer_channel
            $dc_rs = $schema->resultset('Public::DesignerChannel')->search({designer_id => $designer->id});

            is($dc_rs->count,Test::XTracker::Data->get_web_channel_ids(),
                'got ' . Test::XTracker::Data->get_web_channel_ids()
                . ' designer channels');
            while (my $dc = $dc_rs->next){
                is ($dc->website_state_id, $DESIGNER_WEBSITE_STATE__INVISIBLE, 'designer invisible on channel '. $dc->channel_id);
            }

            # Add same details a second time. Job passes but nothing updatd
            $ret = execute_designer_job( $schema, $fake_job, [ $payload ] );
            ok(defined($ret), "Job Executed OK. Copy silently returned");
            $designer_rs = $schema->resultset('Public::Designer')->search({url_key => $payload->{url_key}});
            is($designer_rs->count, 1, 'Still just the one designer found in DB');

            # Add a third time, the id is previously used and the name is wildly different,
            # triggering an out-of-sync exception
            $payload->{designer_name} = 'Something New';
            $ret = execute_designer_job( $schema, $fake_job, [ $payload ] );
            like($ret, qr/designer ids are out of sync/, "Job failed, designer ids out of sync");

            # designer name is a unique field. should fail if a new designer with a unique, unused id
            # has the same name as another record with a different id.
            $payload->{designer_id} = '99239';
            $payload->{designer_name} = $designer_name;
            $ret = execute_designer_job( $schema, $fake_job, [ $payload ] );
            like($ret, qr/designer already exists with a different id/, "Job failed, designer name already used with different id");


            # try an update on a non-existing designer
            $payload = {
                action          => 'update',
                designer_id     => '99424',
                designer_name   => 'Téèst designer 2',
            };
            $ret = execute_designer_job( $schema, $fake_job, [ $payload ] );
            like($ret, qr/Can.*?t find designer $payload->{designer_name} to update/, "Designer doesnt exist");

            # update once which does exist
            $payload = {
                action              => 'update',
                designer_id         => '99423',
                designer_name       => 'Téèst designer 1',
                designer_name_new   => 'Test designer 2',
                url_key             => 'Test_designer_2',
                supplier_code       => '5678',
                supplier_name       => 'IMA nother supplier',
            };
            $payload->{channel} = [ map { channel_id => $_,
                visibility => 'Coming Soon',
                description => 'description ' . $_ },
                Test::XTracker::Data->get_web_channel_ids() ];

            $ret = execute_designer_job( $schema, $fake_job, [ $payload ] );
            is($ret,undef,"Job Executed OK");
            $designer_rs = $schema->resultset('Public::Designer')->search({url_key => $payload->{url_key}});
            is($designer_rs->count, 1, 'Still just the one designer found in DB');
            $designer = $designer_rs->first;
            is($designer->designer, $payload->{designer_name_new}, 'name updated OK');
            is($designer->url_key, $payload->{url_key}, 'name updated OK');

            is ($designer->suppliers->count, 1, 'Still got one supplier');
            $supplier = $designer->suppliers->first;
            is($supplier->description, $payload->{supplier_name}, 'supplier name updated OK');
            is($supplier->code, $payload->{supplier_code}, 'supplier code updated OK');

            $dc_rs = $schema->resultset('Public::DesignerChannel')->search({designer_id => $designer->id});
            while (my $dc = $dc_rs->next){
                is ($dc->website_state_id, $DESIGNER_WEBSITE_STATE__COMING_SOON, 'designer coming soon on channel '. $dc->channel_id);
                is ($dc->description, 'description ' . $dc->channel_id, 'designer description OK on channel '. $dc->channel_id);
            }



            # Done. Don't actually store any of that.
            $schema->txn_rollback();
        });
    };
}


sub _test_designer_category {
    my $schema      = shift;
    my $fake_job    = shift;

    my ($payload, $ret, $category, $category_rs, $designercat_rs, $designercat);

    my $designer_rs = $schema->resultset('Public::Designer')->search({},{order_by=> {'-desc' => 'id'}});
    my $designer1 = $designer_rs->first;
    my $designer2 = $designer_rs->next;

    SKIP: {
        skip "_test_designer_category",1 if (!shift);

        $schema->txn_do( sub {
            # create with no url_key
            $payload = {
                action      => 'add',
                name        => 'Category 1',
                channel_id  => [Test::XTracker::Data->get_web_channel_ids()]->[0],
                designers   => [$designer1->designer, $designer2->designer],
            };
            $ret = execute_designercategory_job( $schema, $fake_job, [ $payload ] );
            is($ret,undef,"Job Executed");

            # check it's in the DB
            $category_rs = $schema->resultset('Designer::Attribute')->search({ name => $payload->{name}, channel_id => $payload->{channel_id}, deleted => 0 });
            is($category_rs->count, 1, 'Category found in DB');
            $category = $category_rs->first;

            $designercat_rs = $category->designer_attribute->search({deleted=>0});
            is($designercat_rs->count, 2, 'got two designers in the category');

            # Add same details a second time. Job passes but nothing updatd
            $ret = execute_designercategory_job( $schema, $fake_job, [ $payload ] );
            is($ret,undef,"Job Executed");
            $category_rs = $schema->resultset('Designer::Attribute')->search({ name => $payload->{name}, channel_id => $payload->{channel_id}, deleted => 0 });
            is($category_rs->count, 1, 'still just one Category found in DB');



            # try an update on a non-existing designer
            $payload = {
                action      => 'update',
                name        => 'Category 2',
                channel_id  => [Test::XTracker::Data->get_web_channel_ids()]->[0],
                designers   => [],
            };
            $ret = execute_designercategory_job( $schema, $fake_job, [ $payload ] );
            like($ret, qr/cannot find category named $payload->{name} to update/, "Category doesnt exist");

            # update one which does exist
            $payload->{name}     = 'Category 1';
            $payload->{new_name} = 'Category 2';
            $ret = execute_designercategory_job( $schema, $fake_job, [ $payload ] );
            is($ret,undef,"Job Executed");
            $category_rs = $schema->resultset('Designer::Attribute')->search({ name => $payload->{new_name}, channel_id => $payload->{channel_id}, deleted => 0 });
            is($category_rs->count, 1, 'Category found in DB');
            $category = $category_rs->first;

            $designercat_rs = $category->designer_attribute->search({deleted=>0});
            is($designercat_rs->count, 0, 'designers removed from the category');


            # add one designer back in
            $payload = {
                action      => 'update',
                name        => 'Category 2',
                channel_id  => [Test::XTracker::Data->get_web_channel_ids()]->[0],
                designers   => [$designer1->designer],
            };
            $ret = execute_designercategory_job( $schema, $fake_job, [ $payload ] );
            is($ret,undef,"Job Executed");
            $designercat_rs = $category->designer_attribute->search({deleted=>0});
            is($designercat_rs->count, 1, '1 designer added to the category');
            $designercat = $designercat_rs->first;
            is($designercat->designer->designer, $designer1->designer, 'designer1 is in the category');
            is ($designercat->deleted, 0, 'And its not deleted');


            # delete category
            $payload = {
                action      => 'delete',
                name        => 'Category 2',
                channel_id  => [Test::XTracker::Data->get_web_channel_ids()]->[0],
            };
            $ret = execute_designercategory_job( $schema, $fake_job, [ $payload ] );
            is($ret,undef,"Job Executed");

            $category_rs = $schema->resultset('Designer::Attribute')->search({ name => $payload->{new_name}, channel_id => $payload->{channel_id}, deleted => 0 });
            is($category_rs->count, 0, 'Category deleted in DB');
            $category = $category_rs->first;

            # refresh from db
            $designercat->discard_changes;
            is ($designercat->deleted, 1, 'and deleted the designer category');

            # Done. Don't actually store any of that.
            $schema->txn_rollback();
        });
    };
}

#--------------------------------------------------------------

# Creates and executes a
sub create_and_execute_job {
    my ( $funcname, $schema, $fake_job, $arg ) = @_;

    eval {
        my $job = new_ok( $funcname => [ payload => $arg, schema => $schema ] );
        my $errstr = $job->check_job_payload($fake_job);
        die $errstr if $errstr;
        $job->do_the_task( $fake_job );
    };
    if ( $@ ) {
        return $@
    }

    return;
}
sub execute_designer_job {
    create_and_execute_job('XT::JQ::DC::Receive::RetailMgmt::Designer', @_);
}
sub execute_designercategory_job {
    create_and_execute_job('XT::JQ::DC::Receive::RetailMgmt::DesignerCategory', @_);
}


# setup a fake TheShwartz::Job
sub _setup_fake_job {

    my $fake    = Test::MockObject->new();
    $fake->set_isa('TheSchwartz::Job');
    $fake->set_always( completed => 1 );

    return $fake;
}

