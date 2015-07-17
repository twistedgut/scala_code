package XT::Data::Order::Import::Role::ManipulateOrderFiles;
use NAP::policy "tt", 'role';

=head1 NAME

XT::Data::Order::Import::Role::ManipulateOrderFiles

=head1 DESCRIPTION

Role that allows classes access to useful functions when dealing with order xml files

=cut

use MooseX::Params::Validate qw/validated_list/;
use XTracker::Config::Local qw/config_var config_section_slurp/;
use File::Path qw(make_path remove_tree);
use IO::File;
use File::Find;

requires qw/schema/;

has 'order_import_shipping_method_paths' => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $output_dir = config_var('SystemPaths', 'xmparallel_dir');
        die 'No output directory configured' unless $output_dir;
        my $priority_by_shipping_method = config_section_slurp('ParallelOrderImporterShippingPriorities');

        my %paths = map {
            my $shipping_method_directory = $priority_by_shipping_method->{$_};
            die "No sub-directory configured for shipping method '$_'" unless $shipping_method_directory;
            $_ => "$output_dir/" . sprintf(
                '%02d-%s',
                $priority_by_shipping_method->{$_},
                uc($_)
            );
        } keys %$priority_by_shipping_method;

        return \%paths;
    }
);

=head1 METHODS

=head2 clear_all_shipping_methods

Clear all of the xml files (including the sub folders) from each shipping methods order path.

e.g 'rm -rf var/data/xmparallel/*'

=cut
sub clear_all_shipping_methods {
    my ($self) = @_;

    my @shipping_methods = keys %{config_section_slurp('ParallelOrderImporterShippingPriorities')};
    $self->clear_shipping_method({
        shipping_method => $_,
    }) for @shipping_methods;
}

=head2 clear_shipping_method

Clear all of the xml files (including the sub folder) for a single shipping method.
Will throw an exception if passes an invalid shipping method

e.g 'rm -rf var/data/xmparallel/47-STANDARD'

param - shipping_method : The shipping method to remove

=cut
sub clear_shipping_method {
    my ($self, $shipping_method) = validated_list( \@_,
        shipping_method => { required => 1, isa => "Str" },
    );

    die 'Unknown shipping method'
        unless defined(config_section_slurp('ParallelOrderImporterShippingPriorities')->{$shipping_method});
    remove_tree($self->order_import_shipping_method_paths()->{$shipping_method});
    return 1;
}

=head2 add_order_file_to_shipping_method

Will create a new xml order file for a given shipping method

TODO: 'order_number' param should probably be worked out automatically
TODO: 'contents' should be validated as XML or possibly be generated?

param - shipping_method : The shipping method to create a file for
param - status : Status of the file
param - channel : Channel DBIC result object for the channel that this order
    belongs to
param - order_number : The order number
param - order_file_number : Number that is required to distinquish between files where
    all the above params match
param - contents : (Optional) The contents of the new file
param - modification_time : (Optional) The add/modification date of the new file

=cut
sub add_order_file_to_shipping_method {
    my ($self, $shipping_method, $status, $channel, $order_number,
        $order_file_number, $contents, $modification_time) = validated_list(\@_,
        shipping_method     => { required => 1, isa => "Str" },
        status              => { required => 1, isa => "Str" },
        channel             => { required => 1 },
        order_number        => { required => 1, isa => "Str" },
        order_file_number   => { required => 1, isa => "Int" },
        contents            => { isa => "Str", default => "Some test data" },
        modification_time   => { isa => "Str" },
    );

    my $priority_by_business_name = config_section_slurp('ParallelOrderImporterBusinessPriorities');
    my $status_sub_dirs = config_section_slurp('ParallelOrderImporterNames');
    my $shipping_method_paths = $self->order_import_shipping_method_paths();

    die "Unknown status '$status'" unless defined($status_sub_dirs->{$status});
    die "Unknown shippingmethod '$shipping_method'" unless defined($shipping_method_paths->{$shipping_method});

    my $file_name = sprintf(
        '%01d-%s-order-%s-%03d.xml',
        $priority_by_business_name->{$channel->config_name()},
        $channel->config_name(),
        $order_number,
        $order_file_number
    );

    my $path = $shipping_method_paths->{$shipping_method}
        . "/" . $status_sub_dirs->{$status}
        . "/";

    make_path($path);

    if(my $file_handle = IO::File->new($path . $file_name, "w")) {
        print $file_handle $contents;
        $file_handle->close();
    } else {
        die 'Problem creating file: ' . $path . $file_name;
    }

    # If a modification time has been supplied for the file, change it
    if ($modification_time) {
        utime $modification_time, $modification_time, ($path . $file_name);
    }

    return 1;
}

=head2 get_unimported_order_file_paths

Get a list of file paths for all of the unimported order xml files for a single channel

param - $channel : Channel DBIC Result object for channel to get file paths for

return - $file_paths : Array ref of order xml file paths for the channel

=cut
sub get_unimported_order_file_paths {
    my ($self, $channel) = @_;

    my @order_import_shipping_method_paths = values %{$self->order_import_shipping_method_paths()};
    my $ready_folder = config_section_slurp('ParallelOrderImporterNames')->{'ready'};

    my @actual_method_paths;
    for my $method_path (@order_import_shipping_method_paths) {
        push @actual_method_paths, "$method_path/$ready_folder" if -d $method_path;
    }

    my @order_files;
    find(sub {
        my $file_name = $_;
        my $file_path = $File::Find::name;

        # Only want files (not directories)
        return unless -f $file_path;

        # Only want files for the specified channels
        my $key = $channel->config_name() . '-order';
        return unless $file_name =~ /$key/;

        push(@order_files, $file_path);
    }, @actual_method_paths) if @actual_method_paths;

    return \@order_files;
}
