#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Constants::FromDB qw(
                                      :authorisation_level
                                      :flow_status
                              );
use XTracker::Database qw ( :common );
use XTracker::Config::Local qw( iws_location_name );

# KEEP THIS IN SYNC WITH dump_dc.sh !
my @statuses=($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
              $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS);

my $schema = get_database_handle(
    {
        name    => 'xtracker_schema',
        type    => 'transaction',
    }
);

$schema->txn_do(sub {

my $iws_loc = $schema->resultset('Public::Location')->find_or_create({
    location => iws_location_name(),
    type_id => 1,
});
{
$iws_loc->delete_related('location_allowed_statuses');
for my $status (@statuses) {
    $iws_loc->create_related('location_allowed_statuses',{
        status_id => $status,
    });
}
}

my $in_q_rs = $schema->resultset('Public::Quantity')->search({
    'location.location' => { -like => '0%' },
    'me.status_id' => { -in => \@statuses },
},{
    join => 'location',
});

my $out_q_rs = $schema->resultset('Public::Quantity')->search({
    location_id => $iws_loc->id,
});

while (my $in_q = $in_q_rs->next) {
    my %spec = (
        variant_id => $in_q->variant_id,
        status_id => $in_q->status_id,
        channel_id => $in_q->channel_id,
    );
    my $out_q = $out_q_rs->search(\%spec)->single;
    if ($out_q) {
        $out_q->update({
            quantity => ($out_q->quantity + $in_q->quantity),
        });
    }
    else {
        $out_q_rs->create({%spec,quantity => $in_q->quantity});
    }
    $in_q->delete;
}

$schema->resultset('Public::LocationAllowedStatus')->search({
    'location.location' => { -like => '0%' },
    'status_id' => { -in => \@statuses },
},{
    join => 'location',
})->delete();

});
