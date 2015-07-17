#!/usr/bin/env perl

# create a public sale event on the named OUTNET channel, and
# return its event ID
#
# args: [INTL|AM]
#

use NAP::policy "tt";

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Config::Local;
use XTracker::Database qw/get_database_handle/;

my $db = {
    INTL => { schema_name => 'pws_schema_OUT-Intl' },
    AM   => { schema_name => 'pws_schema_OUT-AM' },
#    APAC => { schema_name => 'pws_schema_OUT-APAC' }
};

my $channel_name = $ARGV[0];

die "must specify one of '".(join("', '",(sort keys %$db)))."' as the channel name\n"
    unless $channel_name && exists $db->{$channel_name};

my $pws_schema = get_database_handle( {
    name => $db->{$channel_name}->{schema_name}
} );

$pws_schema->storage->ensure_connected;

my $pws_dbh = $pws_schema->storage->dbh;

# Set all the event parameters!

my $event_id = _get_next_event_id($pws_dbh);

my $visible_id = "EVTPUS-".uc($channel_name)."-".$event_id;
my $title_prefix = "OUTNET TEST CLEARANCE";

my $title = "$title_prefix $event_id"; # visible_id doesn't fit into this column

$title_prefix .= " $visible_id";

my        $internal_title = "$title_prefix [internal]";
my              $subtitle = "$title_prefix [subtitle]";
my           $description = "$title_prefix [description]";
my $dont_miss_out_message = "$title_prefix [don't miss out]";

my $now = DateTime->now;
my $now_formatter = $now->set_formatter( DateTime::Format::Strptime->new( pattern => '%Y-%m-%d %H:%M:%S') );

my $now_str = ''.$now;

my ($yesterday,$tomorrow) = _get_yesterday_tomorrow_from_today($now);

my $publish_date  = "$yesterday 00:00:00";
my $announce_date = "$yesterday 00:00:00";
my $start_date    = "$yesterday 00:00:00";
my $end_date      = "$tomorrow 23:59:59";
my $close_date    = "$tomorrow 23:59:59";

# Yay! Mysterious numbers that mostly resemble flags!

my $event_type_id = 2;

my $product_visibility = {
    publish_to_announce => 1,
    announce_to_start   => 1,
    start_to_end => 2,
    end_to_close => 1,
};

my $product_page_visible = 1;
my $always_visible = 1;
my $enabled = 1;

# And other IDs that mean something, perhaps?

my $created_by = 0;
my $sponsor_id = $event_id;

# And now, it's creation time!

my $create_event_query = q{
INSERT
  INTO event_detail
(
    id,
    visible_id,
    internal_title,
    publish_date,
    announce_date,
    start_date,
    end_date,
    close_date,
    enabled,
    title,
    subtitle,
    created,
    created_by,
    last_modified,
    last_modified_by,
    event_type_id,
    product_page_visible,
    always_visible,
    publish_to_announce_visibility,
    announce_to_start_visibility,
    start_to_end_visibility,
    end_to_close_visibility,
    description,
    dont_miss_out,
    sponsor_id
)
VALUES
(
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?
);
};

my $create_query_sth = $pws_dbh->prepare($create_event_query);

$create_query_sth->execute(
    $event_id,
    $visible_id,
    $internal_title,
    $publish_date,
    $announce_date,
    $start_date,
    $end_date,
    $close_date,
    $enabled,
    $title,
    $subtitle,
    $now_str,
    $created_by,
    $now_str,
    $created_by,
    $event_type_id,
    $product_page_visible,
    $always_visible,
    $product_visibility->{publish_to_announce},
    $product_visibility->{announce_to_start},
    $product_visibility->{start_to_end},
    $product_visibility->{end_to_close},
    $description,
    $dont_miss_out_message,
    $sponsor_id
);

print STDOUT "Created outnet clearance event on $channel_name, ID = $event_id\n";

exit 0;

sub _get_next_event_id {
    my $schema = shift;

    my $sth = $schema->prepare("SELECT MAX(id)+1 AS next_id FROM event_detail;");

    $sth->execute();

    return $sth->fetchrow();
}

sub _get_yesterday_tomorrow_from_today {
    my $today = shift;

    return ($today->clone->subtract( days => 1 )->ymd,
            $today->clone->add(      days => 1 )->ymd);
}
