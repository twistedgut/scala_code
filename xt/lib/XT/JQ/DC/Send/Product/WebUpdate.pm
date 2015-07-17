package XT::JQ::DC::Send::Product::WebUpdate;
use feature ':5.14';
use Moose;

use Data::Dump qw/pp/;

use Moose::Util::TypeConstraints;
use MooseX::Types::Moose qw(Str Int HashRef);
use MooseX::Types::Structured qw(Dict);

use experimental 'smartmatch';
use Try::Tiny;

use namespace::clean -except => 'meta';
use XTracker::Comms::DataTransfer   qw( :transfer_handles :transfer set_pws_visibility clear_catalogue_ship_restriction );
use XTracker::Database::Channel     qw( get_channel_details );
use XTracker::Logfile               qw( xt_logger );
use XTracker::Config::Local         qw( use_optimised_upload );

extends 'XT::JQ::Worker';


has payload => (
    is  => 'rw',
    isa => Dict[
            environment         => enum(['live', 'staging']),
            product_id          => Int,
            channel             => Str,
            transfer_categories => HashRef,
    ],
    required => 1,
);

my $logger  = xt_logger();

sub check_job_payload {
    my ($self, $job) = @_;
    return ();
}

sub do_the_task {
    my ($self, $job) = @_;
    $self->update_website_data( $job );
    return;
}

