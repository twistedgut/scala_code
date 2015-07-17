#!/usr/bin/env perl
use NAP::policy "tt";
use XTracker::Database ();
use XTracker::Role::WithAMQMessageFactory ();
use DateTime::Format::Pg;
use Data::Printer;

my $msg_factory = XTracker::Role::WithAMQMessageFactory->build_msg_factory;
my $schema = XTracker::Database::schema_handle();
my $dbh = $schema->storage->dbh;

say "Getting upload timestamps...";

my $upload_ts = $dbh->selectall_arrayref(
    q{SELECT tl.product_id as product_id,t.channel_id as channel_id,max(tl.dtm) as timestamp
      FROM upload.transfer t
      JOIN upload.transfer_log tl ON tl.transfer_id=t.id
      WHERE tl.transfer_log_action_id=1
       AND tl.level != 'error'
       AND t.environment='live'
      GROUP BY tl.product_id,t.channel_id},
    { Slice => {} },
);

say "Grouping uploads...";

my %upload_map;
for my $upload_pc (@$upload_ts) {
    my $dtm=DateTime::Format::Pg->parse_timestamp_with_time_zone(
        $upload_pc->{timestamp},
    );
    $dtm->set_time_zone('UTC');

    # round to the next half-hour, to send fewer messages
    my $step = 60-$dtm->second;
    $dtm->add(seconds=>$step);
    $step = 60-$dtm->minute;
    if ($step>=30) { $step -= 30 }
    $dtm->add(minutes=>$step);

    my $dtm_string = $dtm->iso8601.'Z';
    push @{$upload_map{$dtm_string}},{
        product_id=>$upload_pc->{product_id},
        channel_id=>$upload_pc->{channel_id},
    };
}

say "Sending messages...";

while (my ($timestamp,$pc_aref) = each %upload_map) {

    say "  $timestamp";

    $msg_factory->transform_and_send(
        'XT::DC::Messaging::Producer::ProductService::MassSetField',
        {
            products => $pc_aref,
            fields => {
                upload_timestamp => $timestamp,
            },
            # yes, this has to be set. upload_timestamp is not
            # env-dependent, but we want to make sure that, if the
            # document has live values, both staging and live get
            # updated in Solr
            live => 1,
        },
    );

    say "  sleeping two minutes";
    sleep 120;
}

say "Done.";
