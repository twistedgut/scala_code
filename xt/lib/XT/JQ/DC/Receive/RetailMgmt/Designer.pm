package XT::JQ::DC::Receive::RetailMgmt::Designer;

use Moose;
use Moose::Util::TypeConstraints;

use MooseX::Types::Moose                qw( Str Int ArrayRef Bool);
use MooseX::Types::Structured           qw( Dict Optional );

use Data::Dump qw/pp/;

use XTracker::Config::Local             qw( create_cms_page_channels );
use XTracker::Constants                 qw( :application );
use XTracker::Comms::DataTransfer       qw( :transfer_handles );
use XTracker::DB::Factory::Designer;

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';



has payload => (
    is  => 'ro',
    isa => ArrayRef[
        Dict[
            action              => enum([qw/add update/]),
            designer_id         => Int,
            designer_name       => Str,
            designer_name_new   => Optional[Str], # update only

            url_key             => Optional[Str], # not optional on addition
            supplier_code       => Optional[Str],
            supplier_name       => Optional[Str],

            channel => Optional[ # not optional on addition
                ArrayRef[
                    Dict[
                        channel_id  => Int,
                        visibility  => Optional[Str], # not optional on addition
                        description => Optional[Str],
                        categories  => Optional[ArrayRef[Str]],
                    ],
                ],
            ],
        ],
    ],
    required => 1,
);


sub check_job_payload {
    my ($self, $job) = @_;
    my $payload = $self->payload;

    my $errors;
    ITEM:
    foreach my $item (@$payload){
        if ($item->{action} eq 'add' ){
            if ($item->{designer_name_new}){
                push @$errors, "designer_name_new param should only by used for designer updates, not when creating a new designer";
            }
            unless ($item->{url_key}){
                push @$errors, "Must have a url_key for designer '". $item->{designer_name} ."'";
            }
            # makes no sense to add a designer with no channel data
            unless ($item->{channel}){
                push @$errors, "No channelisation found for addition of designer '" . $item->{designer_name} . "'";
                next ITEM;
            }
            foreach my $chan (@{$item->{channel}}){
                push @$errors, "No visibility defined for designer '" . $item->{designer_name} . "' on channel " . $chan->{channel_id} unless defined $chan->{visibility};
            }
        }

    }
    return (join(', ', @$errors)) if $errors;
    return ();
}


