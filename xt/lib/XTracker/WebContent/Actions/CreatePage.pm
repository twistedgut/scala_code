package XTracker::WebContent::Actions::CreatePage;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Comms::DataTransfer           qw( :transfer_handles );

use XTracker::DB::Factory::CMS;
use XTracker::Error;

use XTracker::Handler;
use XTracker::Logfile                       qw( xt_logger );
use XTracker::Utilities                     qw( url_encode );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $error           = "";
    my $success         = "";

    my $page_name       = $handler->{param_of}{'page_name'};                # all required fields
    my $page_key        = $handler->{param_of}{'page_key'};                 #
    my $page_type       = $handler->{param_of}{'page_type'};                #
    my $page_template   = $handler->{param_of}{'page_template'};            #
    my $page_channel_id = $handler->{param_of}{'page_channel_id'};          #
    my $redirect        = $handler->{param_of}{'redirect'};                 # where to redirect back to

    my $page_id         = '';                                               # id of created record


    # need page all info to create page
    if ( $page_name && $page_key && $page_type && $page_template && $page_channel_id ) {

        my $schema                      = $handler->{schema};

        my $channel_info                = $schema->resultset('Public::Channel')->get_channel($page_channel_id);     # Get channel info for page

        # get web transfer handles
        my $transfer_dbh_ref            = get_transfer_sink_handle({ environment => 'live', channel => $channel_info->{config_section} });
        # get staging web transfer handles
        my $staging_transfer_dbh_ref    = get_transfer_sink_handle({ environment => 'staging', channel => $channel_info->{config_section} });

        $transfer_dbh_ref->{dbh_source}         = $schema->storage->dbh;                        # pass the schema handle in as the source for the transfer
        $staging_transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;                        # pass the schema handle in as the source for the transfer


        # get CMS DB Factory object
        my $factory = XTracker::DB::Factory::CMS->new({ schema => $schema });

        # get rid of ampersands in the page key
        $page_key   =~ s/\&/and/g;

        # get rid of spaces & replace with '_' in the Page Key as this will represent part of a URL
        $page_key   =~ s/ /_/g;

        # create page
        eval {

            # pre-check page name is unique before creating
            if ( $schema->resultset('WebContent::Page')->count( { 'UPPER(name)' => uc($page_name), 'channel_id' => $page_channel_id } ) ) {
                $error = 'Page already exists with the name: '.$page_name.', please choose another name.';
            }
            # pre-check page key is unique before creating
            elsif ( $schema->resultset('WebContent::Page')->count( { 'UPPER(page_key)' => uc($page_key), 'channel_id' => $page_channel_id } ) ) {
                $error = 'Page already exists with the key: '.$page_key.', please choose another.';
            }
            else {

                $schema->txn_do( sub {

                    # create instance record
                    $page_id    = $factory->create_page(
                                            {
                                                'name'                      => $page_name,
                                                'type'                      => $page_type,
                                                'template'                  => $page_template,
                                                'page_key'                  => $page_key,
                                                'transfer_dbh_ref'          => $transfer_dbh_ref,
                                                'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref,
                                                'channel_id'                => $page_channel_id
                                            }
                                    );

                    $transfer_dbh_ref->{dbh_sink}->commit();
                    $staging_transfer_dbh_ref->{dbh_sink}->commit();

                } );

            }
        };

        if ($@) {
            # rollback website updates on error - XT updates rolled back as part of txn_do
            $transfer_dbh_ref->{dbh_sink}->rollback();
            $staging_transfer_dbh_ref->{dbh_sink}->rollback();

            $error  = $@;
            $error  .= " - Page Name: $page_name, ";
            $error  .= "Page Key: $page_key, ";
            $error  .= "Page Type: $page_type, ";
            $error  .= "Page Template: $page_template, ";
            $error  .= "Page Channel Id: $page_channel_id ";
        }
        else {
            $success    = "Page Created";
        }

        # disconnect website transfer handles
        $transfer_dbh_ref->{dbh_sink}->disconnect()                 if $transfer_dbh_ref->{dbh_sink};

        $staging_transfer_dbh_ref->{dbh_sink}->disconnect()         if $staging_transfer_dbh_ref->{dbh_sink};
    }
    else {
        $error  = "Insufficient data provided to create page - ";
        $error  .= "Page Name: $page_name, ";
        $error  .= "Page Key: $page_key, ";
        $error  .= "Page Type: $page_type, ";
        $error  .= "Page Template: $page_template, ";
        $error  .= "Page Channel Id: $page_channel_id";
    }


    # redirect URL
    $redirect   .= '?page_id='.$page_id;

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
