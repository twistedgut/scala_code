#!/opt/xt/xt-perl/bin/perl -w
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use Data::Dump  qw(pp);

use Getopt::Long;
use DateTime;

use XTracker::Config::Local             qw( get_file_paths config_var );
use XTracker::Database                  qw( :common );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB qw(
    :page_instance_status
    :web_content_field
    :web_content_template
    :web_content_type
);
use XTracker::Image                     qw( copy_image upload_image );
use XTracker::Comms::DataTransfer       qw( :transfer_handles );
use XTracker::DB::Factory::CMS;
use XTracker::Utilities                 qw( portably_get_basename url_encode );

use File::Copy;
use File::Basename;


##
## Process the command line arguments
##

my  ( $fsi_dir, $single_img_file, $live, $staging, $check );
GetOptions(
    'template_image_directory=s' => \$fsi_dir,
    'single_image_upload=s' => \$single_img_file,
    'live' => \$live,
    'staging' => \$staging,
    'check' => \$check,
);
die "Usage:

$0 --template_image_directory [/directory/containing/[standard_template|video_template]/dlp_<designer_id>_<anything>.[jpg|gif]] [--live|--staging]

Run this on xtracker with the content directory  /tmp or something like that.
Alternatively, mount it as follows:

\$ mount.cifs   //fp01-pr-whi/shared /mnt/samba/shared -o user=LONDON/a.solomon

Then call

\$ $0 --template_image_directory \
/mnt/samba/shared/Product\ Marketing/Designer\ Landing\ Pages/FW10/Build

To check the Build directory for Bulk uploads for images that won't get processed or duplicates, call:

$0 --template_image_directory /directory/containing/[standard_template|video_template] --check

or, to update One image to All designers

To upload the same image to All designers, call:
$0 --single_image_upload /path/to/single_image_filename.[jpg|gif] [--live|--staging]

"
    unless ( ( $fsi_dir || $single_img_file ) && !( $fsi_dir && $single_img_file ) );


##
## Get Log Path
##

my $now         = DateTime->now( time_zone => 'local' );
my $log_path    = config_var( 'SystemPaths', 'xtdc_logs_dir' );
my $log_file    = $log_path . "/dlp_updates.log";
print "Log File: " . $log_file . "\n";
open( my $logf,'>>',$log_file ) or die "Can't open Log File: $log_file\n";

_log( $logf, "=============================" );
_log( $logf, "Designer Landing Page Updates" );
_log( $logf, "Date: ".$now->ymd('-') . " " . $now->hms(':') );
_log( $logf, "-----------------------------" );

##
## Get schema
##

my $schema = get_database_handle({
    name => 'xtracker_schema',
    type => 'transaction',
});

# set-up some Result-Sets
my $webc_page   = $schema->resultset('WebContent::Page');


## 
## Get the NAP channel_info and file_paths 
##

my $channel = $schema->resultset('Public::Channel')->get_channel_details('NET-A-PORTER.COM');
_log( $logf, 'DLP season updates for: '. pp($channel) );
my $channel_id      = $channel->{id};
my $channel_info    = $schema->resultset('Public::Channel')->get_channel($channel_id);
my $file_paths      = get_file_paths( $channel_info->{config_section} );
_log( $logf, "File Paths: ".pp($file_paths) );


##
## Parse the directory
##

# Template Id map
my %template_map = (
    video       => {
        template_id => $WEB_CONTENT_TEMPLATE__VIDEO_DESIGNER_LANDING_PAGE,
        font_class  => 'Three',
    },
    standard    => {
        template_id => $WEB_CONTENT_TEMPLATE__STANDARD_DESIGNER_LANDING_PAGE,
        font_class  => 'Two',
    },
);
my $rh_image_info;
my @designer_ids;
my $dpi;

