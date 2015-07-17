package XTracker::WebContent::AJAX::UploadImage;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Logfile qw( xt_logger );
use XTracker::Image;
use XTracker::Config::Local qw( get_file_paths );
use XTracker::Utilities qw( portably_get_basename );


sub handler {
    ## no critic(ProhibitDeepNests)
    my $r = shift;
    my $response = '';   # response string
    my $req = $r;      # they're the same thing in our new Plack world


    if ( $req->upload ) {

        # we now need a channel config section so to know where to put the file
        if ( $req->param('channel_config') ) {

            # get the file paths for the channel
            my $file_paths = get_file_paths( $req->param('channel_config') );

            if ( defined $file_paths ) {

                # loop through uploaded files
                foreach my $upload ( $req->upload ) {

                    # match field name
                    if ( $upload->name ) {

                        if ( $upload->name =~ m/uploadImg/ && $upload->filename ne '' ) {

                            # where to copy file on XT
                            my $destination_dir = $file_paths->{source_base} . $file_paths->{cms_source};

                            # get image filename
                            my $filename = portably_get_basename( $upload->filename );

                            # sub-folder specified
                            if ($req->param('destination')) {
                                $destination_dir .= $req->param('destination').'/';
                            }

                            # tag instance id onto start of filename
                            if ($req->param('instance_id')) {
                                $filename = $req->param('instance_id').'_'.$filename;
                            }

                            # upload image to destination dir on XT
                            my ($status,$error) = upload_image($upload, $destination_dir, $filename);

                            # upload successful - write image filename to DB
                            if ( $status ) {
                                $response = $filename;
                            }
                            else {
                                $response = "ERROR: $error";
                            }
                        }
                    }
                }
            }
            else {
                $response = "ERROR: No File Paths Found";
            }
        }
        else {
            $response = "ERROR: No Channel Info Passed";
        }
    }

    $r->content_type( 'text/plain' );
    $r->print($response);

    return OK;
}

1;
