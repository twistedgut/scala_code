#!/usr/bin/env perl

# add one or more PIDs to the specified event on the named OUTNET channel
#
#
# args: [INTL|AM|APAC] event-id pids....
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

my ($channel_name,$event_id,@pids)=@ARGV;

die "must specify one of '".(join("', '",(sort keys %$db)))."' as the channel name\n"
    unless $channel_name && exists $db->{$channel_name};

die "must specify a valid event ID\n"
    unless defined $event_id && $event_id =~ m{^\d+$};

my @valid_pids = grep { /^\d+(?:-\d+)?$/ } @pids;

die "must provide at least one PID\n"
    unless @valid_pids;

my $pws_schema = get_database_handle( {
    name => $db->{$channel_name}->{schema_name}
} );

$pws_schema->storage->ensure_connected;

my $pws_dbh = $pws_schema->storage->dbh;

my $insert_query = q{
INSERT
  INTO event_product(
    event_id,
    product_id
)
VALUES (
    ?,
    ?
)
};

my $insert_query_sth = $pws_dbh->prepare($insert_query);

my $status = 0;

PID:
foreach my $pid (@valid_pids) {
    # done separately so that one broken PID doesn't b0rk the whole thing
    # handle SKUs as well, but only pull the pid out

    unless ( $pid =~ m{^(?<pid>\d+)(?:-\d+)?$} ) {
        print STDERR "Couldn't not extract a PID from '$pid' -- SKIPPING\n";

        next PID;
    }

    eval {
        $insert_query_sth->execute($event_id, $+{pid});
    };

    if (my $e = $@) {
        print STDERR "Problem adding PID '$+{pid}' to event ID '$event_id': $e\n";

        $status = 1;
    }
    else {
        print STDOUT "Added PID '$+{pid}' to event ID '$event_id'\n";
    }
}

exit $status;

