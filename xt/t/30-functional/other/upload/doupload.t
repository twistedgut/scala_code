#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

doupload.t - Tests the upload process

=head1 DESCRIPTION

Verifies the processes for uploading products and reservations to
the public website.

WARNING: This test redefines code without restoring the redefined subs

#TAGS upload shouldbeunit thirdparty needsrefactor needswork misc prl checkruncondition sql activemq

=cut

use FindBin::libs;
use Test::XTracker::RunCondition
    export => [qw( $distribution_centre $prl_rollout_phase)];

use Test::Exception;

use Data::Dump      qw( pp );
use DateTime;

use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::Data;

use XTracker::Config::Local         qw{ config_var };
use XTracker::Constants             qw{ :application };
use XTracker::Constants::FromDB     qw{ :upload_transfer_status :channel };
use XTracker::Logfile               qw{ xt_logger };
use XTracker::Database              qw{ get_database_handle xtracker_schema };
use XTracker::Image;
use XT::Domain::PRLs;
use Test::XTracker::RequiresAMQ;

BEGIN {
    use_ok('XTracker::Schema');
    use_ok('XTracker::Database',':common');
    use_ok("XT::JQ::DC::Receive::Upload::DoUpload");
}

my @stuff_to_delete;
END {
    $_->delete() for @stuff_to_delete;
}

# get a schema to query
my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema' );

my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

#
# Test Upload
#
note "TESTING: Upload";

my $nap_channel = Test::XTracker::Data->channel_for_business( name => 'nap' );
my $instance    = lc( config_var("XTracker", "instance") );


# re-define some functions to test what Web-DBH handles
# are being used by the StockManager object used in 'DoUpload',
# which is used by a function when transfering Reservations
no warnings 'redefine';

my $config_section  = $nap_channel->business->config_section;
my $stag_web_dbh    = get_database_handle( { name => "Web_${distribution_centre}_Staging_${config_section}", type => 'transaction' } );
my $live_web_dbh    = get_database_handle( { name => "Web_${distribution_centre}_Live_${config_section}", type => 'transaction' } );
my $web_dbh_touse   = $stag_web_dbh;
my $web_env         = 'staging';

my $get_web_dbh     = sub { return $web_dbh_touse };
my $get_web_env     = sub { return $web_env };
my $live_web_ref    = scalar $live_web_dbh;         # get the reference to compare later
my $xfer_reservation_count  = 0;
my $xfer_reservation_web_dbh_ref;

*XT::JQ::DC::Receive::Upload::DoUpload::get_transfer_db_handles = sub {
    return {
        dbh_source       => $_[0]->{dbh_source} || xtracker_schema->storage->dbh,
        dbh_sink         => $get_web_dbh->(),
        sink_environment => $get_web_env->(),
        sink_site        => $instance,
    };
};
*XT::JQ::DC::Receive::Upload::DoUpload::transfer_product_reservations = sub {
                    my $args    = shift;
                    $xfer_reservation_count++;
                    $xfer_reservation_web_dbh_ref   =  scalar $args->{stock_manager}->_web_dbh;         # get the reference to compare later
                    return XTracker::Comms::DataTransfer::transfer_product_reservations( $args );       # now call the original
                };

use warnings 'redefine';


# Get the latest upload date
my $ut_rs           = $schema->resultset('Upload::Transfer');
my $max_upload_id   = $ut_rs->get_column('upload_id')->max() || 0;
my $upload_transfer = $ut_rs->create( {
                                channel_id          => $nap_channel->id,
                                environment         => 'staging',
                                upload_date         => DateTime->now(),
                                dtm                 => DateTime->now(),
                                source              => "xt_$instance",
                                sink                => "pws_$instance",
                                operator_id         => $APPLICATION_OPERATOR_ID,
                                upload_id           => $max_upload_id+1,
                                transfer_status_id  => $UPLOAD_TRANSFER_STATUS__COMPLETED_SUCCESSFULLY,
                            } );
