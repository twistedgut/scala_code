package XTracker::Image;

use strict;
use warnings;
use Carp;

use Data::Dump qw(pp);
use Net::SFTP::Constants qw( SSH2_FX_OK :flags );
use Perl6::Export::Attrs;
use Readonly;
use XTracker::Comms::SFTP;
use XTracker::Database;
use XTracker::Utilities qw( portably_get_basename );
use XTracker::Constants::FromDB qw( :business );

use XTracker::Config::Local qw( config_var get_pws_webservers );

# Declare package-wide accepted image extensions
our @image_extensions = qw(gif jpg jpeg png swf f4v);

Readonly my $PATH_IMAGES  => config_var('SystemPaths','product_images_dir');

=head1 NAME

XTracker::Image

=head1 DESCRIPTION

Do image related stuff for XTracker.

=head1 METHODS

=head2 get_images({ product_id => $product_id, live => $bool, size => $size, schema => $schema, business_id => $business_id })

Returns images for a given C<$product_id>. Accepts optional values for a
hashref with keys for C<live> and C<size>, and a C<$schema> object. If a
C<$schema> object is not passed, the sub will get non-live images for the
product and I<not> create its own, as it's expensive. In other words to get a
live image you B<have> to pass C<< schema => $schema >>.
>>.

Passing the 'business_id' in conjunction with the 'live' flag prevents a lot
of access to the database when calling this function for multiple images
and can vastly increase the speed of retrieving the image file names.

If 'image_host_url' is passed in, use that as the source of images, otherwise
choose the default content server as defined in the config file.

If 'reverse_non_live' was passed, in case if 'live' is false (buy sheet images)
the list of images will be reversed.

=cut

sub get_images :Export(:DEFAULT) {
    my($args_ref) = @_;

    my @images;
    my $product_id  = $args_ref->{product_id}
        || croak 'You must pass a value for product_id';
    my $live        = $args_ref->{live};
    my $size        = $args_ref->{size} || q{m};
    my $schema      = $args_ref->{schema};
    my $business_id = $args_ref->{business_id};         # business id of the channel for the product - optional see above doc
    my $image_url   = $args_ref->{image_host_url} || config_var('Images','image_host_url');
    my $reverse_non_live = $args_ref->{reverse_non_live};

    my $image_path = "images/products/$product_id";

    my $product_channel;
    # Only determine whether product is live if we have a $schema object and
    # we don't know its status

    if($schema){
        $product_channel = __PACKAGE__->_get_product_channel( $schema, $product_id );
        $live //= $product_channel->is_live;
    }

    if($product_channel && $product_channel->channel->is_on_jc){
        @images = _get_external_images($product_channel->product);
    } elsif ( $live ) {
        # get live website images
        # set a flag to determin if the product is for MrP
        my $is_on_mrp   = 0;

        if ( !defined $business_id ) {
            # Find out if the product is on mrporter - we may already have
            # $product_channel from earlier
            if ($schema) {
                $product_channel ||= __PACKAGE__->_get_product_channel(
                    $schema,$product_id );
            }

            $is_on_mrp = $product_channel
                ? $product_channel->channel->is_on_mrp
                : undef;
        }
        else {
            # use the business id to determine if it's on MrP
            $is_on_mrp  = ( $business_id == $BUSINESS__MRP ? 1 : 0 );
        }

        my $filename = $is_on_mrp ? "${product_id}_mrp" : $product_id;

        # As the 'm' size is different for mrp, make sure if a size is
        # explicitly passed we switch to the right size on the channel.
        $size = ( $is_on_mrp and $size =~ m{^m$} )      ? 'm3'
              : ( not $is_on_mrp and $size =~ m{^m[23]$} ) ? 'm'
              :                                           $size;
        push @images, "$image_url/$image_path/${filename}_in_$size.jpg";

        # back and close up shot default to x small size
        push @images, "$image_url/$image_path/${filename}_bk_xs.jpg";
        push @images, "$image_url/$image_path/${filename}_cu_xs.jpg";
    }
    # Check for buy sheet images
    else {
        my @filenames = ( 12, 36, 66, 100, 200, 300 );
        @filenames = reverse @filenames if $reverse_non_live;
        @images = map {
            "/$image_path/$_.jpg"
        } grep { -e "$PATH_IMAGES/$product_id/$_.jpg" } @filenames;
    }

    # fill any empty slots in array
    while (scalar @images < 3){
        push @images, '/images/blank.gif';
    }

    return \@images;
}


=head2 _get_external_images

Returns a list with all the external images for a product

=cut

