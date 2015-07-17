#!/opt/xt/xt-perl/bin/perl -w
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
#
# http://jira4.nap/browse/APS-1008
# BAU :: NAP INTL/AM > DLP Bulk Image Upload - Updates for January 2012
#
# This script is taken from script/BAU/DLP_designer_seasonal_updates.pl
# and has been modified to also update the DLP template and DLP content links (1/2/3)
#
# Please note the staging option of this script does not work (as least not on dave environments)
# There does not appear to be a need to use this option however as the --live option will also 
# update the staging db at the same time
#
# ALSO - filename format was changed to - Designer_Name_Season_123.jpg (eg. Victoria_Beckham_SS12_517.jpg)
#

use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use lib "$Bin/../../lib";
use lib "lib";
use FindBin::libs qw( base=lib_dynamic );

use Data::Printer { colored => 1, class => { internals => 0 , parents => 0, linear_isa => 0, show_methods => 'none' }, };
use Getopt::Long;
use XTracker::Config::Local             qw( get_file_paths config_var );
use XTracker::Database qw( :common );
use XTracker::Constants::FromDB qw(
    :page_instance_status
    :web_content_field
    :web_content_template
    :web_content_type
);
use XTracker::Image                     qw( copy_image upload_image );
use XTracker::Comms::DataTransfer       qw(:transfer_handles);
use XTracker::DB::Factory::CMS;
use XTracker::Utilities                 qw( portably_get_basename url_encode );

use File::Copy;

##
## Process the command line arguments
##
my ($fsi_dir, $live, $staging);
GetOptions(
    'font_size_image_directory=s' => \$fsi_dir,
    'live' => \$live,
    'staging' => \$staging,
);

die "Usage: $0 --font_size_image_directory [/directory/containing/[45|65|85]/dlp_<designer_id>_<anything>.[jpg|gif]] [--live|--staging]

Run this on xtracker with the content directory  /tmp or something like that.
Alternatively, mount it as follows:

\$ mount.cifs   //fp01-pr-whi/shared /mnt/samba/shared -o user=LONDON/a.solomon

Then call

\$ $0 --font_size_image_directory \
/mnt/samba/shared/Product\ Marketing/Designer\ Landing\ Pages/FW10/Build

"
unless $fsi_dir ;

##
## Get schema
##
my $schema = get_database_handle({
    name => 'xtracker_schema',
    type => 'transaction',
});

## 
## Get the NAP channel_info and file_paths 
##
my $channel = $schema->resultset('Public::Channel')->get_channel_details('NET-A-PORTER.COM');
print "\n";
print 'DLP season updates for: '. p($channel)."\n";
my $channel_id      = $channel->{id};
my $channel_info    = $schema->resultset('Public::Channel')->get_channel($channel_id);
my $file_paths  = get_file_paths($channel_info->{config_section});
print "\n";
print "File Paths: ".p($file_paths)."\n";

##
## Parse the directory
##
my $rh_image_info = parse_image_folder($fsi_dir);
print "\n";
print 'Parsed Image Folder: '.p($rh_image_info)."\n";

# Points->css class map
my %css_map = (
    85 => 'One',
    65 => 'Two',
    45 => 'Three',
);

## Get the page content for these designers
my @designer_ids = keys(%$rh_image_info);
my $dpi = designers_page_instance_ids(\@designer_ids);
my $operator_id = '971';

print "\n";
print 'Designer page instances: ' .p($dpi)."\n";