isa_ok( $upload_transfer, 'XTracker::Schema::Result::Upload::Transfer' );

push @stuff_to_delete,$upload_transfer;

note ("Upload id          = ".$upload_transfer->upload_id);
note ("upload.transfer id = ".$upload_transfer->id);

# Test that you can repeat an upload to staging
my ( $job, $pc_rs ) = create_upload_job_for_transfer( {
                                upload_transfer => $upload_transfer,
                                pid_count       => 2,
                                environment     => 'staging',
                            } );
ok( $job->_validate_pids(), 'completed upload can be repeated for staging' );
lives_ok { $job->do_the_task(); } "JOB Run for 'staging'";
# check products are still NOT 'live'
my @pc  = $pc_rs->reset->all;
foreach my $pc ( @pc ) {
    cmp_ok( $pc->live, '==', 0, "Product: " . $pc->product_id . " is STILL not 'live'" );
}
cmp_ok( $xfer_reservation_count, '==', 0, "NO Reservations were Attempted to be Transfered for 'staging'" );

# Test that you can keep uploading to staging while products are being transferred
$upload_transfer->update(
    { transfer_status_id => $UPLOAD_TRANSFER_STATUS__IN_PROGRESS }
);
ok( $job->_validate_pids(), 'upload with pids being transferred passes for staging' );

# set-up the redefined functions for 'live' context
$web_dbh_touse   = $live_web_dbh;
$web_env         = 'live';
$upload_transfer->update( { environment => 'live' } );

# Check that you can't upload to live when the transfer is in progress
( $job, $pc_rs )    = create_upload_job_for_transfer( {
                                upload_transfer => $upload_transfer,
                                pid_count       => 2,
                                environment     => 'live',
                            } );
is( $job->_validate_pids(), 0, 'upload with pids being transferred fail for live: upload_id = '.$upload_transfer->upload_id );

# now make it ok to upload for live
$upload_transfer->update(
    { transfer_status_id => $UPLOAD_TRANSFER_STATUS__UNKNOWN }
);
ok( $job->_validate_pids(), 'unknown status, upload can be done for live' );

# We need to ensure that products have a storage type for
# pid_update to work
for my $product ( $pc_rs->related_resultset('product')->all ) {
    $product->update({
        storage_type_id => $schema->resultset('Product::StorageType')
                                    ->slice(0,0)
                                    ->single
                                    ->id,
    }) unless $product->storage_type_id;

    # Set product to be available for pre-order
    $product->product_attribute->update({ pre_order => 1 });
    ok( $product->product_attribute->pre_order, 'Pre-order is turned on for product ' . $product->id );
}

{
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
lives_ok { $job->do_the_task(); } "JOB Run for 'live'";
# Check one messages sent for every product updating the URL to the live image
$xt_to_wms->expect_messages({
    messages => [map {{
        type => 'pid_update',
        details => {
            pid => $_,
            photo_url => XTracker::Image::get_images({
                product_id  => $_,
                live        => 1,
                schema      => $schema,
                business_id => $nap_channel->business_id,
            })->[0],
        },
    }} $pc_rs->get_column('product_id')->func('distinct')]
});
}

# check products are now 'live'
@pc = $pc_rs->reset->all;
foreach my $pc ( @pc ) {
    cmp_ok( $pc->live, '==', 1, "Product: " . $pc->product_id . " is now 'live'" );
}

# Check that the pre_order flag for all products has been turned off.
for my $product ( $pc_rs->related_resultset('product')->all ) {
    ok( !$product->product_attribute->pre_order, 'Pre-order flag is turned off for product ' . $product->id);
}

