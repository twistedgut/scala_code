package XTracker::Script::Product::WHM3505BulkPidStorageTypeUpdate;

use NAP::policy qw/class tt/;

use Time::HiRes 'sleep';
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw( :storage_type );

extends 'XTracker::Script';
with 'XTracker::Script::Feature::Schema',
     'XTracker::Role::WithAMQMessageFactory';

sub invoke {
    my ( $self, %args ) = @_;

    my $schema = $self->schema;
    my $verbose = !!$args{verbose};

    #get pids from IWS file into an array
    my $pidfile = $args{pidfile};
    open (my $fh_pids, "<", $pidfile) or die $!;
    my @lines_pids = <$fh_pids>;
    close $fh_pids;

    my $count = 0;

    my ($sleep_length,$sleep_every) = split /\//,($args{throttle}//'0/100000');
    $sleep_length = 0 unless $sleep_length =~ m{^\d+$};
    $sleep_every = 100000 unless $sleep_every =~ m{^\d+$};

    for my $product_id ( @lines_pids ) {
        chomp $product_id;

        my $product_obj = $self->schema->resultset('Public::Product')->find($product_id);

        # warn if product not found
        if ( !$product_obj ) {
            warn "Unable to find product with pid $product_id\n";
            next;
        }

        # check if product is already oversized
        if ( $product_obj->storage_type_id && $product_obj->storage_type_id == $PRODUCT_STORAGE_TYPE__OVERSIZED ) {
            $verbose && print "Storage type is already Oversized for $product_id\n";
            next;
        }

        # update storage type to oversized in the databse
        $product_obj->update({storage_type_id => $PRODUCT_STORAGE_TYPE__OVERSIZED} ) unless $args{dryrun};
        $verbose && print "Updating storage type on xtracker database to Oversized for $product_id\n";

        # send PidUpdate message to IWS to update storage type
        my $amq = $self->msg_factory;
        $verbose && print "Sending pid update message for $product_id\n";
        try {
            $amq->transform_and_send('XT::DC::Messaging::Producer::WMS::PidUpdate', $product_obj->discard_changes)
                unless $args{dryrun};
        }
        catch {
            warn "Couldn't send message for $product_id: $_\n";
        };

        if (++$count % $sleep_every == 0) {
            printf "Sleeping $sleep_length second%s\n",
                $sleep_length == 1 ? q{} : q{s};
            sleep($sleep_length);
        }
    }

    $verbose && print "Sent $count messages to IWS\n",
                      "DONE!\n";
}

1;
