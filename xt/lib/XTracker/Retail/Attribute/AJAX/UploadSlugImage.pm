package XTracker::Retail::Attribute::AJAX::UploadSlugImage;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

#use XTracker::Database         qw( :common );
#use XTracker::DB::Factory::ProductNavigation;

use XTracker::Handler;
use XTracker::Logfile           qw( xt_logger );
use XTracker::Session; # TODO: Remove this
use XTracker::Image;

use XTracker::Config::Local     qw( get_file_paths );
use XTracker::Utilities         qw( portably_get_basename );
use XTracker::DBEncode          qw( encode_it );

sub handler {

    my $r                   = shift;
    my $response            = '';                               # response string
    my $req                 = $r; # they're the same thing in our new Plack world

    my $slug_name           = $req->param('slug_name');
    my $upload_img          = $req->upload('slug_image');
    my $channel_id          = $req->param('channel_id');
    my $channel_config      = $req->param('channel_config');
    my $retmsg              = "";


    if ($upload_img) {

        eval {
            # Get base/source/destination paths for use in copying images
            my $file_paths      = get_file_paths($channel_config);

            # where to copy file on XT
            my $destination_dir = $file_paths->{source_base}.$file_paths->{slug_source};

            # tidy up slug name to use as image filename
            $slug_name  =~ s/ /_/g;

            # upload image to destination dir on XT
            my ($status,$error) = upload_image($upload_img, $destination_dir, $slug_name.'.gif')
                or die 'Could not save local copy of image';

            # upload successful - copy image to website
            if ( $status ) {

                # get image filename
                my $filename = portably_get_basename( $upload_img->filename() );

                if (copy_image(
                        {
                            'environment'       => 'live',
                            'source_dir'        => $destination_dir,
                            'destination_dir'   => $file_paths->{destination_base}.$file_paths->{slug_destination},
                            'filename'          => $slug_name . '.gif',
                        }
                    )) {
                    $retmsg = $filename;
                }
                else {
                    die 'Could not transfer image to web servers';
                }

            }
            else {
                die $error;
            }

        };

        if ($@) {
            $@  =~ s/[\r\n]//g;
            $retmsg = "Error: ".$@;
        }
        else {
            # nothing to do - all went okay
        }

    }
    else {
        $retmsg = "No file to upload";
    }

    $r->content_type( 'text/html' );
    $r->print( encode_it($retmsg) );

    return OK;
}

1;
