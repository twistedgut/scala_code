package XTracker::WebContent::Actions::UpdateInstance;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Utilities                 qw( portably_get_basename url_encode );
use XTracker::Image                     qw( copy_image upload_image );
use XTracker::Comms::DataTransfer       qw(:transfer_handles);
use XTracker::DB::Factory::CMS;
use XTracker::Constants::FromDB         qw( :page_instance_status );
use XTracker::Config::Local             qw( get_file_paths config_var );
use XTracker::Error;
use XTracker::Role::WithAMQMessageFactory;

sub _redirect {
    my %args = (
        handler     => undef,
        redirect    => undef,
        error_msg   => undef,
        success_msg => undef,
        @_
    );


    # tag error onto URL if we have one
    if ($args{error_msg}) {
        xt_warn($args{error_msg});
    }
    elsif ($args{success_msg}) {
        xt_success($args{success_msg});
    }

    return $args{handler}->redirect_to( $args{redirect} );
}

sub _dlp_ActiveMQ_update {

    my $rh_args =  {
            schema          => undef,
            instance_id     => undef,
            page            => undef,
            page_id         => undef,
            channel         => undef,
            handler         => undef,
            redirect        => undef,
            @_
    };

    # First find the designer of this page instance
    my $page_id = $rh_args->{page_id};
    my $designer_name = $rh_args->{schema}->resultset('WebContent::Page')->find( $page_id )->name;
    $designer_name =~ s/^Designer - //;
    my $designer_id =  $rh_args->{schema}->resultset('Public::Designer')->search( { designer => $designer_name })->first->id;

    my $factory = XTracker::Role::WithAMQMessageFactory->build_msg_factory;

    my $success =
    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::DLP::Update',
        {
            designer => $designer_id,
            channel  => $rh_args->{page}->channel_id,
        },
    ) || 'Synchronisation message sent';


    _redirect(
        handler     => $rh_args->{handler},
        redirect    => $rh_args->{redirect},
        success_msg => $success
    );


}

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $error           = "";
    my $success         = "";
    my $success_suffix  = "";

    # required post vars
    my $instance_id     = $handler->{param_of}{'instance_id'};      # id of instance we're updating
    my $redirect        = $handler->{param_of}{'redirect'};         # where to redirect back to

    # optional post vars
    my $name            = $handler->{param_of}{'name'};             # name/label
    my $status          = $handler->{param_of}{'status'};           # status name
    my $status_id       = $handler->{param_of}{'status_id'};        # status_id
    my $page_id         = $handler->{param_of}{'page_id'};          # page id of the instance we're updating

    # set website environment to live
    my $web_environment = 'live';

    my $schema          = $handler->{schema};
    my $page            = $schema->resultset('WebContent::Page')->find($page_id);
    my $channel_info    = $schema->resultset('Public::Channel')->get_channel($page->channel_id);


    if ($status && ($status =~ /^Sync to Other DC/)) {
        _dlp_ActiveMQ_update (
            handler         => $handler,
            schema          => $handler->{schema},
            instance_id     => $instance_id,
            page            => $page,
            page_id         => $page_id,
            channel         => $channel_info,
            redirect        => $redirect,
        );
    }

    # convert status to status id if required
    if ( $status ) {

        $success_suffix     = "Updated";

        if ( $status =~ /^Archive/ ) {
            $status_id      = $WEB_CONTENT_INSTANCE_STATUS__ARCHIVED;
            $success_suffix = "Archived";
        }

        if ( $status =~ /^Publish to Live/ ) {
            $status_id      = $WEB_CONTENT_INSTANCE_STATUS__PUBLISH;
            $success_suffix = "Published to Live";
        }

        if ( $status =~ /^Publish to Staging/ ) {

            # IMPORTANT: publish to staging does not change status BUT needs to switch web environment to staging otherwise we'll be updating live website
            $status_id          = $WEB_CONTENT_INSTANCE_STATUS__PUBLISH;
            $web_environment    = 'staging';
            $success_suffix     = "Published to Staging";

        }
    }

    # should have at least an instance id
    if ( $instance_id ) {


        my $transfer_dbh_ref            = get_transfer_sink_handle({ environment => $web_environment, channel => $channel_info->{config_section} });    # get web transfer handles
        my $staging_transfer_dbh_ref    = get_transfer_sink_handle({ environment => 'staging', channel => $channel_info->{config_section} });           # get staging web transfer handles

        $transfer_dbh_ref->{dbh_source}         = $schema->storage->dbh;                # pass the schema handle in as the source for the transfer
        $staging_transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;                # pass the schema handle in as the source for the transfer

        # get Category Navigation DB Factory object
        my $factory = XTracker::DB::Factory::CMS->new({ schema => $schema });

        # run updates
        eval {
            $schema->txn_do( sub {

                # update instance status
                if ( $status_id ) {
                    $factory->set_instance_status(
                                        {   'page_id'                   => $page_id,
                                            'instance_id'               => $instance_id,
                                            'status_id'                 => $status_id,
                                            'operator_id'               => $handler->operator_id,
                                            'environment'               => $web_environment,
                                            'transfer_dbh_ref'          => $transfer_dbh_ref,
                                            'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref}
                                );
                }

                # update instance content
                # we're looking for form fields named 'content_(id)'

                # loop through form fields
                foreach my $param ( keys %{ $handler->{param_of} } ) {

                    # match field name
                    if ($param =~ m/content_/) {

                        # split content id out of field name
                        my ($blank, $content_id) = split(/_/, $param);

                        my $content = $handler->{param_of}{$param};

                        # clean up content
                        $content =~ s/\r//g;
                        $content =~ s/\n//g;
                        $content =~ s/\\//g;
                        $content =~ s/\\'/\'/g;
                        $content =~ s/DQUOTE/\"/g;

                        $factory->set_content(
                                        {   'content_id'                => $content_id,
                                            'content'                   => $content,
                                            'transfer_dbh_ref'          => $transfer_dbh_ref,
                                            'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                            );

                    }

                }

                my $file_paths  = get_file_paths($channel_info->{config_section});

                # check for file uploads
                foreach my $upldfile ( $handler->{request}->upload ) {

                    if ( ( $upldfile->name =~ /\w.*_(.*)/ ) && ( $upldfile->filename ne "" ) ) {
                        my $content_id  = $1;
                        my $filename    = $upldfile->filename;
                        my $destination = $handler->{param_of}{'destination_'.$content_id};

                        # where to copy file on XT
                        my $destination_dir = $file_paths->{source_base} . $file_paths->{cms_source};

                        # get image filename
                        $filename   = portably_get_basename( $filename );
                        # tag instance id onto start of filename
                        $filename   = $instance_id.'_'.$filename;

                        # sub-folder specified
                        if ($destination) {
                            $destination_dir    .= $destination;
                        }
                        if ( $destination_dir !~ /\/$/ ) {
                            $destination_dir    .= "/";
                        }

                        # upload image to destination dir on XT
                        my ($status,$error) = upload_image($upldfile, $destination_dir, $filename);
                        if ( !$status ) {
                            die "Couldn't upload file: ".$filename.( $error ne "" ? ' - '.$error : '');
                        }

                        # copy image to web-site dirs
                        copy_image(
                            {
                                'environment'       => $web_environment,
                                'source_dir'        => $destination_dir,
                                'destination_dir'   => $file_paths->{destination_base}.$handler->{param_of}{'remote_image_path'},
                                'filename'          => $filename,
                            }
                        );

                        # save the filename
                        $factory->set_content(
                                        {   'content_id'                => $content_id,
                                            'content'                   => $filename,
                                            'transfer_dbh_ref'          => $transfer_dbh_ref,
                                            'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                            );
                    }
                }

                # finally set the last updated dts and operator for instance if we didn't update that table
                if ( !$status_id ) {
                    $factory->set_instance_last_updated(
                                            {   'instance_id'               => $instance_id,
                                                'operator_id'               => $handler->operator_id,
                                                'transfer_dbh_ref'          => $transfer_dbh_ref,
                                                'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                                    );
                }

            } );

            $transfer_dbh_ref->{dbh_sink}->commit();
            $staging_transfer_dbh_ref->{dbh_sink}->commit();
        };

        if ($@) {
            # rollback website updates on error - XT updates rolled back as part of txn_do
            $transfer_dbh_ref->{dbh_sink}->rollback();
            $staging_transfer_dbh_ref->{dbh_sink}->rollback();

            $error = $@;
        }
        else {
            $success    = "Version ".$success_suffix;
        }

        # disconnect website transfer handles
        $transfer_dbh_ref->{dbh_sink}->disconnect()         if $transfer_dbh_ref->{dbh_sink};

        $staging_transfer_dbh_ref->{dbh_sink}->disconnect()         if $staging_transfer_dbh_ref->{dbh_sink};

    }
    else {
        $error  = 'No instance_id provided';
    }


    _redirect(
        handler     => $handler,
        redirect    => $redirect,
        error_msg   => $error,
        success_msg => $success
    );
}

1;