# If PRLs are turned on, we should've sent one message for each related SKU
# to each PRL
if ($prl_rollout_phase) {
    my @prls = XT::Domain::PRLs::get_all_prls();
    my @messages;
    foreach my $prl (@prls) {
        foreach my $pc ($pc_rs->all) {
            foreach my $variant ($pc->product->variants->all) {
                push @messages,
                {
                    '@type' => 'sku_update',
                    'path' => $prl->amq_queue,
                    details => {
                        'sku' => $variant->sku,
                        'image_url' => XTracker::Image::get_images({
                            product_id  => $variant->product_id,
                            live        => 1,
                            schema      => $schema,
                            business_id => $nap_channel->business_id,
                        })->[0],
                    },
                };
            }
        }
    }
    $xt_to_prls->expect_messages({
        messages => \@messages
    });
}


cmp_ok( $xfer_reservation_count, '==', 2, "Product Reservations WERE Attempted to be Transfered for 'live'" );
is( $xfer_reservation_web_dbh_ref, $live_web_ref, "When Transfering Reservations, StockManager used same Web-DBH as rest of Upload functions" );

# just to make sure Web handles are disconnected
$stag_web_dbh->disconnect();
$live_web_dbh->disconnect();


#
# Validate Text Transforms
#
note "TESTING: Test Transforms";

my $dbh     = $schema->storage->dbh;
my $site    = $distribution_centre eq 'DC1' ? 'intl' : 'am';
my $pids    = undef;

# get channel
my $channel = Test::XTracker::Data->get_enabled_channels()->first;

($channel,$pids) = Test::XTracker::Data->grab_products({ channel => $channel->web_name });
Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

# bullet point insertion
my $text_editors_comments = "Hello\n- some bullet point\ntest";
my $text_long_description = "Hello\n- some bullet point\ntest";
my $arguments = { source_fields => [$text_editors_comments],extra_args=> { dbh => $dbh, site => $site, product_id => $pids->[0]{pid} }};
note('XTracker::Comms::DataTransfer::src_tform_editors_comments($arguments) :'.XTracker::Comms::DataTransfer::src_tform_editors_comments($arguments));
ok( XTracker::Comms::DataTransfer::src_tform_editors_comments($arguments) eq "Hello<ul><li>some bullet point</li></ul>test","Bullet point transform responding for editors comments");
$arguments = { source_fields => [$text_long_description],extra_args=> { dbh => $dbh, site => $site, product_id => $pids->[0]{pid} }};
note('XTracker::Comms::DataTransfer::src_tform_long_description($arguments) :'.XTracker::Comms::DataTransfer::src_tform_long_description($arguments));
ok( XTracker::Comms::DataTransfer::src_tform_long_description($arguments) eq "Hello<ul><li>some bullet point</li></ul>test","Bullet point transform responding for long description");

