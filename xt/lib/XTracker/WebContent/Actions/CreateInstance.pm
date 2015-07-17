package XTracker::WebContent::Actions::CreateInstance;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Comms::DataTransfer       qw( :transfer_handles );
use XTracker::DB::Factory::CMS;
use XTracker::Logfile                   qw( xt_logger );
use XTracker::Utilities                 qw( portably_get_basename url_encode );
use XTracker::Config::Local             qw( get_file_paths );
use XTracker::Image;
use XTracker::Error;

sub handler {
    ## no critic(ProhibitDeepNests)
    my $handler = XTracker::Handler->new(shift);

    my $error       = "";
    my $success     = "";
    my $suffix      = "";

    my $page_id     = $handler->{param_of}{'page_id'};              # id of page we're creating instance for
    my $name        = $handler->{param_of}{'name'};                 # instance name
    my $redirect    = $handler->{param_of}{'redirect'};             # where to redirect back to

    my $instance_id = '';                                           # id of created record


    # need page id and name to create instance
    if ( $page_id && $name ) {

        my $schema          = $handler->{schema};

        my $page            = $schema->resultset('WebContent::Page')->find($page_id);
        my $channel_info    = $schema->resultset('Public::Channel')->get_channel($page->channel_id);

        my $transfer_dbh_ref            = get_transfer_sink_handle({ environment => 'live', channel => $channel_info->{config_section} });      # get web transfer handles
        my $staging_transfer_dbh_ref    = get_transfer_sink_handle({ environment => 'staging', channel => $channel_info->{config_section} });   # get staging web transfer handles

        $transfer_dbh_ref->{dbh_source}         = $schema->storage->dbh;            # pass the schema handle in as the source for the transfer
        $staging_transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;            # pass the schema handle in as the source for the transfer

        # get Category Navigation DB Factory object
        my $factory = XTracker::DB::Factory::CMS->new({ schema => $schema });

        # create instance & instance content
        eval {

            # pre-check instance name is unique before creating
            if ( $factory->get_instance_from_name($page_id, $name) ) {
                $error  = 'Version already exists with the name: '.$name.', please choose another name.';
            }
            else {

                $schema->txn_do( sub {

                    # create instance record
                    $instance_id = $factory->create_instance(
                                                {   'page_id'                   => $page_id,
                                                    'name'                      => $name,
                                                    'operator_id'               => $handler->operator_id,
                                                    'transfer_dbh_ref'          => $transfer_dbh_ref,
                                                    'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref}
                                        );


                    # create content for instance
                    # we should expect 0 or more content blocks

                    # flag to keep track if we have any content from form
                    my $got_content = 0;
                    # find out if we have ANY content to create
                    foreach ( keys %{ $handler->{param_of} } ) {
                        if ( m/content/ ) {
                            if ( $handler->{param_of}{$_} ne "" ) {
                                $got_content    = 1;
                                last;
                            }
                        }
                    }
                    # also any files being uploaded counts as content
                    foreach ( $handler->{request}->upload ) {
                        if ( ( $_->name =~ /\w.*_(.*)/ ) && ( $_->filename ne "" ) ) {
                            $got_content    = 1;
                            last;
                        }
                    }

                    CREATE_CONTENT: {

                        # no content submitted - try cloning the current instance content if we have one
                        if ( $got_content == 0 ) {

                            # get the current live instance
                            my $live_instance_id = $factory->get_live_instance_from_pageid($page_id);

                            # if we have one get it's content and clone it
                            if ( $live_instance_id ) {

                                my $live_content = $factory->get_instance_content($live_instance_id);

                                while (my $content = $live_content->next) {

                                    $factory->create_content(
                                                    {   'instance_id'               => $instance_id,
                                                        'field_id'                  => $content->get_column('field_id'),
                                                        'content'                   => $content->get_column('content'),
                                                        'category_id'               => $content->get_column('category_id'),
                                                        'transfer_dbh_ref'          => $transfer_dbh_ref,
                                                        'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                                        );
                                }

                                $suffix = " & Content Cloned from Current Live Version";

                                last CREATE_CONTENT;
                            }

                        }

                        # if ANY content submitted then create all fields,
                        # also do this if no current live version present even though there is no content

                        # loop through form fields to pick up content blocks - e.g. content_1, content_2
                        foreach my $param ( keys %{ $handler->{param_of} } ) {

                            # match field name
                            if ( $param =~ m/content/ ) {

                                # split content id out of field name
                                my ($blank, $content_id) = split(/_/, $param);

                                my $content     = $handler->{param_of}{'content_'.$content_id};
                                my $field_id    = $handler->{param_of}{'field_'.$content_id};

                                if ($field_id) {

                                    if (!$content) {
                                        $content = '';
                                    }

                                    # clean up content
                                    $content =~ s/\r//g;
                                    $content =~ s/\n//g;
                                    $content =~ s/\\//g;
                                    $content =~ s/\\'/\'/g;
                                    $content =~ s/DQUOTE/\"/g;

                                    $factory->create_content(
                                                    {   'instance_id'               => $instance_id,
                                                        'field_id'                  => $field_id,
                                                        'content'                   => $content,
                                                        'transfer_dbh_ref'          => $transfer_dbh_ref,
                                                        'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                                            );
                                }

                            }
                        }

                        my $file_paths  = get_file_paths($channel_info->{config_section});

                        # check for file uploads
                        foreach my $upldfile ( $handler->{request}->upload ) {
                            if ( ( $upldfile->name =~ /\w.*_(.*)/ ) && ( $upldfile->filename ne "" ) ) {
                                my $content_id  = $1;
                                my $field_id    = $handler->{param_of}{'field_'.$content_id};
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
                                    die "Couldn't upload file: ".$filename;
                                }

                                # copy image to web-site dirs
                                copy_image(
                                        {
                                            'environment'       => 'live',
                                            'source_dir'        => $destination_dir,
                                            'destination_dir'   => $file_paths->{destination_base}.$handler->{param_of}{'remote_image_path'},
                                            'filename'          => $filename,
                                        }
                                    );

                                # save the filename
                                $factory->create_content(
                                        {
                                            'instance_id'               => $instance_id,
                                            'field_id'                  => $field_id,
                                            'content'                   => $filename,
                                            'transfer_dbh_ref'          => $transfer_dbh_ref,
                                            'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref
                                        }
                                    );
                            }
                            else {
                                if ( $upldfile->name =~ /\w.*_(.*)/ ) {
                                    my $content_id  = $1;
                                    my $field_id    = $handler->{param_of}{'field_'.$content_id};

                                    # create the content even if there is no filename
                                    $factory->create_content(
                                            {
                                                'instance_id'               => $instance_id,
                                                'field_id'                  => $field_id,
                                                'content'                   => "",
                                                'transfer_dbh_ref'          => $transfer_dbh_ref,
                                                'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref
                                            }
                                        );
                                }
                            }
                        }

                    };

                    $transfer_dbh_ref->{dbh_sink}->commit();
                    $staging_transfer_dbh_ref->{dbh_sink}->commit();

                } );

            }
        };

        if ($@) {
            # rollback website updates on error - XT updates rolled back as part of txn_do
            $transfer_dbh_ref->{dbh_sink}->rollback();
            $staging_transfer_dbh_ref->{dbh_sink}->rollback();

            $error      = $@;
            $instance_id= '';       # clear instance id as it no longer exists
        }
        else {
            $success    = "New Version Created".$suffix;
        }

        # disconnect website transfer handles
        $transfer_dbh_ref->{dbh_sink}->disconnect()         if $transfer_dbh_ref->{dbh_sink};

        $staging_transfer_dbh_ref->{dbh_sink}->disconnect()         if $staging_transfer_dbh_ref->{dbh_sink};

    }
    else {
        $error = 'No page_id or name provided';
    }


    # redirect URL
    $redirect .= '?page_id='.$page_id.'&instance_id='.$instance_id;

    # tag error onto URL if we have one
    if ($error) {
            xt_warn($error);
    }
    elsif ($success) {
            xt_success($success);
    }

    $handler->redirect_to( $redirect );

    return REDIRECT;
}

1;