if ( $fsi_dir ) {
    if ( !$check ) {
        _log( $logf, "DLP Update Type: Updating Designer Images from Bulk Directory", 1 );

        $rh_image_info  = parse_image_folder( $fsi_dir );
        _log( $logf, 'Parsed Image Folder: '.pp($rh_image_info) );
    }
    else {
        _log( $logf, "DLP Update Type: Checking Images from Bulk Directory", 1 );
        check_image_folder( $fsi_dir, $schema );
        _log( $logf, "---- FINISHED ----" );
        exit;
    }
}
elsif ( $single_img_file ) {

    _log( $logf, "DLP Update Type: Updating All Designers with the Same Image", 1 );

    # check if file is there and greater than ZERO bytes in length
    if ( !-e $single_img_file || !-s $single_img_file ) {
        _log( $logf, "Cant't read file or file ZERO bytes: $single_img_file", 1 );
        exit 1;
    }

    $rh_image_info  = parse_single_image( $schema, $single_img_file, $channel_id );
    _log( $logf, 'Parsed Single Image: '.pp($rh_image_info) );
}
else {
    print "Don't know what to upload: use --template_image_directory or --single_image_upload\n";
    exit 1;
}

## Get the page content for these designers
@designer_ids   = keys( %{ $rh_image_info } );
$dpi            = designers_page_instance_ids( \@designer_ids, $channel, $schema->storage->dbh );

my $operator_id = $APPLICATION_OPERATOR_ID;

_log( $logf, 'Designer page instances: ' .pp($dpi) );


##
## Set-Up Web Connections
##

# set the environment first
my $web_environment = "live";
my $status_id;

# staging overrides live
if ( $staging ) {
    # IMPORTANT: publish to staging does not change status BUT needs to switch web environment to staging otherwise we'll be updating live website
    $status_id          = $WEB_CONTENT_INSTANCE_STATUS__PUBLISH;
    $web_environment    = 'staging';
}
elsif ( $live ) { 
    $status_id          = $WEB_CONTENT_INSTANCE_STATUS__PUBLISH;
}
else {
    print "Don't know where to update! Staging or Live\n";
    exit 1;
}

# get web transfer handles
my $transfer_dbh_ref            = get_transfer_sink_handle({ environment => $web_environment, channel => $channel_info->{config_section} });

# get staging web transfer handles
my $staging_transfer_dbh_ref    = get_transfer_sink_handle({ environment => 'staging', channel => $channel_info->{config_section} });

# pass the schema handle in as the source for the transfer
# always from XTracker no matter where we're going for the Web App
$transfer_dbh_ref->{dbh_source}         = $schema->storage->dbh;
$staging_transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;

# get Category Navigation DB Factory object
my $factory = XTracker::DB::Factory::CMS->new( { schema => $schema } );


##
## Update the DLP's
##

my $exit_on_error   = 0;

_log( $logf, "---- START ----", 1 );
_log( $logf, "Number of Designers Found : ".scalar( keys( %{ $dpi } ) ), 1 );

