package XTracker::PrintFunctions;

use strict;
use warnings;

use Carp;
use HTML::HTMLDoc               ();
use PDF::WebKit;
use Perl6::Export::Attrs;
use File::Basename;
use File::Temp qw(tempdir);
use Net::FTP;
use Readonly;
use MIME::Base64;
use Number::Format 'format_bytes';
use IO::File;
use MooseX::Params::Validate 'validated_list';
use XTracker::Comms::SFTP;
use XTracker::Comms::SSH;
use XTracker::Database::Department qw(get_department_by_id);
use XTracker::XTemplate ();
use XTracker::Logfile qw( xt_logger );
use XTracker::Error;
use XTracker::Printers::Zebra::PNG;
use DateTime;
use XT::LP;
use XTracker::PrinterMatrix;
use XT::Rules::Solve;

use XTracker::Config::Local
    qw( config_var get_config_sections config_section_slurp config_section_exists app_root_dir );
use File::Spec;
use File::Path qw( make_path );
use Digest::MD5 qw( md5_hex );

use XTracker::DBEncode  qw( encode_it );

use vars qw($dbh);

Readonly my $PATH_PRINT_DOCS    => config_var('SystemPaths','document_dir');

my %barcode_proxy = (
    'apocalypse' => 'print_apocalypse.sh',
    'phoenix'    => 'print_phoenix.sh',
);

sub print_documents_root_path :Export() {
    return $PATH_PRINT_DOCS;
}

=head1 NAME

XTracker::PrintFunctions

=head1 METHODS

=head2 path_for_print_document

