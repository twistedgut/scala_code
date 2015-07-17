package XTracker::Script::Product::Migrate;
use NAP::policy "tt", 'class';
use Time::HiRes 'sleep';
extends 'XT::Common::Script';
with 'XTracker::Role::WithSchema';
with 'XTracker::Role::WithAMQMessageFactory';

sub invoke {
    my ($self,$args) = @_;

    my @lc;my @joins;
    if ($args->{'if-live'} or $args->{'if-staging'} or $args->{'if-visible'}) {
        @joins = (join => 'product_channel');
        if ($args->{'if-live'}) {
            push @lc,('product_channel.live'=>1);
        }
        if ($args->{'if-staging'}) {
            push @lc,('product_channel.staging'=>1);
        }
        if ($args->{'if-visible'}) {
            push @lc,('product_channel.visible'=>1);
        }
    }

    my $criteria = {@lc};

    if ($args->{'min-pid'} && !$args->{'max-pid'}) {
        $criteria->{'me.id'}={ '>=', $args->{'min-pid'}};
    }
    elsif ($args->{'max-pid'} && !$args->{'min-pid'}) {
        $criteria->{'me.id'}={ '<=', $args->{'max-pid'}};
    }
    elsif ($args->{'min-pid'} && $args->{'max-pid'}) {
        $criteria->{'me.id'}={ '-between',
                          [ $args->{'min-pid'},$args->{'max-pid'} ],
                      };
    }
    if ($args->{pid}) {
        $criteria=[$criteria,{ 'me.id' => { '-in', $args->{pid}}}];
    }

    my $product_rs = $self->schema->resultset('Public::Product')
        ->search($criteria,
                 {
                     order_by => { -asc => 'me.id' },
                     distinct => 1,
                     @joins,
                 }
             );

    my ($sleep_length,$sleep_every) = split /\//,($args->{throttle}//'0/100000');
    $sleep_length=0 unless $sleep_length=~m{^\d+(?:.\d+)?$};
    $sleep_every=100000 unless $sleep_every=~m{^\d+$};

    my $amq = $self->msg_factory;

    my $count=0;
    while ( my $product = $product_rs->next ) {
        my $pid = $product->id;
        my $pc_rs = $product->product_channel;

        while ( my $pc = $pc_rs->next ) {
            my $chid = $pc->channel_id;

            print "Checking whether to send $pid\n" if $args->{verbose};

            # Skip transfered from channels
            next if $self->schema->resultset(
                'Public::ChannelTransfer'
            )->find({product_id=>$pid,from_channel_id=>$chid});

            my $ts = $self->get_upload_timestamp($pid,$chid);

            # No timestamp, can't set it
            next unless $ts;

            print "Migrating data in the product service for ${pid}x${chid}\n"
                if $args->{verbose};

            try {

                my $payload = {
                    products => [{
                        product_id => $pid,
                        channel_id => $chid
                    }],
                    fields => {
                        upload_timestamp => $ts,
                    },
                };
                if ( $pc->is_live ) {
                    $payload->{live} = 1;
                }
                else {
                    $payload->{live} = 0;
                }

                $amq->transform_and_send('XT::DC::Messaging::Producer::ProductService::MassSetField', $payload) unless $args->{dryrun};
            }
            catch {
                warn "Couldn't send data for $pid: $_\n";
            };
            ++$count;
            if ($count>=$sleep_every) {
                $count=0;
                sleep($sleep_length);
            }
        }
    }

    print "Done.\n"
        if $args->{verbose};

    return 1; # success
}

sub get_upload_timestamp {
    my ($self,$pid,$chid) = @_;

    my $dbh = $self->dbh;

    my $timestamp;
    eval {
        $timestamp =
            $dbh->selectall_arrayref(
                q{SELECT max(tl.dtm)
                  FROM upload.transfer t
                  JOIN upload.transfer_log tl ON tl.transfer_id=t.id
                  WHERE tl.transfer_log_action_id=1
                    AND t.environment='live'
                    AND tl.product_id=? AND t.channel_id=?},
                {},
                $pid,$chid)->[0][0];
    };
    return unless $timestamp;
    my $dtm=DateTime::Format::Pg->parse_timestamp_with_time_zone($timestamp);
    $dtm->set_time_zone('UTC');
    return $dtm->iso8601.'Z';
}