sub update_website_data {
    my ($self, $job) = @_;

    my %exceptions  = (
        'Deadlock'              => 'retry',
        'Lock wait'             => 'retry',
        'server has gone away'  => 'retry',
    );

    # this is based heavily on Fulcrum's Remote::SendTo::Base
    # http://stash.vm.wtf.nap:7990/projects/BAK/repos/fulcrum/browse/lib/XT/JQ/Central/Remote/SendTo/Base.pm

    # if we find ourself in a situation where the database is unreachable, we
    # cling on to the current job as long as we can, thus preventing other
    # jobs from being picked up, and building a mountain of failed jobs

    my $attempt     = 1;
    # we'd like to retry quickly(ish) in early retries, but wait longer after
    # repeated failires
    my $sleep_time  = 10; # seconds

    # flag whether or not we want to (re)try the same job
    # default to 1 so we make the first attempt
    my $try_update  = 1;  # 'true'

    local $SIG{INT} = sub {
        # let people know what's happening
        $self->jq_logger->info(
            __PACKAGE__ . qq{ received SIGINT in website-update retry loop; exiting}
        );
        # * if we don't exit, lose the job
        # * if we just exit() we leave the job with a grabbed_until
        #
        # so we (re)set the grabbed_until value; use 0 and rely on priority to
        # make this more important
        $job->grabbed_until(0);
        # make this job more important amongst equals
        $job->priority( $job->priority() - 1 );
        # save our changes
        $job->driver->update($job);

        # if we don't exit strange things happen with the job we're in the
        # middle of (it gets completed without actually doing the work - a
        # great way to lose data and cause confusion and upset)
        exit;
    };

    # If the channel we are looking at uses optimised upload, we don't need to
    # send product updates to the WebDB so get out of here.
    #
    # Ultimately we should stop creating these jobs but I think while that's
    # still different from channel to channel I think it's easier to make these
    # jobs a no-op.
    my $channel_details = get_channel_details(
        $self->dbh,
        $self->payload->{channel}
    );

    if ( use_optimised_upload($channel_details->{config_section}) ) {
        $logger->info(sprintf(
            "Not updating WebDB for product %s for UPOP channel %s.",
            $self->payload->{product_id} // 'UNKNOWN',
            $self->payload->{channel},
        ));
        return; # Don't even try to update the webdb
    }

    # store the original process name so we can reset it if/when we exit
    # normally/successfully
    my $original_process_name = $0;

    # our processing logic is slightly different to the SendTo handling. We
    # aren't trying to insert into a remote job-queue, instead we need to be
    # on the lookout for errors updating the remote data source


  while ($try_update) {
        try {
            # this is essentially what do_the_task() was before we added the
            # holding-retry pattern

            my $transfer_dbh_ref;

            eval {
                # get web transfer handle
                $transfer_dbh_ref = get_transfer_sink_handle({
                    environment => $self->payload->{environment},
                    channel => $channel_details->{config_section}
                });
                $transfer_dbh_ref->{dbh_source} = $self->dbh;
            };
            if ($@) {
                $job->failed( $@ );
                return ();
            }

            foreach my $category ( keys %{ $self->payload->{transfer_categories} } ) {
                $logger->debug('Data Transfer Category: '.$category);

                # visibility update
                if ( $category eq 'pws_visibility' ) {
                    $logger->debug(
                          'Setting visibility for PID: '
                        . $self->payload->{product_id}
                        . ' to '
                        . $self->payload->{transfer_categories}->{$category}{'visible'}
                    );
                    set_pws_visibility({
                        dbh         => $transfer_dbh_ref->{dbh_sink},
                        product_ids => $self->payload->{product_id},
                        type        => 'product',
                        visible     => $self->payload->{transfer_categories}->{$category}{'visible'},
                    });
                }
                # ship restriction update
                elsif ( $category eq 'catalogue_ship_restriction' ) {
                    $logger->debug(
                        'Setting shipping restrictions for PID: '
                        . $self->payload->{product_id}
                    );
                    clear_catalogue_ship_restriction({
                        dbh         => $transfer_dbh_ref->{dbh_sink},
                        product_ids => $self->payload->{product_id},
                    });
                    transfer_product_data({
                        dbh_ref             => $transfer_dbh_ref,
                        channel_id          => $channel_details->{id},
                        product_ids         => $self->payload->{product_id},
                        transfer_categories => 'catalogue_ship_restriction',
                        sql_action_ref      => { catalogue_ship_restriction => {insert => 1} },
                    });
                }
                # general product data update
                else {
                    # push changed fields into an array for transfer
                    my @attributes;

                    foreach my $field ( keys %{ $self->payload->{transfer_categories}->{$category} } ) {
                        push @attributes, $field;
                        $logger->debug('Field: '.$field);
                    }

                    my %permissions;

                    if ( $category eq 'navigation_attribute' ) {
                        %permissions = ( 'insert' => 1, 'update' => 1, 'delete' => 0 );

                    # don't insert any new records in Web DB as part of this general
                    # product update - this can easily cause the product to have
                    # incomplete data set and appear in broken state on site
                    } elsif ( $category eq 'catalogue_sku' ) {
                          $logger->debug(
                              'Updating variants for PID: '
                              . $self->payload->{product_id}
                          );
                          %permissions = ( 'insert' => 0, 'update' => 1, 'delete' => 1);

                    } else {
                          %permissions = ( 'insert' => 1, 'update' => 1, 'delete' => 1 );
                    }

                    transfer_product_data({
                        dbh_ref             => $transfer_dbh_ref,
                        product_ids         => $self->payload->{product_id},
                        channel_id          => $channel_details->{id},
                        transfer_categories => $category,
                        attributes          => \@attributes,
                        sql_action_ref      => { $category => \%permissions },
                    });
                }
            }

            $transfer_dbh_ref->{dbh_sink}->commit();

            # we finished the work without raising any exceptions; should be
            # fine to flag this job as done and move on to the next one
            $try_update = 0; # false
        }
        catch {
            my $e = $_;
            # we get our desired 'undef $job_handle' from the call; anything
            # we do here is just icing on the cake
            #
            # TODO: consider emailing 'appropriate people' for certain errors

            # spew the error if we're debugging
            $self->jq_logger->debug($e);

            # no nice things with certain failures
            #
            # one error that we might be tempted to catch and sleep longer for
            # is 'could not connect to server: Connection refused' but this
            # could be the transient "where's the internet gone?" error, so we
            # DO NOT catch this, and we let the sleep_time build up if it's a
            # long running problem
            given ($e) {
                # sometimes the remote database gets caught up in itself and can't
                # keep up with being asked to be a database
                when (m{Lock wait timeout exceeded; try restarting transaction}) {
                    $self->jq_logger->warn(
                        sprintf(
                            'error="%s", product="%d"',
                            "DBD::mysql::st: Lock wait timeout exceeded",
                            $self->payload->{product_id},
                        )
                    );
                    # give the poor darling some time to recover
                    $sleep_time = 15;
                }

                # PM-3584
                default {
                    # reset the process name
                    $0 = $original_process_name; ## no critic(RequireLocalizedPunctuationVars)

                    # fail like any other borked JQ task
                    die $e;
                }
            }
        };

        # if $try_update is still 1 at this point we've hit a problem and
        # we're going to hang on to this job until it's resolved
        # This will block all the other updates behind it. This is intentional
        # and means we have one problem and a backlog instead of tens or
        # hundreds of failedjobs
        last if not $try_update;

        # getting this far means we hit an error; we may have done some extra
        # nice things in the catch{} block but these are the essential tasks
        # we always want to perform when we go into holding-retry mode
        $self->jq_logger->warn(
            sprintf(
                "problem updating website data for {product_id: %d}: attempt #%d; sleeping %ds...",
                $self->payload->{product_id},
                $attempt,
                $sleep_time
            )
        );

        # fudge the process name
        $0 = ## no critic(RequireLocalizedPunctuationVars)
            sprintf("%s [website-data-update-fail; attempt %d; sleep-delay %ds]",
                $original_process_name,
                $attempt,
                $sleep_time,
            );

        # to be safe we should increase the grabbed_until ...
        # to avoid hacky stuff, let's just increse it by the amount we're
        # sleeping for
        $job->grabbed_until( $job->grabbed_until + $sleep_time );
        $job->driver->update($job);

        sleep $sleep_time;
        # set the sleep time for our next loop
        $sleep_time = _increase_sleep_time($sleep_time, $attempt++);
    }

    # reset the process name
    $0 = $original_process_name; ## no critic(RequireLocalizedPunctuationVars)

    return;
}

sub _increase_sleep_time {
    my $sleep_time   = shift;
    my $attempt = shift;

    # let's just double after every 6 failed tries
    # 6 retries in the first minute : 10s sleep
    # 3 retries in the second minute: 20s sleep
    # one retry every 40s for 4 minutes
    # one retry every 80s for 8 minutes
    # ...
    $sleep_time *= 2
        if (0 == ($attempt % 6));

    return $sleep_time;
}

1;

=head1 NAME

XT::JQ::DC::Send::Product::WebUpdate - Push products data changes to the relevant website

=head1 DESCRIPTION

To follow.