foreach my $designer_id (sort { $a <=> $b } keys(%$dpi)) {

    eval {

        print '=================================================='      . "\n";
        print 'Dealing with designer:' . (p $dpi->{$designer_id})      . "\n";
        print '--------------------------------------------------'      . "\n";
        print 'New data:' . (p $rh_image_info->{$designer_id})         . "\n";
        print '--------------------------------------------------'      . "\n";
        print                                                             "\n";

        my $font_size_content_id = instance_content($dpi->{$designer_id}{instance_id},  $WEB_CONTENT_FIELD__DESIGNER_NAME_FONT_CLASS);
        print "Current Font size: " . (p $font_size_content_id) . "\n";
        my $image_content_id = instance_content($dpi->{$designer_id}{instance_id},  $WEB_CONTENT_FIELD__MAIN_AREA_IMAGE);
        print "\n";
        print "Current Image:" . (p $image_content_id) . "\n";

        # get content link ids 
        my %wc_left_nav_id;

        $wc_left_nav_id{link_1_text} = instance_content($dpi->{$designer_id}{instance_id},  $WEB_CONTENT_FIELD__LEFT_NAV_LINK_1_TEXT);
        $wc_left_nav_id{link_1_url} = instance_content($dpi->{$designer_id}{instance_id},  $WEB_CONTENT_FIELD__LEFT_NAV_LINK_1_URL);

        $wc_left_nav_id{link_2_text} = instance_content($dpi->{$designer_id}{instance_id},  $WEB_CONTENT_FIELD__LEFT_NAV_LINK_2_TEXT);
        $wc_left_nav_id{link_2_url} = instance_content($dpi->{$designer_id}{instance_id},  $WEB_CONTENT_FIELD__LEFT_NAV_LINK_2_URL);

        $wc_left_nav_id{link_3_text} = instance_content($dpi->{$designer_id}{instance_id},  $WEB_CONTENT_FIELD__LEFT_NAV_LINK_3_TEXT);
        $wc_left_nav_id{link_3_url} = instance_content($dpi->{$designer_id}{instance_id},  $WEB_CONTENT_FIELD__LEFT_NAV_LINK_3_URL);

        my $instance_id = $dpi->{$designer_id}{instance_id};
        my $page_id = $dpi->{$designer_id}{page_id};

        my $image = $rh_image_info->{$designer_id}{image};
        my $font_size_class = $css_map{ $rh_image_info->{$designer_id}{font_size} };
        my $upldfile = $rh_image_info->{$designer_id}{path} . $rh_image_info->{$designer_id}{image}; # ????
        my $remote_image_path = 'images/designerFocus/';

        my $designer = $schema->resultset('Public::Designer')->find($designer_id);

        my $page = $schema->resultset('WebContent::Page')->find($page_id);

        my $template = $schema->resultset('WebContent::Template')->find({name => 'Featured Product Designer Landing Page'}) || die 'Unable to find new template';

        ##### SECTION COPIED AND AMENDED FROM lib/XTracker/WebContent/Actions/UpdateInstance.pm

        # convert status to status id if required

        my $success_suffix = "Updated";
        my $web_environment = "live"; 
        my ($status_id, $error, $success) = ('','',''); 

        # staging overrides live
        print "\n";
        if ( $staging ) {
            # IMPORTANT: publish to staging does not change status BUT needs to switch web environment to staging otherwise we'll be updating live website
            print "*** STAGING ***\n";
            $status_id          = $WEB_CONTENT_INSTANCE_STATUS__PUBLISH;
            $web_environment    = 'staging';
            $success_suffix     = "Published to Staging";
        } elsif ( $live ) { 
            print "*** LIVE ***\n";
            $status_id          = $WEB_CONTENT_INSTANCE_STATUS__PUBLISH;
            $success_suffix     = "Published to Live";
        } else {
            print "Next\n";
            next;
        }

        # should have at least an instance id

        my $transfer_dbh_ref            = get_transfer_sink_handle({ environment => $web_environment, channel => $channel_info->{config_section} });    # get web transfer handles
        my $staging_transfer_dbh_ref    = get_transfer_sink_handle({ environment => 'staging', channel => $channel_info->{config_section} });           # get staging web transfer handles

        # pass the schema handle in as the source for the transfer
        # always from XTracker no matter where we're going for the Web App
        $transfer_dbh_ref->{dbh_source}         = $schema->storage->dbh;     
        $staging_transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;               

        # get Category Navigation DB Factory object
        my $factory = XTracker::DB::Factory::CMS->new({ schema => $schema });

        # run updates
        eval {
            $schema->txn_do( sub {

                my $param_ref = {
                    'page_id'               => $page_id,
                    'name'                  => $page->name,
                    'type_id'               => $page->type_id,
                    'template_id'           => $template->id,
                    'page_key'              => $page->page_key,
                    'transfer_dbh_ref'         => $transfer_dbh_ref,
                    'staging_transfer_dbh_ref' => $staging_transfer_dbh_ref
                };

                print "\n";
                print "Updating template: " . p($param_ref) . "\n";

                $factory->update_page($param_ref);

                print "\nUpdating content links: \n\n";

                $param_ref = {
                    'content_id'               => $wc_left_nav_id{link_1_text}->{content_id},
                    'content'                  => 'Shop the collection',
                    'transfer_dbh_ref'         => $transfer_dbh_ref,
                    'staging_transfer_dbh_ref' => $staging_transfer_dbh_ref 
                };

                print "Content link text 1 - ". p($param_ref) . "\n";
                $factory->set_content($param_ref);

                $param_ref = {
                    'content_id'               => $wc_left_nav_id{link_1_url}->{content_id},
                    'content'                  => 'http://www.net-a-porter.com/Shop/Designers/' . $designer->url_key . '/All',
                    'transfer_dbh_ref'         => $transfer_dbh_ref,
                    'staging_transfer_dbh_ref' => $staging_transfer_dbh_ref,
                };

                print "Content link URL 1 - ". p($param_ref) . "\n";
                $factory->set_content($param_ref);

                $param_ref = {
                    'content_id'               => $wc_left_nav_id{link_2_text}->{content_id},
                    'content'                  => 'Sign up for '. $designer->designer . ' updates',
                    'transfer_dbh_ref'         => $transfer_dbh_ref,
                    'staging_transfer_dbh_ref' => $staging_transfer_dbh_ref 
                };

                print "Content link text 2 - ". p($param_ref) . "\n";
                $factory->set_content($param_ref);

                $param_ref = {
                    'content_id'               => $wc_left_nav_id{link_2_url}->{content_id},
                    'content'                  => 'javascript:designerEmailUpdate(\''. $designer->url_key . '\')',
                    'transfer_dbh_ref'         => $transfer_dbh_ref,
                    'staging_transfer_dbh_ref' => $staging_transfer_dbh_ref,
                };

                print "Content link URL 2 - ". p($param_ref) . "\n";
                $factory->set_content($param_ref);

                $param_ref = {
                    'content_id'               => $wc_left_nav_id{link_3_text}->{content_id},
                    'content'                  => 'Editors\' Picks',
                    'transfer_dbh_ref'         => $transfer_dbh_ref,
                    'staging_transfer_dbh_ref' => $staging_transfer_dbh_ref 
                };

                print "Content link text 3 - ". p($param_ref) . "\n";
                $factory->set_content($param_ref);

                $param_ref = {
                    'content_id'               => $wc_left_nav_id{link_3_url}->{content_id},
                    'content'                  => '',
                    'transfer_dbh_ref'         => $transfer_dbh_ref,
                    'staging_transfer_dbh_ref' => $staging_transfer_dbh_ref,
                };

                print "Content link URL 3 - ". p($param_ref) . "\n";
                $factory->set_content($param_ref);

                # update instance status
                if ( $status_id ) {
                    $factory->set_instance_status({
                        'page_id'                   => $page_id,
                        'instance_id'               => $instance_id,
                        'status_id'                 => $status_id,
                        'operator_id'               => $operator_id,
                        'environment'               => $web_environment,
                        'transfer_dbh_ref'          => $transfer_dbh_ref,
                        'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref
                    });
                }
    
                $param_ref = {
                    'content_id'                => $font_size_content_id->{content_id},
                    'content'                   => $font_size_class,
                    'transfer_dbh_ref'          => $transfer_dbh_ref,
                    'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref 
                };
    
                print "Content font class - " . p($param_ref) . "\n";
                $factory->set_content($param_ref);

                my $file_paths  = get_file_paths($channel_info->{config_section});

                # check for file uploads

                {
                    my $content_id  = $image_content_id->{content_id};
                    my $filename    = $image;
                    my $destination = 'designerFocus';

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
                    print "\nAbout to copy file $upldfile to $destination_dir$filename\n";
                    eval { 
                        copy ($upldfile, $destination_dir . $filename) or die ("Couldn't copy  file: $upldfile to $destination_dir$filename");
                    };
                    warn "$@" if $@;

                    # copy image to web-site dirs
                    print "\nAbout to do web copy\n";
                    $param_ref = {
                        'environment'       => $web_environment,
                        'source_dir'        => $destination_dir,
                        'destination_dir'   => $file_paths->{destination_base}. $remote_image_path,
                        'filename'          => $filename,
                    };

                    print "Copying:" .  p($param_ref) . "\n";

                    eval { # just to stop this bombing out while testing ssh
                        copy_image($param_ref);
                    }; 
                    warn "Could not copy $destination_dir$filename to $remote_image_path : $@" if $@;
                    print "\n";
    
                    # save the filename
                
                    $param_ref = {
                        'content_id'                => $content_id,
                        'content'                   => $filename,
                        'transfer_dbh_ref'          => $transfer_dbh_ref,
                        'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref 
                    };

                    print "About to set image content: " . p($param_ref) . "\n";
                    $factory->set_content($param_ref);
                }

                # finally set the last updated dts and operator for instance if we didn't update that table             
                if ( !$status_id ) {
                    $factory->set_instance_last_updated({
                        'instance_id'               => $instance_id,
                        'operator_id'               => $operator_id,
                        'transfer_dbh_ref'          => $transfer_dbh_ref,
                        'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref 
                    });
                }

            });
    
            $transfer_dbh_ref->{dbh_sink}->commit();
            $staging_transfer_dbh_ref->{dbh_sink}->commit();
        };

        if ($@) {
            print "Got error $@\n";
            # rollback website updates on error - XT updates rolled back as part of txn_do
            $transfer_dbh_ref->{dbh_sink}->rollback();
            $staging_transfer_dbh_ref->{dbh_sink}->rollback();

            $error = $@;
            exit;

        } else {
            print "\nSUCCESS!\n";
            $success    = "Version ".$success_suffix;
        }

        # disconnect website transfer handles
        $transfer_dbh_ref->{dbh_source}->disconnect()       if $transfer_dbh_ref->{dbh_source};
        $transfer_dbh_ref->{dbh_sink}->disconnect()         if $transfer_dbh_ref->{dbh_sink};

        $staging_transfer_dbh_ref->{dbh_source}->disconnect()       if $staging_transfer_dbh_ref->{dbh_source};
        $staging_transfer_dbh_ref->{dbh_sink}->disconnect()         if $staging_transfer_dbh_ref->{dbh_sink};

    }; 

    print "\n";
    print "BAILED FROM OUTER EVAL : $@\n" if $@;

}