sub _get_external_images{
    my ($product) = @_;
    my @image_list;
    for my $image ($product->external_image_urls->all){
        push @image_list, $image->url;
    }
    return @image_list;
}

=head2 get_image_list( $schema, \@prod_ref, $size, )

Return a hashref in the format C<< { $pid => $image_path } >>. C<\@prod_ref>
is an array of hashes that have the keys C<$product_id> or C<$id>, and
C<$live>.

You should pass your own $schema else it'll create one for you!

=cut

sub get_image_list :Export(:DEFAULT) {
    my ( $schema, $prod_ref, $size ) = @_;
    $schema ||= XTracker::Database::get_schema_and_ro_dbh('xtracker_schema');

    my %img = ();
    $size ||= 's';

    foreach my $product ( @$prod_ref ){
        my $product_id  = $product->{product_id} || $product->{id};

        my $product_channel = __PACKAGE__->_get_product_channel( $schema, $product_id );

        # Only make the db call if we don't know the value of live
        my $live = defined $product->{live} ? $product->{live} : $product_channel->is_live;

        if($product_channel && $product_channel->channel->is_on_jc){
            my $first_image = $product_channel->product->external_image_urls->first;
            $img{$product_id} = $first_image ? $first_image->url : '/images/blank.gif';
        } elsif ( $live ) {
            # get live website images
            $img{$product_id} = shift @{ get_images({
                schema => $schema,
                product_id => $product_id,
                live => 1,
                size => $size,
                business_id => $product->{business_id},
            }) };
        }
        # check for buy sheet images
        else {
            if (-e "$PATH_IMAGES/$product_id/100.jpg") {
                $img{$product_id} = "/images/product/$product_id/100.jpg";
            }
            else {
                $img{$product_id} = '/images/blank.gif';
            }
        }
    }
    return \%img;
}

sub _get_product_channel {
    my($self,$schema,$product_id) = @_;
    die "Need to pass in \$schema" if (!$schema);

    # prefetch channel info as we are using it immediately
    my $product = $schema->resultset('Public::Product')->find(
        $product_id,
        {
            prefetch => { product_channel => 'channel' },
        }
    );
    return $product->get_product_channel_for_images
        if $product;
    # We have a voucher
    return $schema->resultset('Voucher::Product')->find($product_id);
}

### Subroutine : get_images_from_dir            ###
# usage        : $image_list_ref                  #
#                   = get_images_from_dir($dir)   #
# description  : Returns a reference to a list of #
#                images from a given directory    #
# parameters   : $dir with images                 #
# returns      : $image_list_ref                  #

sub get_images_from_dir :Export(:DEFAULT) {
    my ( $dir ) = @_;

    my @names  = ();
    my @sorted = ();

    if( opendir my $dh, $dir ){
        foreach  my $file  ( grep { !/^\./ } readdir $dh ){
            if ( _has_img_ext($file) ) {
                push @names, $file;
            }
        }
        closedir $dh;
        @sorted = sort(@names);

    }

    return \@sorted;
}

### Subroutine : _has_img_ext                   ###
# usage        : _has_img_ext($file)              #
# description  : Checks whether a given file has  #
#                an extension specified in        #
#                @image_extensions                #
# parameters   : $file                            #
# returns      : 1 if match, 0 otherwise          #

sub _has_img_ext {
    my ( $file ) = @_;
    foreach my $image_ext (@image_extensions) {
        if ( $file =~ /\.$image_ext$/i ) {
            return 1;
        }
    }
    return 0;
}

### Subroutine : upload_image                   ###
# usage        : copy_file(                       #
#                   Apache::Upload object,       #
#                   $dir                          #
#                )                                #
# description  : Uploads a file to the given      #
#                destination directory            #
# parameters   : $fullname, $dest_dir             #
# returns      : 1 if successful, 0 if not        #

sub upload_image :Export(:DEFAULT) {
    my ($upload, $destination_dir, $filename) = @_;

    # Set upload filehandle
    my $fh = $upload->fh;

    # Check extension
    if( not _has_img_ext( $upload->filename() ) ) {
        return (0, "The file does not have a recognised image extension");
    }


    my $output_file;

    # use filename provided if set
    if ($filename) {
        $output_file = $destination_dir . '/' . $filename;
    }
    # Make sure upload->filename returns just basename for cross-platform purposes
    else {
        $output_file = $destination_dir . '/' . portably_get_basename($upload->filename());
    }

    open my $OUTPUTFILE, '>', $output_file or return (0, $!);

    binmode($fh);
    binmode($OUTPUTFILE);

    # Print to OUTPUTFILE
    while(<$fh>) {
        print ($OUTPUTFILE $_);
    }
    close $fh;
    close $OUTPUTFILE;

    return 1;
}