foreach my $designer_id (sort { $a <=> $b } keys( %{ $dpi } ) ) {

    eval {
        my $des_dets            = $dpi->{ $designer_id };
        my $des_img             = $rh_image_info->{ $designer_id };

        my $instance_id         = $des_dets->{instance_id};
        my $page_id             = $des_dets->{page_id};
        my $image               = $des_img->{image};
        my $template_id         = ( $des_img->{template} ? $template_map{ $des_img->{template} }{template_id} : 0 );
        my $fontclass           = ( $des_img->{template} ? $template_map{ $des_img->{template} }{font_class} : undef );
        my $upldfile            = $des_img->{path} . $des_img->{image};

        my $current_page        = $webc_page->find( $page_id );
        my $video_content_id    = instance_content( $instance_id, $WEB_CONTENT_FIELD__DESIGNER_RUNWAY_VIDEO );
        my $image_content_id    = instance_content( $instance_id, $WEB_CONTENT_FIELD__MAIN_AREA_IMAGE );
        my $fontclass_content_id= instance_content( $instance_id, $WEB_CONTENT_FIELD__DESIGNER_NAME_FONT_CLASS );

        print "Processing: " . $des_dets->{designer_id}." - ".$des_dets->{designer} . "\n";
        _log( $logf, 'Processing Designer : ' . $des_dets->{designer_id}." - ".$des_dets->{designer}.", IID: ".$des_dets->{instance_id}.", PGID: ".$des_dets->{page_id} );
        _log( $logf, "    Current Template: " . $current_page->template_id." - ".$current_page->template->name );
        _log( $logf, "    Current Image   : " . $image_content_id->{content_id}." - ".$image_content_id->{current_value}." (FID: ".$image_content_id->{field_id}.")" );
        _log( $logf, "    Current Video   : " . $video_content_id->{content_id}." - ".$video_content_id->{current_value}." (FID: ".$video_content_id->{field_id}.")" );
        _log( $logf, "    Current Font    : " . $fontclass_content_id->{content_id}." - ".$fontclass_content_id->{current_value}." (FID: ".$fontclass_content_id->{field_id}.")" );
        _log( $logf, '    New data        : ' . "Template - ".( $des_img->{template} ? $des_img->{template} : 'N/A' ) . ", Image - ".$des_img->{image}.", Font Class - ". ( $fontclass ? $fontclass : 'N/A' ) );

        my $remote_image_path = 'images/designerFocus/';

        my $err_msg = "";
        my $error   = 0;

        ##### SECTION COPIED AND AMENDED FROM lib/XTracker/WebContent/Actions/UpdateInstance.pm

        # run updates
        eval {
            $schema->txn_do( sub {

                if ( $template_id ) {
                    # update the page template
                    _log( $logf, "    updating template id" );
                    $factory->update_page(
                        {   'page_id'                   => $page_id,
                            'template_id'               => $template_id,
                            'transfer_dbh_ref'          => $transfer_dbh_ref,
                            'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                    );
                }

                # update instance status
                if ( $status_id ) {
                    $factory->set_instance_status(
                                        {   'page_id'                   => $page_id,
                                            'instance_id'               => $instance_id,
                                            'status_id'                 => $status_id,
                                            'operator_id'               => $operator_id,
                                            'environment'               => $web_environment,
                                            'transfer_dbh_ref'          => $transfer_dbh_ref,
                                            'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref}
                                );
                }

                # save the filename
                _log( $logf, "    updating video filename to be empty" );
                $factory->set_content(
                                {   'content_id'                => $video_content_id->{content_id},
                                    'content'                   => '',
                                    'transfer_dbh_ref'          => $transfer_dbh_ref,
                                    'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                );

                if ( $fontclass ) {
                    # Change the Font Class
                    _log( $logf, "    updating font class" );
                    $factory->set_content(
                                    {   'content_id'                => $fontclass_content_id->{content_id},
                                        'content'                   => $fontclass,
                                        'transfer_dbh_ref'          => $transfer_dbh_ref,
                                        'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                    );
                }

                my $file_paths  = get_file_paths( $channel_info->{config_section} );

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
                    _log( $logf, "    uploading image to xTracker: $upldfile to ${destination_dir}${filename}" );
                    eval { # 
                         copy ($upldfile, $destination_dir . $filename)
                             or die ("Couldn't copy file: $upldfile to $destination_dir$filename");
                    };
                    if ( my $err = $@ ) {
                        chomp($err);
                        $err_msg    .= "ERROR UPLOADING IMAGE: $err"."\n";
                        $error      = 1;
                        die "ERROR";
                    }

                    # copy image to web-site dirs
                    _log( $logf, "    copying image file to web" );
                    eval { # just to stop this bombing out while testing ssh
                        copy_image(
                            {
                                'environment'       => $web_environment,
                                'source_dir'        => $destination_dir,
                                'destination_dir'   => $file_paths->{destination_base}. $remote_image_path,
                                'filename'          => $filename,
                            }
                        );
                    };
                    if ( my $err = $@ ) {
                        chomp($err);
                        $err_msg    .= "ERROR COPYING IMAGE: $err"."\n";
                        $error      = 1;
                        die "ERROR";
                    }

                    # save the filename
                    _log( $logf, "    updating image filename" );
                    $factory->set_content(
                                    {   'content_id'                => $content_id,
                                        'content'                   => $filename,
                                        'transfer_dbh_ref'          => $transfer_dbh_ref,
                                        'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                    );
                }

                # finally set the last updated dts and operator for instance if we didn't update that table             
                if ( !$status_id ) {
                    $factory->set_instance_last_updated(
                                        {   'instance_id'               => $instance_id,
                                            'operator_id'               => $operator_id,
                                            'transfer_dbh_ref'          => $transfer_dbh_ref,
                                            'staging_transfer_dbh_ref'  => $staging_transfer_dbh_ref }
                                );
                }

            } );

            $transfer_dbh_ref->{dbh_sink}->commit();
            $staging_transfer_dbh_ref->{dbh_sink}->commit();
        };

        if ( my $err = $@ ) {
            chomp($err);
            _log( $logf, "GOT ERROR:\n$err" );
            _log( $logf, $err_msg )                 if ( $err_msg );

            # rollback website updates on error - XT updates rolled back as part of txn_do
            $transfer_dbh_ref->{dbh_sink}->rollback();
            $staging_transfer_dbh_ref->{dbh_sink}->rollback();

            # use this flag to know if we finished
            # because of an error rather than completed
            # everything
            $exit_on_error  = 1;

            last;
        } else {
            _log( $logf, "SUCCESS" );
        }

    };
    if ( my $err = $@ ) {
        chomp( $err );
        _log( $logf, "($designer_id - $$dpi{ $designer_id }{designer}) Bailed from outer eval: $err" );
    }
}

# disconnect website transfer handles
$transfer_dbh_ref->{dbh_source}->disconnect()               if $transfer_dbh_ref->{dbh_source};
$transfer_dbh_ref->{dbh_sink}->disconnect()                 if $transfer_dbh_ref->{dbh_sink};

$staging_transfer_dbh_ref->{dbh_source}->disconnect()       if $staging_transfer_dbh_ref->{dbh_source};
$staging_transfer_dbh_ref->{dbh_sink}->disconnect()         if $staging_transfer_dbh_ref->{dbh_sink};

if ( $exit_on_error ) {
    _log( $logf, "---- SCRIPT DIDN'T COMPLETE CHECK LOG ----", 1 );
    close($logf);
    exit 1;
}
else {
    _log( $logf, "---- FINISHED ----", 1 );
    close($logf);
    exit;
}


## 
## designers_page_instance_ids (\@designer_ids)
##
## Get the DLP page instance ids for a list of designers
##

sub designers_page_instance_ids {
    my $designers   = shift;
    my $channel     = shift;
    my $dbh         = shift;

    my $qry = "SELECT d.id as designer_id,
                      d.designer,
                      p.id as page_id,
                      i.id as instance_id
                 FROM designer d,
                      designer_channel dc,
                      web_content.page p,
                      web_content.instance i
                WHERE d.id = dc.designer_id
                  AND dc.channel_id = ?
                  AND dc.page_id = p.id
                  AND p.id = i.page_id
                  AND i.status_id = ( SELECT id FROM web_content.instance_status WHERE status = 'Publish' )
                  AND d.id IN ("
            . join( q{, }, (("?") x @$designers))
            . q{) ORDER BY d.designer}
    ;
    my $sth = $dbh->prepare($qry);
    $sth->execute($channel->{id},@$designers);

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
## Takes one argument - a directory containing the _template/images
## 
## Returns a hash of 
## designerid => {template => xxx,  image => 'abc.jpg' };
## 
sub parse_image_folder {
    my $template_image_dir  = shift;

    my %designer_images = ();
    # Get the template directories
    opendir(BUILD, $template_image_dir) ;
    my @template_image_dirs = grep { /.*_template/i } readdir(BUILD);
    close(BUILD);

    foreach my $template ( @template_image_dirs ) {
        # print "Opening $template_image_dir/$template\n";
        opendir(IMAGES, "$template_image_dir/$template") ;
        my @images = grep { /dlp_.*_\d+\..*$/i } readdir(IMAGES);
        close(IMAGES);

        foreach my $image (@images) {
            my $designer_id = $image;
            $designer_id    =~ s/^dlp_.*_(\d+)\..*$/$1/i;
            $designer_images{$designer_id}->{image}     = $image;
            $designer_images{$designer_id}->{path}      = "$template_image_dir/$template/";
            $designer_images{$designer_id}->{template}  = lc($template);
            $designer_images{$designer_id}->{template}  =~ s/_template//;       # get rid of '_template' suffix
        }
    }

    return \%designer_images;
}

##
## parse_single_image
##
## Takes one argument - a directory containing the single image file
## 
## Returns a hash of 
## designerid => {template => xxx,  image => 'abc.jpg' };
## 
## for all designers for a channel
sub parse_single_image {
    my ( $schema, $image_file, $channel_id )    = @_;

    my %designer_images;

    my @des_channels    = $schema->resultset('Public::DesignerChannel')
                                        ->search( { channel_id => $channel_id } )->all;

    foreach my $designer ( @des_channels ) {
        my ( $image, $path )    = File::Basename::fileparse( $image_file );

        my $designer_id                         = $designer->designer_id;
        $designer_images{$designer_id}->{image} = $image;
        $designer_images{$designer_id}->{path}  = $path;
        # force all Designers to use Standard Templates
        $designer_images{$designer_id}->{template}  = 'standard';
    }

    return \%designer_images;
}


sub _log {
    my ( $log, $msg, $tostdout )    = @_;

    print $log $msg . "\n";
    if ( $tostdout ) {
        print $msg . "\n";
    }
}

##
## check_image_folder
## 
## Takes one argument - a directory containing the _template/images
## 
## Checks the directory for images that won't get processed and
## duplicate Designer Id's on files
## 
sub check_image_folder {
    my $template_image_dir  = shift;
    my $schema              = shift;

    my $designer_rs = $schema->resultset('Public::Designer');

    my %designer_images;
    my @non_processed;

    # Get the template directories
    opendir(BUILD, $template_image_dir) ;
    my @template_image_dirs = grep { /.*_template/i } readdir(BUILD);
    close(BUILD);

    

    foreach my $template ( @template_image_dirs ) {
        # print "Opening $template_image_dir/$template\n";
        opendir(IMAGES, "$template_image_dir/$template") ;
        #my @images = grep(/dlp_.*_\d+\..*$/i,readdir(IMAGES));
        my @images = readdir(IMAGES);
        close(IMAGES);

        foreach my $image (@images) {
            next        if ( $image =~ m/^(\.|\.\.)$/ );

            if ( $image =~ m/dlp_.*_\d+\..*$/i ) {
                my $designer_id = $image;
                $designer_id    =~ s/^dlp_.*_(\d+)\..*$/$1/i;
                push @{ $designer_images{$designer_id} }, $template."/".$image;
            }
            else {
                push @non_processed, $template."/".$image;
            }
        }
    }

    print "\n";
    print "NON Processed Images:\n";
    foreach ( @non_processed ) {
        print "    $_"."\n";
    }
    print "\n";

    print "Duplicate Designer Id's:\n";
    foreach my $id ( keys %designer_images ) {
        my $imgs    = $designer_images{ $id };

        if ( scalar( @{ $imgs } ) > 1 ) {
            my $designer    = $designer_rs->find( $id );
            print "    Designer: $id - ".$designer->designer."\n";
            map { print "        $_\n" } @{ $imgs };
        }
    }
    print "\n";

    return;
}


1;
