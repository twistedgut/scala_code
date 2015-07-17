package XTracker::WebContent::Actions::UpdatePage;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Comms::DataTransfer       qw( :transfer_handles );
use XTracker::DB::Factory::CMS;
use XTracker::Constants::FromDB         qw( :page_instance_status );
use XTracker::Logfile                   qw( xt_logger );
use XTracker::Utilities                 qw( url_encode );
use XTracker::Error;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $error           = "";
    my $success         = "";

    # required post vars
    my $page_id         = $handler->{param_of}{'page_id'};          # id of page we're updating
    my $name            = $handler->{param_of}{'page_name'};        # name/label
    my $type_id         = $handler->{param_of}{'page_type'};        # type_id
    my $template_id     = $handler->{param_of}{'page_template'};    # template_id
    my $page_key        = $handler->{param_of}{'page_key'};         # page_key
    my $redirect        = $handler->{param_of}{'redirect'};         # where to redirect back to

    # should have required fields
    if ( $page_id && $name && $type_id && $template_id && $page_key ){

        # get schema handle
        my $schema          = $handler->{schema};

        my $page            = $schema->resultset('WebContent::Page')->find($page_id);
        my $channel_info    = $schema->resultset('Public::Channel')->get_channel($page->channel_id);

        my $transfer_dbh_ref            = get_transfer_sink_handle({ environment => 'live', channel => $channel_info->{config_section} });      # get live web transfer handles
        my $staging_transfer_dbh_ref    = get_transfer_sink_handle({ environment => 'staging', channel => $channel_info->{config_section} });   # get staging web transfer handles

        $transfer_dbh_ref->{dbh_source}         = $schema->storage->dbh;                        # pass the schema handle in as the source for the transfer
        $staging_transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;                        # pass the schema handle in as the source for the transfer

        # get Category Navigation DB Factory object
        my $factory = XTracker::DB::Factory::CMS->new({ schema => $schema });

        # get rid of ampersands in the page key
        $page_key   =~ s/\&/and/g;

        # get rid of spaces & replace with '_' in the Page Key as this will represent part of a URL
        $page_key   =~ s/ /_/g;

        # run updates
        eval {
            # pre-check page name is unique before creating
            if ( $schema->resultset('WebContent::Page')->count( { 'UPPER(name)' => uc($name), 'channel_id' => $page->channel_id, 'id' => { '!=', $page_id } } ) ) {
                $error = 'Page already exists with the name: '.$name.', please choose another name.';
            }
            # pre-check page key is unique before creating
            elsif ( $schema->resultset('WebContent::Page')->count( { 'UPPER(page_key)' => uc($page_key), 'channel_id' => $page->channel_id, 'id' => { '!=', $page_id } } ) ) {
                $error = 'Page already exists with the key: '.$page_key.', please choose another.';
            }
            else {
                $schema->txn_do( sub {

                    $factory->update_page(
                                        {   'page_id'                   => $page_id,
                                            'name'                      => $name,
                                            'type_id'                   => $type_id,
                                            'template_id'               => $template_id,
                                            'page_key'                  => $page_key,
                                            'transfer_dbh_ref'          => $transfer_dbh_ref,
                                            'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                    );

                } );

                $transfer_dbh_ref->{dbh_sink}->commit();
                $staging_transfer_dbh_ref->{dbh_sink}->commit();
            }
        };

        if ($@) {
            # rollback website updates on error - XT updates rolled back as part of txn_do
            $transfer_dbh_ref->{dbh_sink}->rollback();
            $staging_transfer_dbh_ref->{dbh_sink}->rollback();

            $error      = $@;
        }
        else {
            $success    = "Page Updated";
        }

        # disconnect website transfer handles
        $transfer_dbh_ref->{dbh_sink}->disconnect()         if $transfer_dbh_ref->{dbh_sink};

        $staging_transfer_dbh_ref->{dbh_sink}->disconnect()         if $staging_transfer_dbh_ref->{dbh_sink};

    }
    else {
        $error = 'Required data not provided';
    }


    $redirect .= '?page_id='.$page_id;

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