=head2 sync_to_staging

=cut

sub sync_to_staging :Export(:DEFAULT) {
    my ( $image, $from, $to ) = @_;

    my $sftp           = get_staging_sftp_handle();
    my $remote_path   = "$to/$image";
    my $remote_fh     = $sftp->do_open($remote_path, (SSH2_FXF_WRITE | SSH2_FXF_CREAT));

    open my $SOURCE, '<', "$from/$image" or die "Unable to open file $from/$image\n";

    if (!defined($remote_fh)) {
        die("Unable to open remote file $remote_path\n");
    }

    # Set do_write args
    my $chunk_size = 1024;
    my $chunk      = '';
    my $offset     = 0;
    my $write_err  = SSH2_FX_OK;
    my $chars_read = 0;

    while (read($SOURCE, $chunk, $chunk_size)) {
    $chars_read = length($chunk);
    $write_err = $sftp->do_write($remote_fh, $offset, $chunk);
    if ($write_err != SSH2_FX_OK) {
        die("SFTP error writing upload file $remote_path: $write_err\n");
    }
    $offset += $chars_read;
    }

    close $SOURCE;
    $sftp->do_close($remote_fh);
}

=head2 copy_image

=cut

sub copy_image :Export(:DEFAULT) {
    my ( $arg_ref ) = @_;

    # check required args
    if ( !defined($arg_ref->{'environment'}) ) {
        die "No environment specified\n";
    }

    if ( !defined($arg_ref->{'destination_dir'}) ) {
        die "No destination directory specified\n";
    }

    if ( !defined($arg_ref->{'source_dir'}) ) {
        die "No source directory specified\n";
    }

    if ( !defined($arg_ref->{'filename'}) ) {
        die "No filename specified\n";
    }

    my %args = ();

    # local and remote files
    $args{'local_path'}     = $arg_ref->{'source_dir'}.$arg_ref->{'filename'};
    $args{'remote_path'}    = $arg_ref->{'destination_dir'}.$arg_ref->{'filename'};

    # for live we have multiple webservers upload to
    if ( $arg_ref->{'environment'} eq 'live' ) {

        my $webservers = get_pws_webservers();

        foreach my $server_name ( @{$webservers} ) {

            $args{'sftp_handle'} = get_sftp_handle($server_name);
            sftp_image(\%args);

        }
    }
    # staging
    elsif ( $arg_ref->{'environment'} eq 'staging' ) {

        $args{'sftp_handle'} = get_sftp_handle('StagingFCP');
        sftp_image(\%args);

    }
    # default to DEV
    else {

        $args{'sftp_handle'} = get_sftp_handle('DevFCP');
        sftp_image(\%args);

    }

    return 1;

}

=head2 sftp_image

=cut

sub sftp_image :Export(:DEFAULT) {
    my ( $arg_ref ) = @_;

    # check required args
    if ( !defined($arg_ref->{'sftp_handle'}) ) {
        die "No environment specified\n";
    }

    if ( !defined($arg_ref->{'local_path'}) ) {
        die "No destination directory specified\n";
    }

    if ( !defined($arg_ref->{'remote_path'}) ) {
        die "No source directory specified\n";
    }

    my $sftp_handle = $arg_ref->{'sftp_handle'};
    my $local_path  = $arg_ref->{'local_path'};
    my $remote_path = $arg_ref->{'remote_path'};

    # open remote file handle
    my $remote_fh   = $sftp_handle->do_open($remote_path, (SSH2_FXF_WRITE | SSH2_FXF_CREAT));

    if (!defined($remote_fh)) {
        die("Unable to open remote file $remote_path\n");
    }

    # open local file
    open my $SOURCE, '<', $local_path or die "Unable to open file $local_path\n";

    # Set do_write args
    my $chunk_size = 1024;
    my $chunk      = '';
    my $offset     = 0;
    my $write_err  = SSH2_FX_OK;
    my $chars_read = 0;

    # read local file and write out to remote handle
    while (read($SOURCE, $chunk, $chunk_size)) {
        $chars_read = length($chunk);
        $write_err = $sftp_handle->do_write($remote_fh, $offset, $chunk);

        if ($write_err != SSH2_FX_OK) {
            die("SFTP error writing upload file $remote_path: $write_err\n");
        }

        $offset += $chars_read;
    }

    close $SOURCE;

    $sftp_handle->do_close($remote_fh);

    return 1;
}

1;