$arguments = { source_fields => ['- some text [top id63437] \r- test \r'],extra_args=> { dbh => $dbh, site => $site, product_id => $pids->[0]{pid} }};
ok( XTracker::Comms::DataTransfer::src_tform_editors_comments($arguments) !~ /\[/,"links transformed in editors comments");
ok( XTracker::Comms::DataTransfer::src_tform_long_description($arguments) !~ /\[/,"links transformed in long description (Details)");

my $test_product = $pids->[0]{product};
$arguments = { source_fields => ['- some text [top id63437] \r- test \r'],extra_args=> { dbh => $dbh, site => $site, product_id => $pids->[0]{pid} }};
note XTracker::Comms::DataTransfer::src_tform_size_fit($arguments);
ok( XTracker::Comms::DataTransfer::src_tform_size_fit($arguments) !~ /\[/,"links transformed in size fit");


done_testing;

#---------------------------------------------------------------------

# Creates a job for the given transfer
sub create_upload_job_for_transfer {
    my ( $arg )     = @_;

    my $upload_transfer = $arg->{upload_transfer};
    my $count           = $arg->{pid_count};
    my $environment     = $arg->{environment};

    # Get pids to test - allow matching upload dates or nulls (as they default to
    # being set to the due date in the payload)
    my $pc_rs   = get_pids_matching_upload( {
                        channel_id  => $upload_transfer->channel_id,
                        count       => $count,
                    } );

    is( $pc_rs->count, $count,'got all the PIDs we wanted' );

    my $pids    = [ $pc_rs->get_column('product_id')->all ];
    my $job     = new_ok( 'XT::JQ::DC::Receive::Upload::DoUpload' => [
            payload => {
                operator_id => $APPLICATION_OPERATOR_ID,
                channel_id  => $upload_transfer->channel_id,
                upload_id   => $upload_transfer->upload_id,
                due_date    => $upload_transfer->upload_date->ymd,
                pid_count   => scalar @{ $pids },
                pids        => [ map { pid => $_ }, @{ $pids } ],
                environment => $environment,
            },
        ] );

    # Create the data fields for validation to pass
    $job->data->{prods}     = fake_upload_products( $pids, $job->payload->{channel_id} );
    $job->data->{operator}  = $APPLICATION_OPERATOR_ID;

    return ( $job, $pc_rs );
}

sub get_pids_matching_upload {
    my ( $arg )     = shift;

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
                                                channel_id                  => $arg->{channel_id},
                                                how_many                    => $arg->{count},
                                                force_create                => 1,
                                                ensure_stock_all_variants   => 1,
                                        } );

    my @prod_ids;
    foreach my $pid ( @{ $pids } ) {
        _ready_product_for_upload( $pid->{product_channel} );
        push @prod_ids, $pid->{pid};
    }

    my $pc_rs   = $schema->resultset('Public::ProductChannel')
                            ->search( {
                                    channel_id  => $arg->{channel_id},
                                    product_id  => { -in => \@prod_ids },
                                } );
    return $pc_rs;
}

# Sub to fake the same output as XTracker::Database::Product::get_products_info_for_upload
sub fake_upload_products {
    my ( $pids, $channel_id ) = @_;
    my $pid_ref;

    my $pc_rs = $schema->resultset('Public::ProductChannel')->search( {
                        product_id => { -in => $pids },
                        channel_id => $channel_id,
                    } );

    while ( my $pc = $pc_rs->next ) {
        $pid_ref->{$pc->product_id} = {
            name        => $pc->product->attribute->name,
            channel_id  => $pc->channel_id,
            upload_date => $pc->upload_date,
            live        => $pc->live,
        };
    }
    return $pid_ref;
}

# This is here to avoid breakage in XT::Common::JQ::Worker::jq_logger
sub logger {
    return xt_logger('XTracker::Comms::DataTransfer');
}

# get the product ready to pass all the checks so that it can be uploaded
sub _ready_product_for_upload {
    my ( $prod_chann )      = @_;

    my $schema  = $prod_chann->result_source->schema;
    my $dbh     = $schema->storage->dbh;
    my $product = $prod_chann->product;

    # make sure the product is not live and an empty upload date
    $prod_chann->update( {
            upload_date => undef,
            live        => 0,
        } );

    # set-up colour mappings using evals so
    # duplicates don't fail the test as a whole
    eval {
        my $sql =<<SQL
INSERT INTO colour_navigation (colour) VALUES (?)
SQL
;
        my $sth = $dbh->prepare( $sql );
        $sth->execute( $product->colour->colour );
    };

    eval {
        my $sql =<<SQL
INSERT INTO navigation_colour_mapping (colour_filter_id, colour_navigation_id, channel_id) VALUES (
    (
        SELECT  filter_colour_id
        FROM    filter_colour_mapping
        WHERE   colour_id = ?
    ),
    (
        SELECT  id
        FROM    colour_navigation
        WHERE   colour = ?
        LIMIT 1
    ),
    ?
)
SQL
;
        my $sth = $dbh->prepare( $sql );
        $sth->execute( $product->colour_id, $product->colour->colour, $prod_chann->channel_id );
    };


    return;
}

