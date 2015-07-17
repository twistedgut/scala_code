package XTracker::Script::PrintDocs::Relocate;

use Moose;

extends 'XTracker::Script';
with 'XTracker::Script::Feature::SingleInstance';

use XTracker::Config::Local 'config_var';
use File::Find::Rule;
use XTracker::PrintFunctions;
use File::Basename;

sub invoke {
    my ( $self, %args ) = @_;

    my @directories = map { config_var( 'SystemPaths', $_ ) } qw(
        barcode_dir
        document_dir
        document_temp_dir
        document_label_dir
        document_rtv_dir
    );

    $self->move_files({ directory => $_, %args }) for @directories;

    return 0;
}

sub move_files {
    my ( $self, $args ) = @_;

    my $verbose = !!$args->{verbose};
    my $dry_run = !!$args->{dryrun};
    my $directory = $args->{directory};

    $verbose && printf("%sMoving documents from %s\n",
        ( $dry_run ? 'TESTING ' : '' ),
        $directory,
    );

    # Loop through files in directory
    my $rule = File::Find::Rule
        ->file
        ->maxdepth( 1 )
        ->start( $directory );

    while ( defined ( my $old_path = $rule->match ) ) {
        my $filename = basename( $old_path );
        my $document_details = XTracker::PrintFunctions::document_details_from_name( $filename );
        if ( !defined $document_details->{id} ) {
            next if $filename =~ /(?:small|large)_label\.txt/; # safe to disregard these temporary files
            warn sprintf("  %s %s - cannot determine ID\n",
                $dry_run ? 'Would not move' : 'Cannot move',
                $old_path,
            );
            next;
        }
        my $new_path = XTracker::PrintFunctions::path_for_print_document({
            %$document_details,
            ensure_directory_exists => !$dry_run,
        });
        $verbose && printf("%s %s -> %s\n",
            $dry_run ? 'Would move' : 'Moving',
            $old_path,
            $new_path,
        );
        unless ( $dry_run ) {
            rename $old_path, $new_path || warn "Failed to move $old_path -> $new_path : $!";
        }
    }

    $verbose && print "\n";
}

1;
