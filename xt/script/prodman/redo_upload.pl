#!/opt/xt/xt-perl/bin/perl
use NAP::policy;

=head1 NAME

    redo_upload.pl

=head1 SYNOPSIS

    In some cases when uploading a list of pids from XT to the WebDB the
    process fails and we get some zombie products which
    Fulcrum/XT/ProductService thinks are live but the WebDB has no idea they
    actually exist. This will result in the PID not being shown at in TON
    or MRP websites and not being able to be purchased in the NAP websites.

    To patch this issue, we need to send the upload again, so we make the PID
    unlive in the XT we're starting from and create a new DoUpload job hence
    forcing the upload process to complete.

=head1 USAGE

    sudo -u xt-web perl -I/opt/xt/deploy/xtracker/lib -I/opt/xt/deploy/xtracker/lib_dynamic redo_upload.pl -channel_id 1 -pids 445280 445279 445275 -wet_run

=head1 AUTHOR

    Nelio Nunes - L<nelio.nunes@net-a-porter.com>

=cut

use XT::JQ::DC::Receive::Upload::DoUpload;
use XTracker::Database qw( get_database_handle get_schema_using_dbh );
use XTracker::Constants qw( :application );

use Data::Printer;
use Getopt::Long;
use POSIX qw( strftime );

my ($product_id,$channel_id, $verbose, $wet_run, @pids, $force);
GetOptions(
    'channel_id=s' => \$channel_id,
    'pids=i{1,}' => \@pids,
    'verbose|v' => \$verbose,
    'wet_run' => \$wet_run,
    'force|f' => \$force
);

die("no channel given") unless $channel_id;
die("no pids given") unless scalar @pids;

say "Dry run, not commiting anything" unless ($wet_run);

my $dbh = get_database_handle( { name => 'xtracker' } );
my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');

my @products;

my $payload = {
        operator_id     =>  $APPLICATION_OPERATOR_ID, # Operator did this
        channel_id      =>  $channel_id,
        upload_id       =>  1, # Some fake upload ID
        due_date        =>  strftime("%Y-%m-%d", localtime), #Today
        pid_count       =>  0,
        pids            =>  [ ],
        environment     =>  'live',
};

foreach my $pid (@pids){
    my $product = $schema->resultset('Public::Product')->find($pid);
    die("No such Product with pid $pid") unless $product;
    say "Product $pid - ".$product->name;

    my $channelised_pid = $product->product_channel->search({channel_id=>$channel_id})->single;

    unless ($channelised_pid){
        die ("PID $pid is not in channel $channel_id - can't proceed");
    }

    unless ( $channelised_pid->live ) {
        say
            "WARNING! Product is NOT LIVE, so there's nothing we can do with it - SKIPPING $pid";
        if ($force) {
            say
                "... well, you're forcing it so we're including the PID anyway. Careful though!";
        }
        else {
            next;
        }
    }


    push @products, $product;
    push @{$payload->{pids}}, {pid => $product->id };
    $payload->{pid_count}++;

    # Make product unlive
    $channelised_pid->update({
            live        =>  0,
            upload_date =>  undef,
    }) if $wet_run;
}

say "Payload to send on JQ: ".p $payload;

# Send upload again
my $job_upload = XT::JQ::DC->new({ funcname => 'Receive::Upload::DoUpload' });
$job_upload->set_payload( $payload );
if($wet_run){
    my $result  = $job_upload->send_job();
    say "Upload Job Created, Job Id: " . $result->jobid;
}
$dbh->disconnect();