print "FINISHED\n";

##### END OF COPY

exit;

## 
## designers_page_instance_ids (\@designer_ids)
##
## Get the DLP page instance ids for a list of designers
##

sub designers_page_instance_ids {
    my $designers = shift;

    my $dbh = read_handle();
    my $qry = "
        SELECT
            d.id as designer_id,
            d.designer,
            p.id as page_id,
            i.id as instance_id
        FROM 
            designer d,
            web_content.page p,
            web_content.instance i
        WHERE 
            d.url_key = p.page_key
            AND p.id = i.page_id
            AND d.id IN ("
            . join( q{, }, (("?") x @$designers))
            . q{) ORDER BY d.designer};

    my $sth = $dbh->prepare($qry);
    $sth->execute(@$designers);

    my $dpc = $sth->fetchall_hashref('designer_id');

    return $dpc;
}

## 
## instance_content (instance_id, content_type_id)
##
## Get the DLP instance content of type content_type_id
##

sub instance_content {
    my $instance_id = shift;
    my $content_type = shift;

    # Get the content id for the matching main area image for the
    # instance that is being updated
    my $webcontent = $schema->resultset('WebContent::Content');
    my $content  = $webcontent->search({
        instance_id => $instance_id,
        field_id    => $content_type
    })->slice(0,0)->single;

    my $rh_content = {
        current_value    => $content->content,
        content_id      => $content->id,
        field_id        => $content->field_id,
    };

    return  $rh_content ;
}