Given the document type and id (and, optionally, file extension), returns the
fully qualified path to the corresponding print document on disk. The file
may or may not already exist. If you want to ensure that the parent directory
exists (for instance, if you're about to create the file), set the
C<ensure_directory_exists> flag in the arguments.

=cut

sub path_for_print_document :Export() {
    my $args = shift;

    # Sanitise incoming arguments.
    # Note that if you pass a 'temp' document type here, the file will be
    # generated under the SystemPaths/document_temp_dir location, and a hashed
    # subdir *won't* be created for it.
    die 'You must supply a document_type' unless $args->{document_type};
    $args->{document_type} = lc $args->{document_type};

    die 'You must supply an id' unless defined $args->{id};

    # Default to creating directories unless told otherwise
    $args->{ensure_directory_exists} = 1 unless exists $args->{ensure_directory_exists};

    # Print document path will be:
    #   BASE/[document_type]/[hash]/[document_type]-[id].[extension]
    #
    # where BASE is the document_dir, document_type is that supplied by the
    # caller, hash is the first two hex characters of an MD5 digest of the
    # filename (document_type-id.extension).
    $args->{extension} //= 'html';
    $args->{extension} =~ s/^\.*//; # ensure no leading .

    # These document types have names that don't follow the convention :(
    my $unprefixed_document_types = [qw(
        rma_request
    )];
    my $bad_separator_document_types = [qw(
        rtv_ship_picklist
        rtv_inspect_picklist
    )];

    # construct the document filename
    my ($doc_prefix, $separator);
    SMARTMATCH: {
        use experimental 'smartmatch';
        $doc_prefix = $args->{document_type} ~~ $unprefixed_document_types ? '' : $args->{document_type};
        $separator = $args->{document_type} ~~ $bad_separator_document_types ? '_' : '-';
    }
    my $doc_basename = $args->{id};

    $doc_basename = join($separator, grep { length } $doc_prefix, $doc_basename)
        if ( $args->{document_type} !~ /^(label|barcode)$/ );
    my $doc_filename = join('.', grep { defined && length } $doc_basename, $args->{extension});

    # construct path for document
    my $base_dir = config_var(
        'SystemPaths', $args->{document_type} eq 'temp' ? 'document_temp_dir' : 'document_dir'
    );
    my @doc_dir_components;
    if ( $args->{path} ) {
        push @doc_dir_components, $args->{path};
    } else {
        # get first 2 characters of MD5 hash of basename (WHM-639)
        my $hex_chars = substr( md5_hex( encode_it($doc_basename) ), 0, 2 );
        push @doc_dir_components, $base_dir, $args->{document_type}, $hex_chars;
    }
    my $doc_dir = File::Spec->catdir( @doc_dir_components );

    # ensure the directory exists, if requested
    if ( $args->{ensure_directory_exists} && ! -d $doc_dir ) {
        my $errors = [];
        if ( ! make_path( $doc_dir, { mode => oct(775), verbose => 0, error => \$errors } ) ) {
            die "Couldn't create print documents subdirectory '$doc_dir': $!";
        }
    }

    my $absolute_path = File::Spec->catfile( @doc_dir_components, $doc_filename );

    # return path relative to print docs root if requested
    if ( $args->{relative} ) {
        ( my $relative_path = $absolute_path ) =~ s{^$base_dir/?}{};
        return $relative_path;
    }

    return $absolute_path;
}

=head2 document_details_from_name

Return document_type and id from supplied name

=cut

sub document_details_from_name :Export() {
    my $document_name = shift;

    my ( $document_basename, $extension) = ( $document_name =~ /^(.*?)(?:\.([^.]+))?$/ );

    # Labels and barcodes are special cases - their names don't follow a sensible naming standard.
    my %special_cases = (
        lbl => 'label',
        png => 'barcode',
    );
    SMARTMATCH: {
        use experimental 'smartmatch';
        if ( ($extension // '') ~~ [keys %special_cases] ) {
            return {
                document_type => $special_cases{$extension},
                id => $document_basename,
                extension => $extension,
            };
        }
    }

    my ( $document_type, $id ) = ( $document_basename =~ /^(.*?)(?:-(.*))?$/ );

    # If we don't have an id, check for special cases which break the normal format
    if (!$id) {
        if ($document_type =~ /^\w+_rma_request_.+$/) {
            # RMA requests use locked hashes for filenames so we probably
            # shouldn't split the channel from the rest :(
            ( $id, $document_type ) = ( $document_type, 'rma_request' );
        }
        elsif ($document_type =~ /^(rtv_(?:ship|inspect)_picklist)_(\d+)$/) {
            ( $id, $document_type ) = ( $2, $1 );
        }
    }

    return {
        document_type => $document_type,
        id => $id,
        ($extension ? (extension => $extension) : ())
    };
}

=head2 path_for_document_name( $filename ) : $absolute_path

Convenience function to return the absolute path for a print document with the supplied
filename. This may not necessarily exist - the path is where that document would be.

=cut

sub path_for_document_name :Export() {
    my $document_name = shift;

    return path_for_print_document(
        {
            %{ document_details_from_name( $document_name ) },
            ensure_directory_exists => 0,
        }
    );
}

=head2 relative_path_for_document_name( $filename ) : $relative_path

Convenience function to return the path, relative to the print_docs root directory, for
a print document with the supplied filename. This may not necessarily exist - the path
is where that document would be.

=cut

sub relative_path_for_document_name : Export() {
    my $document_name = shift;

    return path_for_print_document(
        {
            %{ document_details_from_name( $document_name ) },
            ensure_directory_exists => 0,
            relative => 1,
        }
    );
}

sub get_printer_by_name :Export(:DEFAULT) {
    my $printer_name = shift @_;

    if ( ref($printer_name) eq 'DBI::db' ) {
        $printer_name = shift @_;
        carp("XTracker::PrintFunctions::get_printer_by_name() no longer takes a database handle. This usage is deprecated");
    }
    return  XTracker::PrinterMatrix->new->get_printer_by_name($printer_name);
}

sub get_printer_by_department :Export(:DEFAULT) {
    my ($dept, $large_small) = @_;

    my $key;
    SMARTMATCH: {
        use experimental 'smartmatch';
        $key = ( $large_small ~~ [ 'large', 'small' ] )
            ? "department_$large_small"
            : 'department';
    }

    my $printers = XTracker::PrinterMatrix->new->printer_list->printers;

    foreach my $printer (@$printers) {
        # We might have more than one department using the same printer
        my $depts_ref = $printer->{$key};
        if (ref($depts_ref) ne 'ARRAY') {
            $depts_ref = [ $depts_ref ];
        }

        foreach my $printer_dept (@$depts_ref) {
            if ($printer_dept && ($printer_dept eq $dept)) {
                return $printer;
            }
        }
    }

    # If no printer found, return defaults
    if ($dept eq 'Default') { # prevent infinite recursion
        die("Couldn't find a default printer");
    } else {
        return get_printer_by_department('Default', $large_small);
    }
}

sub create_document :Export(:DEFAULT) {
    my ( $document_name, $temp, $data ) = @_;

    my $html = "";

    my $template = XTracker::XTemplate->template();
    $template->process( $temp, { template_type => 'none', %$data }, \$html );

    my $document_details = document_details_from_name( $document_name );

    my $document_path = path_for_print_document({
        %$document_details,
        extension => 'html',
        ensure_directory_exists => 1,
    });

    open my $fh, ">", $document_path
        or die "Couldn't open $document_path : $!";

    print $fh $html;

    close $fh;
    return $html;
}

sub print_document :Export(:DEFAULT) {
    my ( $document, $printer, $copies, $header, $footer, $should_print_file, $should_delete_file, $page_size, $orientation ) = @_;

    $should_print_file  //= config_var( 'Printing', 'print_file' )  // 1;
    $should_delete_file //= config_var( 'Printing', 'delete_file' ) // 1;

    my $result = $should_print_file ? 0 : 1;
    my $document_details = document_details_from_name( $document );
    if ($document_details->{document_type} eq 'label') {
       $should_delete_file = 0;
       $document = path_for_print_document({ %$document_details,
                                             extension => 'lbl',
                                             ensure_directory_exists => 0, });
    }
    else {
        $document = create_pdf_file($document, $header, $footer, $page_size, $orientation);
    }

    $result = print_file($document, $printer, $copies) if $should_print_file;
    delete_file($document) if $should_delete_file;

    return $result;
}

# Take an HTML file and convert it to PDF for printing
sub create_pdf_file {
    if (config_var('Printing', 'use_webkit')) {
        xt_logger->info('Creating file with webkit');
        return create_pdf_file_with_webkit(@_);
    } else {
        xt_logger->info('Creating file with htmldoc');
        return create_pdf_file_with_htmldoc(@_);
    }
}

sub create_pdf_file_with_webkit {
    my ( $document, $header, $footer, $page_size, $orientation ) = @_;
    # Note that header and footer are not working with Webkit, so those args are
    # ignored. Because of a bug in wkhtmltopdf, the only way to get top and bottom
    # margins working is to use an HTML document for header and footer, which in
    # our case is a blank document.

    my $document_details = document_details_from_name( $document );
    my $in_file = path_for_print_document({
        %$document_details,
        extension => 'html',
        ensure_directory_exists => 0, # must already exist if the file does!
    });

    # if we don't have an input file we can't create an output file!!!!
    # part of REL-859
    if ( ! -e $in_file ) {
        xt_logger->warn("source file for print_document() does not exist: $in_file");
        return;
    }

    (my $out_file = $in_file) =~ s/\.html$/.pdf/;

    my $dummy_html = app_root_dir . 'root/base/print/dummy_for_webkit.html';
    my %print_options = (
        encoding      => 'UTF-8',
        margin_top    => 10,
        margin_bottom => 10,
        margin_left   => 8,
        margin_right  => 8,
        header_spacing  => 5,
        footer_spacing  => 5,
        header_html  => $dummy_html,
        footer_html  => $dummy_html,
    );

    if (defined($orientation)) {
        $print_options{'--orientation'} = $orientation;
    }

    # set appropriate page size for DC
    my $dc_name = config_var('DistributionCentre', 'name');
    if ( defined($page_size) ) {
       $print_options{page_size} = $page_size;
    } elsif ( $dc_name eq "DC2" ) {
       $print_options{page_size} = 'letter';
    } else {
       $print_options{page_size} = 'A4';
    }

    my $webkit = PDF::WebKit->new($in_file, %print_options);

    $webkit->to_file($out_file) || die("Unable to create file $out_file");

    return $out_file;
}

sub create_pdf_file_with_htmldoc {
    my ( $document, $header, $footer ) = @_;

    my $in_file = path_for_document_name( "$document.html" );

    # if we don't have an input file we can't create an output file!!!!
    # part of REL-859
    if ( ! -e $in_file ) {
        xt_logger->warn("source file for print_document() does not exist: $in_file");
        return;
    }

    # ps file should sit in same directory as html file!
    (my $out_file = $in_file) =~ s/\.html$/.pdf/;

    my $tmpdir = File::Temp->newdir();
    my $doc = HTML::HTMLDoc->new( mode => 'file', tmpdir => $tmpdir->dirname );

    my $lp_options = "";

    $doc->set_output_format('ps1');
    $doc->set_charset('UNICODE');

    # set apropriate page size for DC
    my $dc_name = config_var('DistributionCentre','name');
    if ( $dc_name eq "DC2" ) {
       $doc->set_page_size('letter');
    } else {
       $doc->set_page_size('a4');
    }

    $doc->set_input_file($in_file);
    $doc->set_header( '.', 'testing', '.' );   # Adds the html title as a header on each page
    $doc->set_footer( '.', $footer||"", '/' ); # Adds the page number at the bottom of each page
    $doc->set_right_margin( '0.1', 'in' );
    $doc->set_left_margin( '0.25', 'in' );
    $doc->set_bottom_margin( '0', 'in' );
    $doc->set_top_margin( '0.2', 'in' );

    my $pdf = $doc->generate_pdf();
    $pdf->to_file($out_file) || die("Unable to create file $out_file");

    return unless -f $out_file;
    return $out_file;
}

# Send a file to a named printer
sub print_file {
    my ( $out_file, $printer, $copies ) = @_;

    if (!$out_file) {
        xt_logger->error( "Failed to print file to printer: no filename supplied" );
        return;
    }

    my $file_size = _get_human_readable_file_size(-s $out_file);

    xt_logger->info("Printing file: $out_file (size: $file_size)");

    my $printer_info;

    if (ref $printer) {
        $printer_info = $printer;
    }
    else {
        $printer_info = get_printer_by_name($printer);
    }

    my $lp_options = "";

    if ($printer_info->{orientation} && $printer_info->{orientation} eq 'landscape') {
       # $lp_options = "-o landscape"; # rotate 90 degrees
        $lp_options = "-o orientation-requested=5"; # rotate 270 degrees
    }

    my $output = XT::LP->print(
        {
            printer     => $printer_info->{lp_name},
            copies      => $copies,
            orientation => $printer_info->{orientation},
            filename    => $out_file,
        }
    );
    if ( $output =~ m/^request id.*/ ) {
        return 1;
    }
    else {
        xt_logger->error(
            "Failed to print file ($out_file) to printer "
          . "($printer_info->{lp_name}). Output from printer doesn't "
          . "contain 'request id': ($output)",
        );
    }

    return;
}

# Delete a file after it has been printed
sub delete_file {
    my ( $out_file ) = @_;

    xt_logger->info("Deleting file: $out_file");

    ### clean up pdf file
    if (-e $out_file) {
        unlink $out_file
            or xt_logger->error("Could not delete file ($out_file): $!");
    } else {
        xt_logger->warn("trying to remove nonexistent file: ($out_file)");
    }
    return;
}

sub log_shipment_document :Export(:DEFAULT) {
    my ( $dbh, $shipment_id, $document, $file, $printer_name ) = @_;

    my $qry = "INSERT INTO shipment_print_log VALUES (default, ?, ?, ?, ?, current_timestamp)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $shipment_id, $document, $file, $printer_name );
}

sub print_large_label :Export(:DEFAULT) {
    my ( $itemref, $printer_info, $copies ) = @_;

    if (!ref($printer_info)){
        $printer_info = XTracker::PrinterMatrix->new->get_printer_by_name($printer_info);
    }

    my $canvas_size = 60;

    $copies ||= 1;

    my $template = XT::Rules::Solve->solve('PrintFunctions::large_label_template' => {
        print_language => $printer_info->{print_language},
        printer_name =>  $printer_info->{name},
    });

    $template =~ s/\*sku\*/$$itemref{sku}/gi;

    my $sku_horizontal = int( 450 - ( length($$itemref{sku}) * 20 ) );
    $template =~ s/\*sku_x\*/$sku_horizontal/;

    my $bc_horizontal = int( 350 - ( length($$itemref{sku}) * 20 ) );
    $template =~ s/\*bc_x\*/$bc_horizontal/;

    my $size_horizontal = 750 - int( length($$itemref{designer_size}) * 8 );

    $template =~ s/\*size\*/$$itemref{designer_size}/;
    $template =~ s/\*size_x\*/$size_horizontal/;

    my $des_horizontal = int( 400 - ( length( $$itemref{designer} ) * 8 ) );

    $template =~ s/\*designer\*/$$itemref{designer}/;
    $template =~ s/\*designer_x\*/$des_horizontal/;

    my $col_horizontal = int( ( $canvas_size / 2 ) + 10 );
    if ( exists $$itemref{colour} && $$itemref{colour} ) {
        $col_horizontal = int( ( ($canvas_size - ( length($$itemref{colour}) ) ) / 2 ) + 10 );
    }

    $$itemref{colour} = '' if ( $$itemref{colour} eq 'Unknown' );
    $template =~ s/\*colour\*/$$itemref{colour}/;
    $template =~ s/\*col_x\*/$col_horizontal/;

    my $seas_horizontal = 400;

    if ( exists $$itemref{season} && $$itemref{season} ) {
        $seas_horizontal = int( 400 - ( length($$itemref{season}) * 4 ) );
    }

    $$itemref{season} ||= "";
    $template =~ s/\*season\*/$$itemref{season}/;
    $template =~ s/\*season_x\*/$seas_horizontal/;

    my $nap_horizontal = 300;
    $template =~ s/\*nap_x\*/$nap_horizontal/;

    $template =~ s/\*count\*/$copies/;

    my $temp_label_path = path_for_print_document({
        document_type => 'temp',
        id => 'large_label',
        extension => 'txt',
    });
    my $output_fh;
    open ($output_fh, ">:encoding(UTF-8)", $temp_label_path) || die("Unable to create temporary file for printing");
    print $output_fh "$template";
    close ($output_fh);

    XT::LP->print(
        {
            printer     => $printer_info->{lp_name},
            copies      => 1,
            filename    => $temp_label_path,
            orientation => undef,
        }
    );
    return $template;
}

sub print_small_label :Export(:DEFAULT) {
    my ($itemref, $printer_info, $copies ) = @_;

    if (!ref($printer_info)){
        $printer_info = XTracker::PrinterMatrix->new->get_printer_by_name($printer_info);
    }

    $copies ||= 1;

    my $template = XT::Rules::Solve->solve('PrintFunctions::small_label_template' => {
        print_language => $printer_info->{print_language},
        printer_name =>  $printer_info->{name},
    });

    my $size_len = ( 300 - (length($$itemref{designer_size}) * 10 ));
    my $bar_len  = ( 175 - (length($$itemref{sku}) * 10 ));

    $template =~ s/\*sku\*/$$itemref{sku}/gi;
    $template =~ s/\*size\*/$$itemref{designer_size}/;
    $template =~ s/\*size_x\*/$size_len/;
    $template =~ s/\*bar_x\*/$bar_len/;
    $template =~ s/\*count\*/$copies/;

    my $temp_label_path = path_for_print_document({
        document_type => 'temp',
        id => 'small_label',
        extension => 'txt',
    });
    my $output_fh;
    open ($output_fh, ">", $temp_label_path) || die("Unable to create temporary file for printing");
    print $output_fh "$template";
    close ($output_fh);

    XT::LP->print(
        {
            printer     => $printer_info->{lp_name},
            copies      => 1,
            filename    => $temp_label_path,
        }
    );
    return $template;
}

=head2 print_mrp_sticker

Prints personalised sticker for shipment at picking/packing time

=cut

sub print_mrp_sticker :Export() {
    my ($text, $printer, $copies) = validated_list(
        \@_,
        text    => { isa => 'Str' },
        printer => { isa => 'Str' }, # can be an IP or a hostname
        copies  => { isa => 'Int' },
    );

    # Build 'MR PORTER' graphic (logo)

    my $base_dir = config_var('SystemPaths','xtdc_base_dir');
    my $logo_filename = 'LOGO';
    my $logo = XTracker::Printers::Zebra::PNG->new({
        source_png  => $base_dir.'/root/static/images/logo.png',
        filename    => $logo_filename,
        to_mem_only => 1,
    });

    # Build person's name graphic (label)

    my $font = $base_dir.'/root/static/font/MrPorterBeta.otf';

    my $label_filename = 'NAME';
    my $label = XTracker::Printers::Zebra::PNG->new({
        text        => $text,
        font        => $font,
        filename    => $label_filename,
#    if you want to just output to memory of printer and not print set to_mem_only here
#        to_mem_only =>  1,
    });

    $label->pre("^PW".$label->label_width."^LL".$label->label_height."LH0,0\n");
    $label->post("^FO0,520^XGR:$logo_filename.GRF,1,1^FS\n");

    # Build whole sticker

    my $content = $logo->final;

    for (1 .. $copies){
        $content .= $label->final;
    }

    # Print sticker

    my $temp_sticker_path = path_for_print_document({
        document_type => 'temp',
        id => 'mrp_sticker',
        extension => 'txt',
    });

    my $output_fh = IO::File->new( $temp_sticker_path, '>' )
      or die "Unable to open file '$temp_sticker_path': $!\n";
    $output_fh->binmode;
    $output_fh->print( $content );
    $output_fh->close;

    my $printer_info = XTracker::PrinterMatrix->new->get_printer_by_name($printer);

    XT::LP->print(
        {
            printer     => $printer_info->{lp_name},
            copies      => 1,
            filename    => $temp_sticker_path,
        }
    );
}

sub print_label :Export() {
    my ( $dbh, $p ) = @_;

    eval {
        die "type not defined"            unless $p->{type};
        die "id not defined"              unless $p->{id};
        die "department_id not defined"   unless $p->{department_id};
    };
    if ( $@ ) {
        croak $@;
    }

    my $prod_data = _get_barcode_info( $dbh, { type => $p->{type}, id => $p->{id} } );

    my $dept = get_department_by_id($dbh, $p->{department_id});

    my $large_printer = get_printer_by_department( $dept, 'large' )->{lp_name};
    my $small_printer = get_printer_by_department( $dept, 'small' )->{lp_name};

    if ( $p->{print_large} && ($p->{print_large} == 1) ) {
        print_large_label($prod_data, $large_printer, $p->{num_large});
    }

    if ( $p->{print_small} && ($p->{print_small} == 1) ) {
        print_small_label($prod_data, $small_printer, $p->{num_small});
    }
}

=head2 print_ups_label

usage        : print_ups_label(
                    {
                        prefix      => 'outward' || 'return',
                        unique_id   => $unique_id,
                        label_data  => $label_data,
                        printer     => $label_printer
                    }
                );

description  : This function will print out a UPS label to a supplied printer. It will first
               create the label file in the 'print-docs/label' directory and then print it.
               The name of the label file will be made up using the 'prefix' & 'unique_id' and
               with a '.lbl' extension. The 'label_data' supplied will be written to the file.

parameters   : An Anonymous HASH of parameters: Prefix for the filename, Unique Id for the filename,
               Label Data containing the label to be written to the file and the Printer to print
               to.
returns      : Nothing.

=cut

sub print_ups_label :Export() {
    my $args        = shift;

    die "No Args Passed"            if ( !defined $args || ref($args) ne "HASH" );

    die "No Prefix Passed"          if ( !defined $args->{prefix} );
    die "No Unique Id Passed"       if ( !defined $args->{unique_id} );
    die "No Label Data Passed"      if ( !defined $args->{label_data} );
    die "No Printer Passed"         if ( !defined $args->{printer} );

    my $printer_info= XTracker::PrinterMatrix->new->get_printer_by_name( $args->{printer} );
    if ( !defined $printer_info ) {
        die "Couldn't Find Printer: ".$args->{printer}." in Config File";
    }

    my $filename = XTracker::PrintFunctions::path_for_print_document({
        document_type => 'label',
        id => $args->{prefix} . '-' . $args->{unique_id},
        extension => 'lbl',
    });
    # test we can write to either the file of the path
    # to create a file
    if ( -e $filename ) {
        if ( ! -w $filename ) {
            die "Don't have permissions to overwrite file: $filename";
        }
    }
    else {
        if ( ! -w "$PATH_PRINT_DOCS/label" ) {
            die "Don't have permissions to write to: $PATH_PRINT_DOCS/label";
        }
    }

    # decode base64 encoded label data string from UPS
    my $decoded_str = decode_base64( $args->{label_data} );

    # write decoded label data to a label file
    open(my $fh, ">:encoding(utf8)", $filename ) || die "Couldn't open file for writing: $filename";
    binmode $fh;
    print $fh $decoded_str;
    close($fh);

    ### printing via LP
    my $prn_output = XT::LP->print(
        {
            printer     => $printer_info->{lp_name},
            copies      => 1,
            filename    => $filename,
            orientation => undef,
        }
    );

    # if 'request id' is in the output returnred from printing
    # then return success else failure
    return ( $prn_output =~ m/^request id.*/ ? 1 : 0 );
}

sub _get_barcode_info {
    my ( $dbh, $p ) = @_;

    my $clause;

    if ( $p->{type} eq 'variant_id' ) {
        $clause = qq{ v.id = ?  };
    }
    elsif ( $p->{type} eq 'legacy_sku' ) {
        $clause = qq{ v.legacy_sku = ?  };
    }
    else {
        croak 'type not defined';
    }

    my $qry = qq{
select v.legacy_sku, d.designer, s.season, c.colour, si.size, p.id as product_id, v.size_id,
       product_id || '-' || sku_padding(v.size_id) as sku, si2.size as designer_size
from variant v, product p, designer d, season s, colour c, size si, size si2
where $clause
and v.product_id = p.id
and p.designer_id = d.id
and p.season_id = s.id
and p.colour_id = c.id
and v.size_id = si.id
AND v.designer_size_id = si2.id
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( $p->{id} );

    my $data = $sth->fetchrow_hashref();
    return $data;
}

# so we can see if we're jamming rubbish printers with
# massive documents it can't handle.

sub _get_human_readable_file_size {
    my $num_bytes = shift;
    return format_bytes($num_bytes, precision => 1);
}

1;
