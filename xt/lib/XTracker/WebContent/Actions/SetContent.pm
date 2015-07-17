package XTracker::WebContent::Actions::SetContent;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Comms::DataTransfer           qw( :transfer_handles );
use XTracker::DB::Factory::CMS;
use XTracker::Logfile                       qw( xt_logger );
use XTracker::Utilities                     qw( url_encode );
use XTracker::Error;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $error           = "";
    my $success         = "";
    my $success_suffix  = "";
    my $dupe_err        = 0;

    my $page_id         = $handler->{param_of}{'page_id'};              # all required fields except category id
    my $instance_id     = $handler->{param_of}{'instance_id'};          #
    my $content_id      = $handler->{param_of}{'content_id'} || 0;      #
    my $field_id        = $handler->{param_of}{'field_id'};             #
    my $content         = $handler->{param_of}{'content'};              #
    my $category_id     = $handler->{param_of}{'category_id'};          #
    my $redirect        = $handler->{param_of}{'redirect'};             # where to redirect back to


    # need page all info to create page
    if ( $page_id && $instance_id && $field_id ) {

        my $schema          = $handler->{schema};

        my $page            = $schema->resultset('WebContent::Page')->find($page_id);
        my $channel_info    = $schema->resultset('Public::Channel')->get_channel($page->channel_id);

        my $transfer_dbh_ref            = get_transfer_sink_handle({ environment => 'live', channel => $channel_info->{config_section} });      # get web transfer handles
        my $staging_transfer_dbh_ref    = get_transfer_sink_handle({ environment => 'staging', channel => $channel_info->{config_section} });   # get staging web transfer handles

        $transfer_dbh_ref->{dbh_source}         = $schema->storage->dbh;            # pass the schema handle in as the source for the transfer
        $staging_transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;            # pass the schema handle in as the source for the transfer


        # get CMS DB Factory object
        my $factory = XTracker::DB::Factory::CMS->new({ schema => $schema });


        # create page
        eval {

            $schema->txn_do( sub {

                if ($content_id) {

                    # update content record
                    $factory->set_content(
                                        {   'content_id'                => $content_id,
                                            'content'                   => $content,
                                            'field_id'                  => $field_id,
                                            'category_id'               => $category_id,
                                            'transfer_dbh_ref'          => $transfer_dbh_ref,
                                            'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                                    );

                    $success_suffix = " Updated";
                }
                else {

                    if ( $schema->resultset('WebContent::Content')->count( { instance_id => $instance_id, field_id => $field_id } ) ) {
                        $dupe_err   = 1;
                        die "DUPE WEB CONTENT ERR";
                    }

                    # create content record
                    $content_id = $factory->create_content(
                                                {   'instance_id'               => $instance_id,
                                                    'field_id'                  => $field_id,
                                                    'content'                   => $content,
                                                    'category_id'               => $category_id,
                                                    'transfer_dbh_ref'          => $transfer_dbh_ref,
                                                    'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                                    );

                    $success_suffix = " Created";
                }

                # set the last updated dts and operator for instance
                $factory->set_instance_last_updated(
                                                {   'instance_id'               => $instance_id,
                                                    'operator_id'               => $handler->operator_id,
                                                    'transfer_dbh_ref'          => $transfer_dbh_ref,
                                                    'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                                    );

                $transfer_dbh_ref->{dbh_sink}->commit();
                $staging_transfer_dbh_ref->{dbh_sink}->commit();

            } );

        };


        if ($@) {
            # rollback website updates on error - XT updates rolled back as part of txn_do
            $transfer_dbh_ref->{dbh_sink}->rollback();
            $staging_transfer_dbh_ref->{dbh_sink}->rollback();

            if ($dupe_err) {
                my $field_name  = $schema->resultset('WebContent::Field')->find($field_id);
                $error          = 'Attempted to Create Content for Existing Field: '.$field_name->name;
            }
            else {
                $error  = $@;
                $error  .= " - Instance id: $instance_id, ";
                $error  .= "Field id: $field_id, ";
#               $error  .= "Content: $content, ";
                $error  .= "Category ID: $category_id, ";
                $error  .= "Content ID: $content_id";
            }
        }
        else {
            my $field_name  = $schema->resultset('WebContent::Field')->find($field_id);
            $success        = "Content ".$success_suffix." for Field: ".$field_name->name;
        }

        # disconnect website transfer handles
        $transfer_dbh_ref->{dbh_sink}->disconnect()         if $transfer_dbh_ref->{dbh_sink};

        $staging_transfer_dbh_ref->{dbh_sink}->disconnect()         if $staging_transfer_dbh_ref->{dbh_sink};

    }
    else {
        $error  = "Insufficient data provided to create content - ";
        $error  .= "Instance id: $instance_id, ";
        $error  .= "Field id: $field_id, ";
#       $error  .= "Content: $content, ";
        $error  .= "Category ID: $category_id, ";
        $error  .= "Content ID: $content_id";
    }


    # redirect URL
    $redirect   .= '?page_id='.$page_id.'&instance_id='.$instance_id.'&content_id='.$content_id;

    # tag error onto URL if we have one
    if ($error) {
            xt_warn($error);
    }
    elsif ($success) {
            xt_success($success);
    }

    return $handler->redirect_to( $redirect );
}

1;