sub do_the_task {
    my ($self, $job)    = @_;

    my $schema                  = $self->schema;
    my $channels = $schema->resultset('Public::Channel')
        ->enabled_channels_with_public_website();

    my $des_factory             = XTracker::DB::Factory::Designer->new({ schema => $schema });
    my $designer_cms_configs    = create_cms_page_channels();  # get a list of config sections that should create a CMS page
    my %web_dbhs;
    my $cant_talk_to_web = 0;
    my @envs = qw(live staging);

    eval {
        # get website dbh (and some other stuff in the 'sink handler')
        foreach my $cid (keys %$channels){
            foreach my $env (@envs){
                my $business = $channels->{$cid}{config_section};

                eval {
                    $web_dbhs{$cid}->{$env} = get_transfer_sink_handle({
                        environment => $env,
                        channel => $business,
                    });
                };
                if ($@ || !defined $web_dbhs{$cid}->{$env}->{dbh_sink}){
                    $cant_talk_to_web   = 1;
                    die "Can't Talk to $env Web Site for Channel ".$cid." ("
                        .$business.") - ".$@;
                }
                $web_dbhs{$cid}->{$env}->{dbh_source} = $schema->storage->dbh;
            }
            $web_dbhs{$cid}->{create_page} = (grep { $_ eq $channels->{$cid}{config_section} } @$designer_cms_configs) ? 1 : 0;
        }

        # do the updates
        $schema->txn_do( sub {
            ITEM:
            foreach my $item ( @{ $self->payload } ) {

                if ($item->{action} eq 'add'){
                    # create designer record
                    my $designer_id = $des_factory->create_designer({
                        designer_id   => $item->{designer_id},
                        designer_name => $item->{designer_name},
                        url_key       => $item->{url_key},
                        supplier_code => $item->{supplier_code},
                        supplier_name => $item->{supplier_name},
                    });

                    foreach my $dchan ( @{$item->{channel}} ){
                        my $cid = $dchan->{channel_id};
                        next unless $channels->{$cid}; # channel not in this DC - not our concern.

                        my $visibility   = $schema->resultset('Designer::WebsiteState')->search( {state => $dchan->{visibility}} )->first;
                        die("Website visibility state " . $dchan->{visibility} . " not recognised") unless $visibility;

                        # create designer channel, all accociated CMS page stuff (if required) and nav tree stuff
                        $des_factory->create_designer_channel({
                            designer_id                 => $designer_id,
                            channel_id                  => $cid,
                            create_page                 => $web_dbhs{$cid}->{create_page},
                            designer_name               => $item->{designer_name},
                            url_key                     => $item->{url_key},
                            visibility_id               => $visibility->id,
                            description                 => $dchan->{description},
                            categories                  => $dchan->{categories},
                            operator_id                 => $APPLICATION_OPERATOR_ID,
                            transfer_dbh_ref            => $web_dbhs{$cid}->{live},
                            staging_transfer_dbh_ref    => $web_dbhs{$cid}->{staging},
                        });
                    }
                }

                elsif ($item->{action} eq 'update') {
                    my $designer = $schema->resultset('Public::Designer')->search( { 'designer' => $item->{designer_name} } )->first;
                    die ("Can't find designer $item->{designer_name} to update") unless $designer;

                    my $url_key_old       = $designer->url_key;
                    my $designer_name_old = $designer->designer;

                    # update designer
                    $des_factory->update_designer({ designer_id     => $designer->id,
                                                    new_name        => $item->{designer_name_new},
                                                    url_key         => $item->{url_key},
                                                    supplier_name   => $item->{supplier_name},
                                                    supplier_code   => $item->{supplier_code}, });

                    # update all channels on this dc
                    foreach my $cid ( keys %$channels ){
                        my $dchan;
                        foreach my $updachan ( @{$item->{channel}} ){
                            $dchan = $updachan if $updachan->{channel_id} == $cid;
                        }

                        my $visibility_id;
                        if ($dchan->{visibility}){
                            my $visibility = $schema->resultset('Designer::WebsiteState')->search( {state => $dchan->{visibility}} )->first;
                            die("Website visibility state " . $dchan->{visibility} . " not recognised") unless $visibility;
                            $visibility_id = $visibility->id;
                        }

                        $des_factory->update_designer_channel({
                            designer_id                 => $designer->id,
                            channel_id                  => $cid,
                            designer_name_new           => $item->{designer_name_new},
                            designer_name_old           => $designer_name_old,
                            url_key_old                 => $url_key_old,
                            url_key                     => $item->{url_key},
                            visibility_id               => $visibility_id,
                            description                 => $dchan->{description},
                            categories                  => $dchan->{categories},
                            operator_id                 => $APPLICATION_OPERATOR_ID,
                            transfer_dbh_ref            => $web_dbhs{$cid}->{live},
                            staging_transfer_dbh_ref    => $web_dbhs{$cid}->{staging},
                        });

                    }
                }


            }
        });
        # commit all the changes
        foreach my $env (@envs){
            $web_dbhs{$_}->{$env}->{dbh_sink}->commit() foreach keys %web_dbhs;
            $web_dbhs{$_}->{$env}->{dbh_sink}->disconnect() foreach keys %web_dbhs;
        }
    };
    if (my $err = $@){
        # rollback & disconnect for the web
        foreach my $cid (keys %web_dbhs){
            foreach my $env (@envs){
                next unless $web_dbhs{$cid}->{$env}->{dbh_sink};
                $web_dbhs{$cid}->{$env}->{dbh_sink}->rollback();
                $web_dbhs{$cid}->{$env}->{dbh_sink}->disconnect();
            }
        }

        my %exceptions  = (
            'Deadlock'      => 'retry'
        );

        my $action  = "die";
        foreach my $exception ( keys %exceptions ) {
            $action = $exceptions{$exception} if ( $err =~ /$exception/ )
        }
        if ( $action eq "retry" || $cant_talk_to_web ) {
            $job->failed( $err );
        }
        else {
            die $err;
        }
    }
}

1;


=head1 NAME

XT::JQ::DC::Receive::RetailMgmt::Designer - Add/edit designers

=head1 DESCRIPTION

This message is sent via the Fulcrum Send::RetailMgmt::Designer message when designers are added/updated

Expected Payload should look like:

ArrayRef[
    Dict[
        action              => enum([qw/add update/]),
        designer_name       => Str,
        designer_name_new   => Optional[Str], # update only

        url_key             => Optional[Str], # not optional on addition
        supplier_code       => Optional[Str],
        supplier_name       => Optional[Str],

        channel => Optional[ # not optional on addition
            ArrayRef[
                Dict[
                    channel_id  => Int,
                    visibility  => Optional[Str], # not optional on addition
                    description => Optional[Str],
                    categories  => Optional[ArrayRef[Str]],
                ],
            ],
        ],
    ],
],