##
## parse_image_folder
## 
## Takes one argument - a directory containing the fontsizes/images
## 
## Returns a hash of 
## designerid => {font_size => xx,  image => 'abc.jpg' };
## 
sub parse_image_folder {

    my $font_size_image_dir = shift;

    my %designer_images = ();
    # Get the font size directories
    opendir(BUILD, $font_size_image_dir) ;
#    my @font_size_dirs = grep(/\d/,readdir(BUILD));
    my @font_size_dirs = ( grep { /\d/ } readdir(BUILD)  );

    close(BUILD);

    foreach my $font_size (@font_size_dirs) {
        # print "Opening $font_size_image_dir/$font_size\n";
        opendir(IMAGES, "$font_size_image_dir/$font_size") ;
#        my @images = grep(/.*_SS12_\d+.*$/,readdir(IMAGES));

        my @images = ( grep { /.*_SS12_\d+.*$/ } readdir(IMAGES) );

        close(IMAGES);

        foreach my $image (@images) {
            my $designer_id = $image ;   
            $designer_id =~ s/^.*_SS12_(\d+).*$/$1/;
            $designer_images{$designer_id}->{image} = $image ;
            $designer_images{$designer_id}->{path} = "$font_size_image_dir/$font_size/";
            $designer_images{$designer_id}->{font_size} = $font_size;
        }
    }

    return \%designer_images;

}

