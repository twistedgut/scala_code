package XTracker::Database::RTV;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use Hash::Util                          qw(lock_hash);
use Scalar::Util qw/blessed/;
use Perl6::Export::Attrs;
use Readonly;
use HTML::HTMLDoc;
use PDF::WebKit;
use XTracker::Barcode;
use XTracker::Config::Local             qw(dc_address dc_fax config_var);
use XTracker::Constants::FromDB qw(
    :flow_status
    :purchase_order_status
    :purchase_order_type
    :rma_request_detail_status
    :rma_request_detail_type
    :rma_request_status
    :rtv_action
    :rtv_inspection_pick_request_status
    :rtv_shipment_detail_result_type
    :rtv_shipment_detail_status
    :rtv_shipment_status
    :stock_action
    :stock_order_item_status
    :stock_order_status
    :stock_order_type
    :stock_process_type
);
use XTracker::Database                  qw(:common);
use XTracker::Database::Logging         qw(:rtv log_stock);
use XTracker::Database::Stock           qw(update_quantity delete_quantity insert_quantity get_stock_location_quantity check_stock_location);
use XTracker::Database::StockProcess    qw(create_stock_process set_stock_process_status);
use XTracker::Database::Utilities;
use XTracker::DBEncode                  qw(encode_db);
use XTracker::Image                     qw(get_images);
use XTracker::Logfile                   qw(xt_logger);
use XTracker::PrintFunctions            qw(get_printer_by_name);
use XTracker::EmailFunctions            qw( send_email );
use XTracker::Utilities                 qw(:string get_date_db);
use XTracker::XTemplate;
use File::Spec;

#-------------------------------------------------------------------------------
# RTV Constants
#-------------------------------------------------------------------------------
Readonly my $iws_rollout_phase              => config_var('IWS', 'rollout_phase');

my %DOCNAME_RMA_REQUEST = (
    'NET-A-PORTER.COM'  => 'NAP_rma_request',
    'theOutnet.com'     => 'OUT_rma_request',
    'MRPORTER.COM'      => 'MRP_rma_request',
    'JIMMYCHOO.COM'     => 'JC_rma_request',
);
lock_hash(%DOCNAME_RMA_REQUEST);

my %FORMAT_REGEXP = (
    id                  => qr{\A\d+\z}xms,
    sku                 => qr{\A(\d+)-(\d{3,})\z}xms,
    location            => qr{\A(\d{2})(\d)([a-zA-Z])-?(\d{3,4})([a-zA-Z])\z}xmsi,
    email_address       => qr{\A([a-zA-Z0-9_''+*$%\^&!\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9:]{2,4})+\z}xmsi,
    empty_or_whitespace => qr{\A\s*\z}xms,
    auth_section        => qr{\A\w[\w\s]*\w\z}xms,
    int_positive        => qr{\A[1-9]\d*\z}xms,
    int_nonzero         => qr{\A-?[1-9]\d*\z}xms,
    uri_path            => qr{\A\/\w[\w\/]+\w\z}xms,
);
lock_hash(%FORMAT_REGEXP);

#-------------------------------------------------------------------------------
# Utilities (candidates to move elsewhere!)
#-------------------------------------------------------------------------------

sub get_operator_details :Export() {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $operator_id = $arg_ref->{operator_id};

    my $qry = q{SELECT id, name, username, email_address, phone_ddi, department_id FROM operator WHERE id = ?};

    my $sth = $dbh->prepare($qry);
    $sth->execute($operator_id);

    my $operator_details_ref = results_list($sth);
    return $operator_details_ref->[0];
}

sub list_countries :Export() {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};

    my $qry = q{SELECT country AS id, country FROM country ORDER BY country};

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $countries_ref = results_list($sth);
    return $countries_ref;
}

sub update_fields :Export() {
    my ($arg_ref)               = @_;
    my $dbh_trans               = $arg_ref->{dbh};
    my $update_fields_ref       = $arg_ref->{update_fields};

    TABLE:
    foreach my $table_name ( keys %{$update_fields_ref} ) {
        croak "Invalid table name ($table_name)" if $table_name !~ m{\A\w+\z}xms;

        RECORD:
        foreach my $id ( keys %{ $update_fields_ref->{$table_name} } ) {
            croak "Invalid id ($table_name, $id)" if $id !~ $FORMAT_REGEXP{id};

            ## build update query
            my @update_field_names  = keys %{ $update_fields_ref->{$table_name}{$id} };
            my $str_set_list = join(' = ?, ', @update_field_names);
            $str_set_list .= ' = ?';
            my $sql_update = qq{UPDATE $table_name SET $str_set_list WHERE id = ?};

            my @update_field_values = ();
            FIELD:
            foreach my $field_name ( @update_field_names ) {
                push @update_field_values, encode_db($update_fields_ref->{$table_name}{$id}{$field_name});
            }

            my $sth_update = $dbh_trans->prepare($sql_update);
            $sth_update->execute(@update_field_values, $id);
        }
    }
    return;
}

sub is_valid_format :Export(:validate) {
    my ($arg_ref)       = @_;
    my $value           = defined $arg_ref->{value} ? $arg_ref->{value} : '';
    my $format          = defined $arg_ref->{'format'} ? $arg_ref->{'format'} : '';
    my $formats_ref     = defined $arg_ref->{formats_ref} ? $arg_ref->{formats_ref} : \%FORMAT_REGEXP;

    $format = lc($format);
    croak "No pattern defined for format '$format'" unless grep { m/\A$format\z/xms } keys %{$formats_ref};

    my %validation_dispatch = (
        id                  => sub { my ($value, $formats_ref) = @_; return $value =~ $formats_ref->{id} },
        sku                 => sub { my ($value, $formats_ref) = @_; return $value =~ $formats_ref->{sku} },
        location            => sub { my ($value, $formats_ref) = @_; return $value =~ $formats_ref->{location} },
        email_address       => sub { my ($value, $formats_ref) = @_; return $value =~ $formats_ref->{email_address} },
        empty_or_whitespace => sub { my ($value, $formats_ref) = @_; return $value =~ $formats_ref->{empty_or_whitespace} },
        auth_section        => sub { my ($value, $formats_ref) = @_; return $value =~ $formats_ref->{auth_section} },
        int_positive        => sub { my ($value, $formats_ref) = @_; return $value =~ $formats_ref->{int_positive} },
        int_nonzero         => sub { my ($value, $formats_ref) = @_; return $value =~ $formats_ref->{int_nonzero} },
        uri_path            => sub { my ($value, $formats_ref) = @_; return $value =~ $formats_ref->{uri_path} },
    );
    croak "No validation routine defined for format '$format'" unless grep { m/\A$format\z/xms } keys %validation_dispatch;

    my $is_valid_format = $validation_dispatch{$format}->($value, $formats_ref);
    return $is_valid_format;
}

sub create_html_document :Export(:rtv_document) {
    my ($arg_ref)       = @_;
    my $basename        = $arg_ref->{basename};
    my $path            = $arg_ref->{path};
    my $doc_template    = $arg_ref->{doc_template};
    my $doc_data_ref    = $arg_ref->{doc_data_ref};

    $basename =~ s/\.html$//;
    my $out_file    = File::Spec->catfile($path, $basename . '.html');
    my $html        = '';

    my $template    = XTracker::XTemplate->template();
    $template->process( $doc_template, { template_type => 'none', %$doc_data_ref }, \$html);

    open my $fh_out, '>:encoding(UTF-8)', $out_file or croak "Couldn't open '$out_file': $!";
    print {$fh_out} $html           or croak "Couldn't write '$out_file': $!";
    close $fh_out                   or croak "Couldn't close '$out_file': $!";
    return $html;
}

sub convert_html_document :Export(:rtv_document) {
    my ($arg_ref)           = @_;

    my $use_webkit = config_var('Printing', 'use_webkit');

    my $default_header = my $default_footer =
        $use_webkit ? '' : '.';

    my $basename            = $arg_ref->{basename};
    my $path                = $arg_ref->{path};
    my $doc_header          = defined $arg_ref->{doc_header}    ? $arg_ref->{doc_header}    : $default_header;
    my $doc_footer          = defined $arg_ref->{doc_footer}    ? $arg_ref->{doc_footer}    : $default_footer;
    my $out_orientation     = defined $arg_ref->{orientation}   ? $arg_ref->{orientation}   : 'portrait';
    my $out_format          = defined $arg_ref->{output_format} ? $arg_ref->{output_format} : 'pdf';
    my $default_font_size   = 10;
    my $font_size           = defined $arg_ref->{font_size}     ? $arg_ref->{font_size}     : $default_font_size;

    $out_format         = lc($out_format);
    croak "Invalid output_format $out_format" if $out_format !~ m{\A(pdf|ps[123]?)\z}xms;

    ## set default font size if that specified is unsuitable
    $font_size = $default_font_size if $font_size !~ m{\A([1-9]|1\d)\z}xms;

    my $file_extension  = $out_format eq 'pdf'              ?   'pdf'
                        : $out_format =~ m{\Aps[123]?\z}xms ?   'ps'
                        :                                       undef
                        ;

    $basename =~ s/\.html$//;
    my $in_file         = File::Spec->catfile($path, $basename . '.html');
    my $out_file        = File::Spec->catfile($path, $basename . ".$file_extension");

    if ($use_webkit) {
        my %print_options = (
            encoding => 'UTF-8',
            header_center => $doc_header,
            footer_left => '[date]',
            footer_center => $doc_footer,
            footer_right => '[page]/[topage]',
            margin_left => '1.5cm',
            margin_right => '1.5cm',
            margin_top => '1.5cm',
            margin_bottom => '1.5cm',
        );
        if (lc $out_orientation eq 'landscape') {
            $print_options{orientation} = 'Landscape';
        }
        else {
            $print_options{orientation} = 'Portrait';
        }

        my $webkit = PDF::WebKit->new($in_file, %print_options);
        $webkit->to_file($out_file) or croak "Couldn't write '$out_file': $!";
    }
    else {
        my $obj_doc = HTML::HTMLDoc->new( mode => 'file', tmpdir => '/tmp' );

        $obj_doc->set_page_size('a4');
        $obj_doc->set_output_format($out_format);
        $obj_doc->set_charset('iso-8859-15');
        $obj_doc->set_bodyfont('Arial');
        $obj_doc->set_fontsize($font_size);
        $obj_doc->embed_fonts();
        $obj_doc->links();
        $obj_doc->set_input_file($in_file);

        $obj_doc->set_header('.', $doc_header, '.');
        $obj_doc->set_footer('D', $doc_footer, '/');  ## D: current date & time, /: page number & total pages (n/N)
        $obj_doc->set_left_margin('1.5', 'cm');
        $obj_doc->set_right_margin('1.5', 'cm');
        $obj_doc->set_top_margin('1.5', 'cm');
        $obj_doc->set_bottom_margin('1.5', 'cm');

        if ( $out_orientation =~ m{\A(landscape)\z}xmsi ) {
            $obj_doc->landscape();
        }
        else {
            $obj_doc->portrait();
        }

        ## write the doc
        my $pdf = $obj_doc->generate_pdf();
        $pdf->to_file($out_file) or croak "Couldn't write '$out_file': $!";
    }

    return $basename;
}

sub get_rtv_print_location :Export() {
    my ($schema, $channel_id) = @_;

    my $config_section = $schema->resultset("Public::Channel")->find({
        id  => $channel_id,
    })->config_name;

    my $rtv_printer_name = lc(config_var(
        'RTVChannelPrinterName',
        $config_section
    ));

    my $print_location = $schema->resultset("Printer::Printer")->find({
        lp_name => $rtv_printer_name,
    })->location;

    die sprintf("No print location for %s", $config_section)
        unless ($print_location);

    return $print_location->name;
}

#-------------------------------------------------------------------------------
# RTV Utilities
#-------------------------------------------------------------------------------

sub create_rtv_stock_process :Export() {
    my ($arg_ref)               = @_;
    my $dbh                     = $arg_ref->{dbh};
    my $stock_process_type_id   = $arg_ref->{stock_process_type_id};
    my $delivery_item_id        = $arg_ref->{delivery_item_id};
    my $quantity                = $arg_ref->{quantity};
    my $process_group_ref       = $arg_ref->{process_group_ref};
    my $stock_process_status_id = $arg_ref->{stock_process_status_id};
    my $originating_path        = $arg_ref->{originating_path};
    my $notes                   = $arg_ref->{notes};

    my $msg_croak   = '';
    $msg_croak .= "Invalid stock_process_type_id ($stock_process_type_id)\n" if $stock_process_type_id !~ $FORMAT_REGEXP{id};
    $msg_croak .= "Invalid delivery_item_id ($delivery_item_id)\n" if $delivery_item_id !~ $FORMAT_REGEXP{id};
    $msg_croak .= "Invalid quantity ($quantity)\n" if $quantity !~ $FORMAT_REGEXP{int_positive};
    $msg_croak .= "Invalid process_group_ref! Must be a scalar reference" if ref($process_group_ref) ne 'SCALAR';
    $msg_croak .= "Invalid originating_path ($originating_path)\n" if $originating_path !~ m{\A\/\w[\w\/]+\w\z}xms;
    croak $msg_croak if $msg_croak;

    my $stock_process_id
        = create_stock_process(
            $dbh,
            $stock_process_type_id,
            $delivery_item_id,
            $quantity,
            $process_group_ref
        );

    ## set stock process status, if defined and valid
    if ( defined $stock_process_status_id ) {
        croak "Invalid stock_process_status_id ($stock_process_status_id)\n" if $stock_process_status_id !~ $FORMAT_REGEXP{id};
        set_stock_process_status($dbh, $stock_process_id, $stock_process_status_id);
    }

    ## insert rtv_stock_process record
    insert_rtv_stock_process({
            dbh                 => $dbh,
            stock_process_id    => $stock_process_id,
            originating_path    => $originating_path,
            notes               => $notes,
    });
    return $stock_process_id;
}

sub insert_rtv_stock_process :Export() {
    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $stock_process_id    = defined $arg_ref->{stock_process_id} ? $arg_ref->{stock_process_id} : '';
    my $originating_path    = defined $arg_ref->{originating_path} ? $arg_ref->{originating_path} : '';
    my $notes               = $arg_ref->{notes};

    my $msg_croak   = '';
    $msg_croak .= "Invalid stock_process_id ($stock_process_id)\n" if $stock_process_id !~ $FORMAT_REGEXP{id};
    $msg_croak .= "Invalid originating_path ($originating_path)\n" if $originating_path !~ m{\A\/\w[\w\/]+\w\z}xms;
    croak $msg_croak if $msg_croak;

    my $section_info_ref = get_auth_sub_section_data({
            dbh         => $dbh,
            uri_path    => $originating_path,
    });

    my $sql
        = q{INSERT INTO rtv_stock_process (stock_process_id, originating_uri_path, originating_sub_section_id, notes)
            VALUES (?, ?, ?, ?)
        };

    my $sth = $dbh->prepare($sql);
    $sth->execute($stock_process_id, $originating_path, $section_info_ref->{sub_section_id}, $notes);
    return;
}

sub get_rtv_stock_process_row :Export() {
    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $stock_process_id    = $arg_ref->{stock_process_id};

    my $msg_croak   = '';
    $msg_croak .= "Invalid stock_process_id ($stock_process_id)\n" if $stock_process_id !~ $FORMAT_REGEXP{id};
    croak $msg_croak if $msg_croak;

    my $qry = q{SELECT * FROM vw_stock_process WHERE stock_process_id = ?};

    my $sth = $dbh->prepare($qry);
    $sth->execute($stock_process_id);

    my $rtv_stock_process_row_ref = results_list($sth)->[0];
}

sub get_auth_sub_section_data :Export() {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $uri_path    = defined $arg_ref->{uri_path} ? $arg_ref->{uri_path} : '';

    my $msg_croak   = '';
    my @levels      = split /\//, $uri_path;
    my $section     = defined $levels[1] ? $levels[1] : '';
    my $sub_section = defined $levels[2] ? $levels[2] : '';

    # camel-case split
    $section        =~ s{([a-z])([A-Z])}{$1 $2}g;
    $sub_section    =~ s{([a-z])([A-Z])}{$1 $2}g;

    $msg_croak .= "Invalid section ($section)\n" if $section !~ $FORMAT_REGEXP{auth_section};
    $msg_croak .= "Invalid sub_section ($sub_section)\n" if $sub_section !~ $FORMAT_REGEXP{auth_section};
    croak $msg_croak if $msg_croak;

    my $qry
        = q{SELECT
                auths.id AS section_id
            ,   auths.section AS section
            ,   authss.id AS sub_section_id
            ,   authss.sub_section
            ,   authss.ord
            FROM authorisation_section auths
            INNER JOIN authorisation_sub_section authss
                ON (auths.id = authss.authorisation_section_id)
            WHERE auths.section = ?
            AND authss.sub_section = ?
            ORDER BY auths.section, authss.ord
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($section, $sub_section);

    my $auth_sub_section_data_ref = results_list($sth)->[0];
    return $auth_sub_section_data_ref;
}

sub print_rtv_document :Export(:rtv_document) {
    my ($arg_ref)           = @_;
    my $document            = $arg_ref->{document};
    my $printer_name        = $arg_ref->{printer_name};
    my $copies              = defined $arg_ref->{copies} ? $arg_ref->{copies} : 1;

    my $print_file = config_var('Printing', 'print_file') // 1;

    my $keep_document_file  = defined $arg_ref->{keep_document_file} ? $arg_ref->{keep_document_file} : 0;

    # If the global config setting Printing/delete files is present and
    # false, then override $keep_document_file to be true
    my $delete_file = config_var('Printing', 'delete_file');
    if (defined $delete_file and not $delete_file) {
        $keep_document_file = 1;
    }

    my $doc_path = XTracker::PrintFunctions::path_for_print_document({
        %{ XTracker::PrintFunctions::document_details_from_name( $arg_ref->{document} ) },
    });
    my $cmd_output = '';
    if ($print_file) {
        my $lp_name = get_printer_by_name($printer_name)->{lp_name};
        croak "Invalid printer $printer_name"
            if $lp_name =~ $FORMAT_REGEXP{empty_or_whitespace};

        ## limit copies
        $copies         = 1 if $copies !~ m{\A[1-9]\z}xms;

        if ( $lp_name ) {
            my $cmd_output = XT::LP->print(
                {
                    printer     => $lp_name,
                    filename    => $doc_path,
                    copies      => $copies,
                }
            );
        }
    }

    if ( not $keep_document_file ) {
        if (-e $doc_path) {
            unlink $doc_path or xt_logger->error($!);
        }
        else {
            xt_logger->debug( 'trying to remove non-existant file: ' . $doc_path );
        }
    }
    return $cmd_output;
}

sub get_rtv_status :Export() {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $entity      = $arg_ref->{entity};
    my $id          = $arg_ref->{id};

    $entity   = lc(trim($entity));
    croak "Invalid entity '$entity'" unless $entity =~ m{\A(rma_request|rma_request_detail|rtv_shipment|rtv_shipment_detail|rtv_inspection_pick_request)\z}xms;

    my $status_table    = $entity . '_status';

    my $qry
        = qq{SELECT e.status_id, s.status
            FROM $entity e
            INNER JOIN $status_table s
            ON e.status_id = s.id
            WHERE e.id = ?
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    my ($status_id, $status);
    $sth->bind_columns(\($status_id, $status));

    $sth->fetch();
    $sth->finish();

    my $results_ref = { status_id => $status_id, status => $status };
    return $results_ref;
}

sub is_nonfaulty :Export() {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $type        = $arg_ref->{type};
    my $id          = $arg_ref->{id};

    $type   = lc(trim($type));
    croak "Invalid type ($type)" if $type !~ m{\A(?:rma_request_id|rtv_shipment_id)\z}xms;
    croak "Invalid $type ($id)" if $id !~ $FORMAT_REGEXP{id};

    ## build 'where' clause
    my $where_clause    = undef;
    my @exec_args       = ();
    for ($type) {
        m{\Arma_request_id\z}xmsi   && do { $where_clause = 'rrd.rma_request_id = ?'; push @exec_args, $id; last; };
        m{\Artv_shipment_id\z}xmsi  && do { $where_clause = 'rsd.rtv_shipment_id = ?'; push @exec_args, $id; last; };
        croak "Unknown type ($_)";
    }

    my $qry
        = q{SELECT rrd.type_id
            FROM rma_request_detail rrd
            LEFT JOIN rtv_shipment_detail rsd
                ON (rsd.rma_request_detail_id = rrd.id)
        };
    $qry .= qq{ WHERE $where_clause} if defined $where_clause;

    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);

    my $results_ref = results_list($sth);

    my @nonfaulty_request_detail_types = ($RMA_REQUEST_DETAIL_TYPE__SALE_OR_RETURN, $RMA_REQUEST_DETAIL_TYPE__STOCK_SWAP);

    my $is_nonfaulty;

    foreach my $row_ref ( @{$results_ref} ) {
        if ( not grep { $row_ref->{type_id} == $_ } @nonfaulty_request_detail_types ) {
            return 0;
        }
        else {
            $is_nonfaulty = 1;
        }
    }
    return $is_nonfaulty;
}

sub update_rtv_status :Export() {
    my ($arg_ref)   = @_;
    my $dbh_trans   = $arg_ref->{dbh};
    my $entity      = $arg_ref->{entity};
    my $type        = $arg_ref->{type};
    my $id          = $arg_ref->{id};
    my $status_id   = $arg_ref->{status_id};
    my $operator_id = $arg_ref->{operator_id};

    $entity = lc(trim($entity));
    $type   = lc(trim($type));

    ## validate i/p args
    croak "Invalid operator_id '$operator_id'" unless is_valid_format( { value => $operator_id, format => 'id' } );
    croak "Invalid status_id '$status_id'" unless is_valid_format( { value => $status_id, format => 'id' } );

    if ( $entity eq 'rma_request' ) {
        croak "Invalid type '$type'" unless $type eq 'rma_request_id';
    }
    elsif ( $entity eq 'rma_request_detail' ) {
        croak "Invalid type '$type'" unless $type =~ m{\A(rma_request_id|rma_request_detail_id)\z}xms;

        if ( $type eq 'rma_request_id' ) {
            $id = get_detail_ids( { dbh => $dbh_trans, type => 'rma_request', id => $id } );
        }
    }
    elsif ( $entity eq 'rtv_shipment' ) {
        croak "Invalid type '$type'" unless $type eq 'rtv_shipment_id';
    }
    elsif ( $entity eq 'rtv_shipment_detail' ) {
        croak "Invalid type '$type'" unless $type =~ m{\A(rtv_shipment_id|rtv_shipment_detail_id)\z}xms;

        if ( $type eq 'rtv_shipment_id' ) {
            $id = get_detail_ids( { dbh => $dbh_trans, type => 'rtv_shipment', id => $id } );
        }
    }
    elsif ( $entity eq 'rtv_inspection_pick_request' ) {
        croak "Invalid type '$type'" unless $type eq 'rtv_inspection_pick_request_id';
    }

    my @ids = ref($id) eq 'ARRAY'   ? @{$id}
            : ref($id) eq 'HASH'    ? keys %{$id}
            : ref($id) eq ''        ? ($id)
            :                         ()
            ;

    my %update_fields   = ();

    foreach my $id (@ids) {
        croak "Invalid id '$id'" unless is_valid_format( { value => $id, format => 'id' } );
        $update_fields{$entity}{$id}{'status_id'} = $status_id;
    }

    ## perform the status update
    update_fields({
        dbh             => $dbh_trans,
        update_fields   => \%update_fields,
    });

    if ( $entity ne 'rtv_inspection_pick_request' ) {
        foreach my $id (@ids) {
            _log_status_update ({
                dbh         => $dbh_trans,
                type        => $entity,
                id          => $id,
                status_id   => $status_id,
                operator_id => $operator_id,
            });
        }
    }
    return;
}

sub get_detail_ids :Export(:rtv_shipment) {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $type        = $arg_ref->{type};
    my $id          = $arg_ref->{id};

    $type   = lc(trim($type));
    croak "Invalid type '$type'" if $type !~ m{\A(rma_request|rtv_shipment|rtv_inspection_pick_request)\z}xms;
    croak "Invalid id ($id)" if $id !~ $FORMAT_REGEXP{id};

    my %field_map = (
        rma_request                 => { detail_id_field => 'id', detail_table => 'rma_request_detail', fk_field => 'rma_request_id' },
        rtv_shipment                => { detail_id_field => 'id', detail_table => 'rtv_shipment_detail', fk_field => 'rtv_shipment_id' },
        rtv_inspection_pick_request => { detail_id_field => 'rtv_quantity_id', detail_table => 'rtv_inspection_pick_request_detail', fk_field => 'rtv_inspection_pick_request_id' },
    );

    my $qry
        = qq{SELECT $field_map{$type}{detail_id_field}
            FROM $field_map{$type}{detail_table}
            WHERE $field_map{$type}{fk_field} = ?
            ORDER BY $field_map{$type}{detail_id_field}
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    my @detail_ids  = ();
    my $detail_id;

    $sth->bind_columns(\$detail_id);

    while ( $sth->fetch() ) {
        push @detail_ids, $detail_id;
    }
    return \@detail_ids;
}

sub get_parent_id :Export() {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $type        = $arg_ref->{type};
    my $id          = $arg_ref->{id};

    $type   = lc(trim($type));
    croak "Invalid type '$type'" if $type !~ m{\A(delivery_item)\z}xms;
    croak "Invalid id ($id)" if $id !~ $FORMAT_REGEXP{id};

    my %qry_map = (
        delivery_item   => q{SELECT delivery_id FROM delivery_item WHERE id = ?},
    );

    my $qry = $qry_map{$type};
    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    my $parent_id;
    $sth->bind_columns(\$parent_id);

    $sth->fetch();
    $sth->finish();
    return $parent_id;
}

sub _log_status_update {
    my ($arg_ref)   = @_;
    my $dbh_trans   = $arg_ref->{dbh};
    my $type        = $arg_ref->{type};
    my $id          = $arg_ref->{id};
    my $status_id   = $arg_ref->{status_id};
    my $operator_id = $arg_ref->{operator_id};

    my $sql_log_status = {
        rma_request => q{INSERT INTO rma_request_status_log (rma_request_id, rma_request_status_id, operator_id, date_time) VALUES (?, ?, ?, default)},
        rma_request_detail => q{INSERT INTO rma_request_detail_status_log (rma_request_detail_id, rma_request_detail_status_id, operator_id, date_time) VALUES (?, ?, ?, default)},
        rtv_shipment => q{INSERT INTO rtv_shipment_status_log (rtv_shipment_id, rtv_shipment_status_id, operator_id, date_time) VALUES (?, ?, ?, default)},
        rtv_shipment_detail => q{INSERT INTO rtv_shipment_detail_status_log (rtv_shipment_detail_id, rtv_shipment_detail_status_id, operator_id, date_time) VALUES (?, ?, ?, default)},
    };

    my $sth_log_status = $dbh_trans->prepare($sql_log_status->{ $type });
    $sth_log_status->execute($id, $status_id, $operator_id);
    return;
}

#-------------------------------------------------------------------------------
# RTV Stock
#-------------------------------------------------------------------------------

sub log_rtv_shipment_pick :Export(:logging) {
    my ($arg_ref)       = @_;
    my $dbh_trans       = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};
    my $operator_id     = $arg_ref->{operator_id};

    croak "Invalid rtv_shipment_id ($rtv_shipment_id)" if $rtv_shipment_id !~ $FORMAT_REGEXP{id};
    croak "Invalid operator_id ($operator_id)" if $operator_id !~ $FORMAT_REGEXP{id};

    my $rtv_shipment_details_ref
        = list_rtv_shipment_details( { dbh => $dbh_trans, type => 'rtv_shipment_id', id => $rtv_shipment_id } );

    foreach my $row_ref ( @{$rtv_shipment_details_ref} ) {
        log_rtv_stock({
            dbh             => $dbh_trans,
            variant_id      => $row_ref->{variant_id},
            rtv_action_id   => $RTV_ACTION__RTV_SHIPMENT_PICK,
            quantity        => -$row_ref->{rtv_shipment_detail_quantity},
            operator_id     => $operator_id,
            notes           => "$rtv_shipment_id",
            channel_id      => $row_ref->{channel_id},
        });
    }
    return;
}

sub log_rtv_putaway :Export(:logging) {
    my ($arg_ref)           = @_;
    my $dbh_trans           = $arg_ref->{dbh};
    my $stock_process_id    = defined $arg_ref->{stock_process_id} ? $arg_ref->{stock_process_id} : '';
    my $variant_id          = defined $arg_ref->{variant_id} ? $arg_ref->{variant_id} : '';
    my $quantity            = defined $arg_ref->{quantity} ? $arg_ref->{quantity} : 0;
    my $operator_id         = defined $arg_ref->{operator_id} ? $arg_ref->{operator_id} : '';
    my $notes               = defined $arg_ref->{notes} ? $arg_ref->{notes} : '';
    my $channel_id          = defined $arg_ref->{channel_id} ? $arg_ref->{channel_id} : '';

    my $msg_croak   = '';
    $msg_croak .= "Invalid stock_process_id ($stock_process_id)\n" if $stock_process_id !~ $FORMAT_REGEXP{id};
    $msg_croak .= "Invalid variant_id ($variant_id)\n" if $variant_id !~ $FORMAT_REGEXP{id};
    $msg_croak .= "Invalid operator_id ($operator_id)\n" if $operator_id !~ $FORMAT_REGEXP{id};
    $msg_croak .= "Quantity must be positive\n" if $quantity !~ $FORMAT_REGEXP{int_positive};
    $msg_croak .= "Quantity must be positive\n" if $channel_id !~ $FORMAT_REGEXP{id};
    croak $msg_croak if $msg_croak;

    my $sp_row_ref
        = get_rtv_stock_process_row({
                dbh                 => $dbh_trans,
                stock_process_id    => $stock_process_id,
        });
    my $sp_type_id = $sp_row_ref->{stock_process_type_id};

    my %sp_type_action_map = (
        $STOCK_PROCESS_TYPE__FAULTY => {
            rtv_action_id   => $RTV_ACTION__PUTAWAY__DASH__RTV_GOODS_IN,
        },
        $STOCK_PROCESS_TYPE__RTV => {
            rtv_action_id   => $RTV_ACTION__PUTAWAY__DASH__RTV_PROCESS,
        },
        $STOCK_PROCESS_TYPE__DEAD => {
            rtv_action_id   => $RTV_ACTION__PUTAWAY__DASH__DEAD,
        },
        $STOCK_PROCESS_TYPE__RTV_NON_DASH_FAULTY => {
            rtv_action_id   => $RTV_ACTION__PUTAWAY__DASH__RTV_PROCESS,
        },
        $STOCK_PROCESS_TYPE__RTV_CUSTOMER_REPAIR => {
            rtv_action_id   => $RTV_ACTION__PUTAWAY__DASH__RTV_PROCESS,
        },
    );

    ## get rtv log notes, based on origin...
    my $log_rtv_notes   = generate_log_rtv_notes( { dbh => $dbh_trans, sp_row_ref => $sp_row_ref, notes => $notes } );

    ## write the log record
    log_rtv_stock({
        dbh             => $dbh_trans,
        variant_id      => $variant_id,
        rtv_action_id   => $sp_type_action_map{$sp_type_id}{rtv_action_id},
        quantity        => $quantity,
        operator_id     => $operator_id,
        notes           => $log_rtv_notes,
        channel_id      => $channel_id,
    });
}

sub generate_log_rtv_notes :Export() {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $sp_row_ref  = $arg_ref->{sp_row_ref};
    my $notes       = $arg_ref->{notes};

    my $msg_croak   = '';
    $msg_croak .= "Invalid sp_row_ref - must be a hash ref\n" if ref($sp_row_ref) ne 'HASH';
    $msg_croak .= "Invalid stock_process_id ($sp_row_ref->{stock_process_id})\n" if $sp_row_ref->{stock_process_id} !~ $FORMAT_REGEXP{id};
    if ( $sp_row_ref->{originating_uri_path} && ( $sp_row_ref->{originating_uri_path} !~ $FORMAT_REGEXP{uri_path} ) ) {
        $msg_croak .= "Invalid originating_uri_path ($sp_row_ref->{originating_uri_path})\n";
    }
    croak $msg_croak if $msg_croak;

    my $stock_process_type_id   = $sp_row_ref->{stock_process_type_id};
    my $originating_uri_path    = $sp_row_ref->{originating_uri_path} // '';
    #my @origin_levels           = split(/\//, $originating_uri_path);

    my $log_rtv_notes = '';

    if ( $stock_process_type_id == $STOCK_PROCESS_TYPE__FAULTY ) {
        my $delivery_id = get_parent_id({
                dbh     => $dbh,
                type    => 'delivery_item',
                id      => $sp_row_ref->{delivery_item_id},
        });
        $log_rtv_notes = "Delivery: $delivery_id";
    }
    elsif ( $stock_process_type_id == $STOCK_PROCESS_TYPE__RTV ) {
        if ( $originating_uri_path eq '/RTV/FaultyGI') {
            $log_rtv_notes = '' . $notes;
        }
        elsif ( $originating_uri_path eq '/StockControl/Quarantine/SetQuarantine') {
            $log_rtv_notes = 'Quarantine to ' . $notes;
        }
        elsif ( $originating_uri_path eq '/StockControl/Inventory/SetStockQuarantine') {
            $log_rtv_notes = 'Quarantine to ' . $notes;
        }
    }
    elsif ( $stock_process_type_id == $STOCK_PROCESS_TYPE__RTV_CUSTOMER_REPAIR ) {
        if ( $originating_uri_path eq '/GoodsIn/ReturnsFaulty' ) {
            my $delivery_id = get_parent_id({
                    dbh     => $dbh,
                    type    => 'delivery_item',
                    id      => $sp_row_ref->{delivery_item_id}
            });
            $log_rtv_notes = "Delivery: $delivery_id";
        }
    }
    elsif ( $stock_process_type_id == $STOCK_PROCESS_TYPE__DEAD ) {
        if ( $originating_uri_path eq '/RTV/FaultyGI') {
            $log_rtv_notes  = 'RTV Workstation to Dead';
        }
        elsif ( $originating_uri_path eq '/RTV/DispatchedRTV') {
            $log_rtv_notes  = 'Refused by Vendor';
        }
    }
    elsif ( $stock_process_type_id == $STOCK_PROCESS_TYPE__RTV_NON_DASH_FAULTY ) {
        if ( $originating_uri_path eq '/StockControl/Inventory/SetStockQuarantine') {
            $log_rtv_notes = 'RTV Transfer Pending to ' . $notes;
        }
    }
    return $log_rtv_notes;
}

sub move_rtv_stock_in :Export(:rtv_stock) {
    my ($arg_ref)           = @_;
    my $dbh_trans           = $arg_ref->{dbh};
    my $rtv_stock_type      = $arg_ref->{rtv_stock_type};
    my $location_id         = $arg_ref->{location_id};
    my $variant_id          = $arg_ref->{variant_id};
    my $quantity            = $arg_ref->{quantity};
    my $delivery_item_id    = $arg_ref->{delivery_item_id};
    my $origin              = $arg_ref->{origin};
    my $channel_id          = $arg_ref->{channel_id};
    my $schema              = get_schema_using_dbh( $dbh_trans, 'xtracker_schema' );

    croak "Invalid rtv_stock_type ($rtv_stock_type)" if $rtv_stock_type !~ m{\A(RTV\sGoods\sIn|RTV\sWorkstation|RTV\sProcess)\z}xms;
    my $rtv_stock_type_obj = $schema->resultset('Flow::Status')->find({name=>$rtv_stock_type});
    croak "Didn't find a flow status with name '$rtv_stock_type'" unless $rtv_stock_type_obj;
    croak "Invalid variant_id ($variant_id)" if $variant_id !~ $FORMAT_REGEXP{id};
    croak "Invalid quantity ($quantity)" if $quantity !~ m{\A[1-9]\d{0,2}\z}xms;    ## allow positive integers 1 - 999

    unless ( uc($origin) eq 'NF' ) {
        croak "Invalid delivery_item_id ($delivery_item_id)" if $delivery_item_id !~ $FORMAT_REGEXP{id};
    }

    my $location = $schema->resultset('Public::Location')->find({id=>$location_id});
    croak "Didn't find location for id ($location_id)" unless $location;

    unless ( $location->allows_status( $rtv_stock_type_obj )) {
        croak "(2) location (".$location->id.") does not hold quantity of stock_status " . $rtv_stock_type_obj->name;
    }

    ## add or increment quantity record for location
    # need to pass in 'channel_id' to check_stock_location
    if ( check_stock_location( $dbh_trans, {
        variant_id => $variant_id,
        location => $location,
        channel_id => $channel_id,
        status_id => $rtv_stock_type_obj->id,
    } ) > 0 ) {
        update_quantity(
            $schema,
            {
                variant_id => $variant_id,
                location => $location,
                quantity => $quantity,
                channel_id => $channel_id,
                type => 'inc',
                current_status => $rtv_stock_type_obj,
            }
        );
    }
    else {
        insert_quantity(
            $schema,
            {
                    variant_id => $variant_id,
                      location => $location,
                      quantity => $quantity,
                    channel_id => $channel_id,
                initial_status => $rtv_stock_type_obj,
            }
        );
    }

    ### insert rtv_quantity record
    my $rtv_quantity_id
        = insert_rtv_quantity({
                dbh                 => $dbh_trans,
                location_id         => $location_id,
                variant_id          => $variant_id,
                quantity            => $quantity,
                delivery_item_id    => $delivery_item_id,
                origin              => $origin,
                channel_id          => $channel_id,
                initial_status      => $rtv_stock_type_obj,
    });
    return $rtv_quantity_id;
}

sub insert_rtv_quantity :Export(:rtv_stock) {
    my ($arg_ref)               = @_;
    my $dbh_trans               = $arg_ref->{dbh};
    my $location_id             = $arg_ref->{location_id};
    my $variant_id              = $arg_ref->{variant_id};
    my $quantity                = $arg_ref->{quantity};
    my $delivery_item_id        = $arg_ref->{delivery_item_id};
    my $transfer_di_fault_data  = defined $arg_ref->{transfer_di_fault_data} ? $arg_ref->{transfer_di_fault_data} : 0;
    my $origin                  = $arg_ref->{origin};
    my $channel_id              = $arg_ref->{channel_id};
    my $initial_status          = $arg_ref->{initial_status};
    my $initial_status_id       = $arg_ref->{initial_status_id};

    if ($initial_status && blessed($initial_status) && $initial_status->can('id')) {
        $initial_status_id = $initial_status->id;
    }

    croak "Invalid variant_id ($variant_id)" if $variant_id !~ $FORMAT_REGEXP{id};
    croak "Invalid channel_id ($channel_id)" if $channel_id !~ $FORMAT_REGEXP{id};
    croak "Invalid quantity ($quantity)" if $quantity !~ m{\A[1-9]\d{0,2}\z}xms;    ## allow positive integers 1 - 999
    croak "initial_status or initial_status_id is required" unless $initial_status_id;

    unless ( uc($origin) eq 'NF' ) {
        croak "Invalid delivery_item_id ($delivery_item_id)" if $delivery_item_id !~ $FORMAT_REGEXP{id};
    }

    my $sql
        = q{INSERT INTO rtv_quantity (variant_id, location_id, quantity, delivery_item_id, origin, channel_id, status_id)
                VALUES (?, ?, ?, ?, ?, ?, ?)
        };
    my $sth = $dbh_trans->prepare($sql);
    $sth->execute($variant_id, $location_id, $quantity, $delivery_item_id, $origin, $channel_id, $initial_status_id);

    my $rtv_quantity_id = last_insert_id($dbh_trans, 'rtv_quantity_id_seq');

    ## transfer fault data from delivery_item_fault record if requested (and available)
    if ($transfer_di_fault_data) {
        my $di_fault_ref    = get_delivery_item_fault( { dbh => $dbh_trans, delivery_item_id => $delivery_item_id } );

        if ( defined $di_fault_ref->{delivery_item_id} ) {
            my %update_fields   = ();
            $update_fields{rtv_quantity}{$rtv_quantity_id}{fault_type_id}       = $di_fault_ref->{fault_type_id};;
            $update_fields{rtv_quantity}{$rtv_quantity_id}{fault_description}   = $di_fault_ref->{fault_description};

            update_fields({
                dbh             => $dbh_trans,
                update_fields   => \%update_fields,
            });
        }
    }
    return $rtv_quantity_id;
}

sub insert_update_delivery_item_fault :Export(:rtv_stock) {
    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $type                = defined $arg_ref->{type} ? $arg_ref->{type} : 'rtv_quantity_id';
    my $id                  = $arg_ref->{id};
    my $fault_type_id       = $arg_ref->{fault_type_id};
    my $fault_description   = $arg_ref->{fault_description};

    $type   = lc(trim($type));
    croak "Invalid type ($type)" if $type !~ m{\A(delivery_item_id|rtv_quantity_id)\z}xms;
    croak "Invalid $type ($id)" if $id !~ $FORMAT_REGEXP{id};
    croak "Invalid fault_type_id ($fault_type_id)" if $fault_type_id !~ $FORMAT_REGEXP{id};

    my $delivery_item_id;

    if ( $type eq 'rtv_quantity_id' ) {
        ## get delivery_item_id
        my $rtv_quantity_ref    = get_rtv_stock( { dbh => $dbh, type => 'rtv_quantity_id', id => $id } );
        $delivery_item_id       = $rtv_quantity_ref->[0]{delivery_item_id};
    }
    elsif ( $type eq 'delivery_item_id' ) {
        $delivery_item_id = $id;
    }

    croak "Invalid delivery_item_id ($delivery_item_id)" if $delivery_item_id !~ $FORMAT_REGEXP{id};

    my $qry_existing_id = q{SELECT delivery_item_id FROM delivery_item_fault WHERE delivery_item_id = ?};
    my $sth_existing_id = $dbh->prepare($qry_existing_id);

    $sth_existing_id->execute($delivery_item_id);

    my $existing_id;
    $sth_existing_id->bind_columns(\$existing_id);

    $sth_existing_id->fetch();
    $sth_existing_id->finish();

    my $sql_action  = '';
    my @exec_args   = ();

    if (defined $existing_id) {
        $sql_action
            = q{UPDATE delivery_item_fault SET
                    fault_type_id = ?,
                    fault_description = ?,
                    date_time = LOCALTIMESTAMP
                    WHERE delivery_item_id = ?
            };
        @exec_args  = ($fault_type_id, $fault_description, $delivery_item_id);
    }
    else {
        $sql_action
            = q{INSERT INTO delivery_item_fault (delivery_item_id, fault_type_id, fault_description, date_time)
                    VALUES (?, ?, ?, default)
            };
        @exec_args  = ($delivery_item_id, $fault_type_id, $fault_description);
    }

    my $sth_action = $dbh->prepare($sql_action);
    $sth_action->execute(@exec_args);
    return;
}

sub get_delivery_item_fault :Export(:just_for_test) {
    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $delivery_item_id    = $arg_ref->{delivery_item_id};

    croak "Invalid delivery_item_id ($delivery_item_id)" if $delivery_item_id !~ $FORMAT_REGEXP{id};

    my $qry
        = qq{SELECT delivery_item_id, fault_type_id, fault_description, date_time
            FROM delivery_item_fault WHERE delivery_item_id = ?
        };
    my $sth = $dbh->prepare($qry);
    $sth->execute($delivery_item_id);

    my $delivery_item_fault_ref = $sth->fetchrow_hashref();
    $sth->finish();

    my $return_ref;

    if ( defined $delivery_item_fault_ref ) {
        $return_ref = $delivery_item_fault_ref;
    }
    else {
        $return_ref = {
            delivery_item_id    => $delivery_item_id,
            fault_type_id       => 0,
            fault_description   => '',
            date_time           => '',
        };
    }
    return $return_ref;
}

sub move_rtv_stock_out :Export(:rtv_stock) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $schema          = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    my $rtv_stock_type  = $arg_ref->{rtv_stock_type};
    my $type            = defined $arg_ref->{type} ? $arg_ref->{type} : 'rma_request_detail_id';
    my $id              = $arg_ref->{id};
    my $quantity        = $arg_ref->{quantity};

    $type   = lc(trim($type));
    croak "Invalid rtv_stock_type ($rtv_stock_type)" if $rtv_stock_type !~ m{\A(RTV\sGoods\sIn|RTV\sWorkstation|RTV\sProcess)\z}xms;
    my $rtv_stock_type_obj = $schema->resultset('Flow::Status')->find({name=>$rtv_stock_type});
    croak "Didn't find a flow status with name '$rtv_stock_type'" unless $rtv_stock_type_obj;
    croak "Invalid type ($type)" if $type !~ m{\A(rma_request_detail_id|rtv_shipment_detail_id|rtv_quantity_id)\z}xms;
    croak "Invalid $type ($id)" if $id !~ $FORMAT_REGEXP{id};

    ## get variant_id, location and quantity
    my $rtv_stock_ref                   = get_rtv_stock( { dbh => $dbh, type => $type, id => $id } );
    my $rtv_quantity_id                 = $rtv_stock_ref->[0]{id};
    my $variant_id                      = $rtv_stock_ref->[0]{variant_id};
    my $location_id                     = $rtv_stock_ref->[0]{location_id};
    my $current_quantity                = $rtv_stock_ref->[0]{quantity};
    my $rtv_shipment_detail_quantity    = $rtv_stock_ref->[0]{rtv_shipment_detail_quantity};
    my $rma_request_detail_quantity     = $rtv_stock_ref->[0]{rma_request_detail_quantity};
    my $channel_id                      = $rtv_stock_ref->[0]{channel_id};

    croak "Invalid rtv_quantity_id ($rtv_quantity_id)" if $rtv_quantity_id !~ $FORMAT_REGEXP{id};

    ## assume current row quantity if quantity unspecified
    $quantity = defined $quantity ? $quantity : $current_quantity;

    ## check that request quantity is valid
    if ( $quantity > $current_quantity ) {
        croak "Move request quantity ($quantity) is greater than current record quantity ($current_quantity)";
    }

    ## check that record quantities match
    if ( $type eq 'rtv_shipment_id' and ($rtv_shipment_detail_quantity != $rma_request_detail_quantity) ) {
        croak "Quantity mismatch! rtv_shipment_detail quantity ($rtv_shipment_detail_quantity) does not match rma_request_detail quantity ($rma_request_detail_quantity)";
    }

    if ( $type eq 'rma_request_id' and ($rma_request_detail_quantity != $current_quantity) ) {
        croak "Quantity mismatch! rma_request_detail quantity ($rma_request_detail_quantity) does not match rtv_quantity quantity ($current_quantity)";
    }

    my $location = $schema->resultset('Public::Location')->find({id=>$location_id});
    croak "Didn't find location for id ($location_id)" unless $location;

    unless ( $location->allows_status( $rtv_stock_type_obj )) {
        croak "(1) location (".$location->id.") does not hold quantity of stock_status " . $rtv_stock_type_obj->name;
    }

    ## decrememt rtv_quantity record (will delete record if taken to zero)
    _decrement_rtv_quantity( { dbh => $dbh, type => 'rtv_quantity_id', id => $rtv_quantity_id, quantity => $quantity } );

    ## decrement location quantity and delete if this takes it to zero
    update_quantity(
        $schema,
        {
                variant_id => $variant_id,
                  location => $location,
                  quantity => -$quantity,
                      type => 'dec',
                channel_id => $channel_id,
            current_status => $rtv_stock_type_obj,
        }
    );
    my $location_qty = get_stock_location_quantity( $dbh, {
        variant_id => $variant_id,
        location => $location,
        channel_id => $channel_id,
        status_id => $rtv_stock_type_obj->id,
    } );
    if ($location_qty <= 0) {
        delete_quantity( $dbh, {
            variant_id => $variant_id,
              location => $location,
            channel_id => $channel_id,
                status => $rtv_stock_type_obj,
        });
    }
    return;
}

sub _decrement_rtv_quantity {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $type        = $arg_ref->{type};
    my $id          = $arg_ref->{id};
    my $quantity    = $arg_ref->{quantity};

    $type   = lc(trim($type));
    croak "Invalid type ($type)" if $type !~ m{\A(rma_request_detail_id|rtv_shipment_detail_id|rtv_quantity_id)\z}xms;
    croak "Invalid $type ($id)" if $id !~ $FORMAT_REGEXP{id};
    croak "Invalid quantity ($quantity)" if $quantity !~ $FORMAT_REGEXP{int_positive};

    ## get rtv_quantity detail
    my $rtv_stock_ref       = get_rtv_stock( { dbh => $dbh, type => $type, id => $id } );
    my $rtv_quantity_id     = $rtv_stock_ref->[0]{id};
    my $current_quantity    = $rtv_stock_ref->[0]{quantity};

    croak "Invalid rtv_quantity_id ($rtv_quantity_id)" if $rtv_quantity_id !~ $FORMAT_REGEXP{id};

    ## check that request quantity is valid
    if ( $quantity > $current_quantity ) {
        croak "Decrement request quantity ($quantity) is greater than current record quantity ($current_quantity)";
    }

    my $sql_update = q{UPDATE rtv_quantity SET quantity = (quantity - ?) WHERE id = ?};
    my $sth_update = $dbh->prepare($sql_update);
    $sth_update->execute($quantity, $rtv_quantity_id);

    if ($quantity == $current_quantity) {
    ## delete rtv_quantity record if decremented to zero
        my $sql_delete = q{DELETE FROM rtv_quantity WHERE id = ? AND quantity = 0};
        my $sth_delete = $dbh->prepare($sql_delete);
        $sth_delete->execute($rtv_quantity_id);
    }
    return;
}

sub transfer_rtv_stock :Export(:rtv_stock) {
    my ($arg_ref)           = @_;
    my $dbh_trans           = $arg_ref->{dbh};
    my $rtv_stock_type_from = $arg_ref->{rtv_stock_type_from};
    my $rtv_stock_type_to   = $arg_ref->{rtv_stock_type_to};
    my $location_id_to      = $arg_ref->{location_id_to};
    my $type                = defined $arg_ref->{type} ? $arg_ref->{type} : 'rtv_quantity_id';
    my $id                  = $arg_ref->{id};
    my $operator_id         = $arg_ref->{operator_id};

    croak "Invalid rtv_stock_type_from ($rtv_stock_type_from)" if $rtv_stock_type_from !~ m{\A(RTV\sGoods\sIn|RTV\sWorkstation)\z}xms;
    croak "Invalid rtv_stock_type_to ($rtv_stock_type_to)" if $rtv_stock_type_to !~ m{\A(RTV\sWorkstation|RTV\sProcess)\z}xms;
    croak "Invalid type ($type)" if $type ne 'rtv_quantity_id';
    croak "Invalid operator_id ($operator_id)" if $operator_id !~ $FORMAT_REGEXP{id};
    croak "Invalid $type ($id)" if $id !~ $FORMAT_REGEXP{id};

    my $rtv_stock_ref_to    = get_rtv_stock( { dbh => $dbh_trans, type => $type, id => $id } );

    ## outward movement, and rtv log record
    move_rtv_stock_out({
        dbh             => $dbh_trans,
        rtv_stock_type  => $rtv_stock_type_from,
        type            => $type,
        id              => $id,
    });

    log_rtv_stock({
        dbh             => $dbh_trans,
        variant_id      => $rtv_stock_ref_to->[0]{variant_id},
        rtv_action_id   => $RTV_ACTION__SYSTEM_TRANSFER,
        quantity        => -$rtv_stock_ref_to->[0]{quantity},
        operator_id     => $operator_id,
        notes           => "From $rtv_stock_type_from $rtv_stock_ref_to->[0]{location}",
        channel_id      => $rtv_stock_ref_to->[0]{channel_id},
    });

    ## inward movement, and rtv log record
    my $rtv_quantity_id
        = move_rtv_stock_in({
            dbh                 => $dbh_trans,
            rtv_stock_type      => $rtv_stock_type_to,
            location_id         => $location_id_to,
            variant_id          => $rtv_stock_ref_to->[0]{variant_id},
            quantity            => $rtv_stock_ref_to->[0]{quantity},
            delivery_item_id    => $rtv_stock_ref_to->[0]{delivery_item_id},
            origin              => $rtv_stock_ref_to->[0]{origin},
            channel_id          => $rtv_stock_ref_to->[0]{channel_id},
        });

    log_rtv_stock({
        dbh             => $dbh_trans,
        variant_id      => $rtv_stock_ref_to->[0]{variant_id},
        rtv_action_id   => $RTV_ACTION__SYSTEM_TRANSFER,
        quantity        => $rtv_stock_ref_to->[0]{quantity},
        operator_id     => $operator_id,
        notes           => "To $rtv_stock_type_to",
        channel_id      => $rtv_stock_ref_to->[0]{channel_id},
    });
    return $rtv_quantity_id;
}

sub transfer_nonfaulty_stock :Export(:nonfaulty) {
    my ($arg_ref)           = @_;
    my $dbh_trans           = $arg_ref->{dbh};
    my $variant_id          = $arg_ref->{variant_id};
    my $location_id_from    = $arg_ref->{location_id_from};
    my $quantity            = $arg_ref->{quantity};
    my $location_id_to      = defined $arg_ref->{location_id_to} ? $arg_ref->{location_id_to} : '';
    my $operator_id         = $arg_ref->{operator_id};
    my $channel_id          = $arg_ref->{channel_id};
    my $schema              = get_schema_using_dbh( $dbh_trans, 'xtracker_schema' );

    croak "Invalid variant_id ($variant_id)" if $variant_id !~ $FORMAT_REGEXP{id};
    croak "Invalid 'from' location id ($location_id_from)" if $location_id_from !~ $FORMAT_REGEXP{id};
    croak "Invalid quantity ($quantity)" if $quantity !~ $FORMAT_REGEXP{int_positive};
    croak "Invalid operator_id ($operator_id)" if $operator_id !~ $FORMAT_REGEXP{id};
    croak "Invalid channel_id ($channel_id)" if $channel_id !~ $FORMAT_REGEXP{id};

    my $location_from = $schema->resultset('Public::Location')->find({id=>$location_id_from});
    croak "Did not find location for id ($location_id_from)" unless $location_from;
    if ($location_from->allows_status($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS)) {
        croak "location ($location_id_from) cannot hold quantity of status Main Stock";
    }

    ## default to location ('RTV Non-Faulty' RTV Process location)
    if ( $location_id_to !~ $FORMAT_REGEXP{id} ) {
        $location_id_to = get_location_details( { dbh => $dbh_trans, location => 'RTV Non-Faulty' } )->{location_id};
    }
    croak "Invalid 'to' location id ($location_id_to)" if $location_id_to !~ $FORMAT_REGEXP{id};

    my $quantity_in_location = get_stock_location_quantity( $dbh_trans, {
        variant_id => $variant_id,
        location => $location_from->location,
        channel_id => $channel_id,
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );

    if ( $quantity <= $quantity_in_location ) {
        update_quantity(
            $dbh_trans,
            {
                    variant_id => $variant_id,
                      location => $location_from->location,
                      quantity => -$quantity,
                          type => 'dec',
                    channel_id => $channel_id,
             current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            }
        );
    }
    else {
        croak "Transfer failed.  Specified quantity exceeds location quantity";
    }
    my $location_qty = get_stock_location_quantity( $dbh_trans, {
        variant_id => $variant_id,
        location => $location_from->location,
        channel_id => $channel_id,
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    } );
    if ($location_qty <= 0) {
        delete_quantity( $dbh_trans, {
            variant_id => $variant_id,
            location => $location_from->location,
            channel_id => $channel_id,
            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        });
    }

    my $rtv_quantity_id
        = move_rtv_stock_in({
            dbh                 => $dbh_trans,
            rtv_stock_type      => 'RTV Process',
            location_id         => $location_id_to,
            variant_id          => $variant_id,
            quantity            => $quantity,
            origin              => 'NF',
            channel_id          => $channel_id
        });

    ## insert original location detail (used for picklist)
    _insert_rtv_nonfaulty_location({
        dbh                 => $dbh_trans,
        rtv_quantity_id     => $rtv_quantity_id,
        original_location   => $location_from->location,
    });

    ## insert transaction log record
    log_stock(
        $dbh_trans,
        {
            variant_id  => $variant_id,
            action      => $STOCK_ACTION__RTV_NON_DASH_FAULTY,
            quantity    => -$quantity,
            operator_id => $operator_id,
            notes       => "From " . $location_from->location,
            channel_id  => $channel_id
        },
    );

    ## insert RTV log record
    log_rtv_stock({
        dbh             => $dbh_trans,
        variant_id      => $variant_id,
        rtv_action_id   => $RTV_ACTION__NON_DASH_FAULTY,
        quantity        => $quantity,
        operator_id     => $operator_id,
        notes           => "From " . $location_from->location,
        channel_id      => $channel_id
    });
    return $rtv_quantity_id;
}

sub _insert_rtv_nonfaulty_location {
    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $rtv_quantity_id     = $arg_ref->{rtv_quantity_id};
    my $original_location   = $arg_ref->{original_location};

    croak "Invalid rtv_quantity_id ($rtv_quantity_id)" if $rtv_quantity_id !~ $FORMAT_REGEXP{id};
    croak "Invalid location ($original_location)" if $original_location !~ $FORMAT_REGEXP{location};

    my $sql
        = q{INSERT INTO rtv_nonfaulty_location (rtv_quantity_id, original_location)
                VALUES (?, ?)
        };

    my $sth = $dbh->prepare($sql);
    $sth->execute($rtv_quantity_id,$original_location);
    return;
}

sub split_rtv_quantity :Export(:rtv_stock) {
    my ($dbh_trans, $arg_ref)       = @_;

    my $rtv_quantity_id = $arg_ref->{rtv_quantity_id};
    my $split_quantity  = $arg_ref->{split_quantity};

    croak "Invalid rtv_quantity_id ($rtv_quantity_id)" if $rtv_quantity_id !~ $FORMAT_REGEXP{id};
    croak "Invalid split quantity ($split_quantity)" if $split_quantity !~ m{\A[1-9]\d{0,2}\z}xms;  ## allow positive integers 1 - 999

    ## get current line quantity
    my $rtv_quantity_ref        = get_rtv_quantity_row( { dbh => $dbh_trans, rtv_quantity_id => $rtv_quantity_id} );
    my $current_line_quantity   = $rtv_quantity_ref->{quantity};

    if ( $split_quantity > ($current_line_quantity - 1) ) {
        croak "Unable to split line!  Split quantity ($split_quantity) must be less than current line quantity ($current_line_quantity)";
    }

    my $update_line_quantity = $current_line_quantity - $split_quantity;

    ## update current line quantity
    my $sql = q{UPDATE rtv_quantity SET quantity = ? WHERE id = ?};
    my $sth = $dbh_trans->prepare($sql);
    $sth->execute($update_line_quantity, $rtv_quantity_id);

    ## insert new rtv_quantity record
    my $rtv_quantity_id_new
        = insert_rtv_quantity({
            dbh                 => $dbh_trans,
            location_id         => $rtv_quantity_ref->{location_id},
            variant_id          => $rtv_quantity_ref->{variant_id},
            quantity            => $split_quantity,
            delivery_item_id    => $rtv_quantity_ref->{delivery_item_id},
            origin              => $rtv_quantity_ref->{origin},
            channel_id          => $rtv_quantity_ref->{channel_id},
            initial_status_id   => $rtv_quantity_ref->{status_id},
        });
    return $rtv_quantity_id_new;
}

sub get_rtv_quantity_row :Export() {
    my ($arg_ref)               = @_;
    my $dbh                     = $arg_ref->{dbh};
    my $rtv_quantity_id         = $arg_ref->{rtv_quantity_id};

    croak "Invalid rtv_quantity_id ($rtv_quantity_id)" if $rtv_quantity_id !~ $FORMAT_REGEXP{id};

    my $qry = q{SELECT * FROM rtv_quantity WHERE id = ?};

    my $sth = $dbh->prepare($qry);
    $sth->execute($rtv_quantity_id);

    my $rtv_quantity_ref = $sth->fetchrow_hashref();
    $sth->finish();
    return $rtv_quantity_ref;
}

sub get_rtv_stock :Export(:rtv_stock) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $type            = $arg_ref->{type};
    my $id              = $arg_ref->{id};

    $type   = lc(trim($type));
    croak "Invalid type ($type)" if $type !~ m{\A(rtv_quantity_id|rma_request_id|rma_request_detail_id|rtv_shipment_id|rtv_shipment_detail_id)\z}xms;
    croak "Invalid $type ($id)" if $id !~ $FORMAT_REGEXP{id};

    ## build 'where' clause
    my $where_clause    = undef;
    my @exec_args       = ();
    for ($type) {
        m{\Aall\z}xmsi                      && do { $where_clause = undef; last; };
        m{\Artv_quantity_id\z}xmsi          && do { $where_clause = 'id = ?'; push @exec_args, $id; last; };
        m{\Arma_request_id\z}xmsi           && do { $where_clause = 'rma_request_id = ?'; push @exec_args, $id; last; };
        m{\Arma_request_detail_id\z}xmsi    && do { $where_clause = 'rma_request_detail_id = ?'; push @exec_args, $id; last; };
        m{\Artv_shipment_id\z}xmsi          && do { $where_clause = 'rtv_shipment_id = ?'; push @exec_args, $id; last; };
        m{\Artv_shipment_detail_id\z}xmsi   && do { $where_clause = 'rtv_shipment_detail_id = ?'; push @exec_args, $id; last; };
        croak "Unknown type ($_)";
    }

    my $qry = q{SELECT * FROM vw_rtv_quantity};
    $qry .= qq{ WHERE $where_clause} if defined $where_clause;

    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);

    my $rtv_stock_ref = results_list($sth);
    return $rtv_stock_ref;
}

sub get_location_details :Export(:rtv_stock) {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $location_id = $arg_ref->{location_id};
    my $location    = $arg_ref->{location};

    my $where_clause;
    my $exec_arg;
    if ( defined $location_id and $location_id =~ $FORMAT_REGEXP{id} ) {
        $where_clause   = 'location_id = ?';
        $exec_arg       = $location_id;
    }
    elsif ( defined $location ) {
        $where_clause   = 'location = ?';
        $exec_arg       = $location;
    }
    else {
        croak 'Invalid Location';
    }

    my $qry
        = qq{SELECT *
            FROM vw_location_details
            WHERE $where_clause
            ORDER BY location_id
            LIMIT 1
        };
    my $sth = $dbh->prepare($qry);
    $sth->execute($exec_arg);

    my $location_details_ref = $sth->fetchrow_hashref();
    $sth->finish();
    return $location_details_ref;
}

sub list_rtv_stock :Export(:rtv_stock) {
    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $rtv_stock_type      = $arg_ref->{rtv_stock_type};
    my $type                = defined $arg_ref->{type} ? $arg_ref->{type} : 'all';
    my $id                  = $arg_ref->{id};
    my $get_image_names     = defined $arg_ref->{get_image_names} ? $arg_ref->{get_image_names} : 0;
    my $get_di_fault_data   = defined $arg_ref->{get_di_fault_data} ? $arg_ref->{get_di_fault_data} : 0;
    my $hide_requested      = $arg_ref->{hide_requested} ? 1 : 0;
    my $columnsort_ref      = $arg_ref->{columnsort};
    my $channel_id          = $arg_ref->{channel_id};
    my $schema              = get_schema_using_dbh( $dbh, 'xtracker_schema' );

    $type   = lc(trim($type));
    croak "Invalid rtv_stock_type ($rtv_stock_type)" if $rtv_stock_type !~ m{\A(RTV\sGoods\sIn|RTV\sWorkstation|RTV\sProcess)\z}xms;
    my $rtv_stock_type_obj = $schema->resultset('Flow::Status')->find({name=>$rtv_stock_type});

    croak "Invalid $type ($id)" if ( $type ne 'all' and $id !~ $FORMAT_REGEXP{id} );
    croak "Invalid channel_id ($channel_id)" if ( $channel_id !~ $FORMAT_REGEXP{id} );

    ## build 'where' clause
    my $where_clause    = undef;
    my @exec_args       = ();
    push @exec_args, $channel_id;
    for ($type) {
            m{\Aall\z}xmsi              && do { $where_clause = 'rq.status_id = ?'; push @exec_args, $rtv_stock_type_obj->id; last; };
            m{\Adesigner_id\z}xmsi      && do { $where_clause = 'rq.status_id = ? AND des.id = ?'; push @exec_args, $rtv_stock_type_obj->id, $id; last; };
            m{\Aproduct_id\z}xmsi       && do { $where_clause = 'rq.status_id = ? AND p.id = ?'; push @exec_args, $rtv_stock_type_obj->id, $id; last; };
            croak "Unknown type ($_)";
    }

    my $filter_clause = '';
    $filter_clause = 'rrd.id IS NULL' if $hide_requested;

    ## build 'order by' clause
    my $sort_clause = undef;
    my $asc_desc    = defined $columnsort_ref->{asc_desc} ? $columnsort_ref->{asc_desc} : 'ASC';
    my $order_by    = defined $columnsort_ref->{order_by} ? $columnsort_ref->{order_by} : '';
    for ($order_by) {
        m{\Aproduct_id\z}xmsi           && do { $sort_clause = "product_id $asc_desc, size_id, delivery_item_id"; last; };
        m{\Adesigner\z}xmsi             && do { $sort_clause = "designer $asc_desc, product_id, size_id, delivery_item_id"; last; };
        m{\Aproduct_type\z}xmsi         && do { $sort_clause = "product_type $asc_desc, designer, product_id, size_id, delivery_item_id"; last; };
        m{\Artv_quantity_date\z}xmsi    && do { $sort_clause = "rtv_quantity_date $asc_desc, designer, product_id, size_id, delivery_item_id"; last; };
        m{\Adelivery_date\z}xmsi        && do { $sort_clause = "delivery_date $asc_desc, designer, product_id, size_id, delivery_item_id"; last; };
        m{\Aquantity\z}xmsi             && do { $sort_clause = "quantity $asc_desc, designer, product_id, size_id, delivery_item_id"; last; };
        m{\Alocation\z}xmsi             && do { $sort_clause = "location $asc_desc, product_id, size_id, delivery_item_id"; last; };
                                              { $sort_clause = "designer, sku, rtv_quantity_id DESC"; };
    }

    my $qry = qq{SELECT rq.id AS rtv_quantity_id,
                        rq.channel_id AS channel_id,
                        rq.variant_id AS variant_id,
                        rq.location_id AS location_id,
                        rq.origin,
                        rq.date_created AS rtv_quantity_date,
                        TO_CHAR(rq.date_created, 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_quantity_date,
                        l.location,
                        SUBSTRING((l.location)::text, E'\\A(\\d{2})\\d[a-zA-Z]-?\\d{3,4}[a-zA-Z]\\Z'::text) AS loc_dc,
                        SUBSTRING((l.location)::text, E'\\A\\d{2}(\\d)[a-zA-Z]-?\\d{3,4}[a-zA-Z]\\Z'::text) AS loc_floor,
                        SUBSTRING((l.location)::text, E'\\A\\d{2}\\d([a-zA-Z])-?\\d{3,4}[a-zA-Z]\\Z'::text) AS loc_zone,
                        SUBSTRING((l.location)::text, E'\\A\\d{2}\\d[a-zA-Z]-?(\\d{3,4})[a-zA-Z]\\Z'::text) AS loc_section,
                        SUBSTRING((l.location)::text, E'\\A\\d{2}\\d[a-zA-Z]-?\\d{3,4}([a-zA-Z])\\Z'::text) AS loc_shelf,
                        rq.quantity,
                        rq.fault_type_id,
                        ft.fault_type,
                        rq.fault_description,
                        di.delivery_id,
                        rq.delivery_item_id,
                        dit.type AS delivery_item_type,
                        dis.status AS delivery_item_type,
                        d.date AS delivery_date,
                        TO_CHAR(d.date, 'DD-Mon-YYYY HH24:MI'::text) AS txt_delivery_date,
                        v.product_id,
                        v.size_id,
                        sz.size,
                        v.designer_size_id,
                        dsz.size AS designer_size,
                        (v.product_id::text || '-'::text) || sku_padding(v.size_id)::text AS sku,
                        pa.name,
                        pa.description,
                        p.designer_id,
                        des.designer,
                        p.style_number,
                        col.colour,
                        pa.designer_colour_code,
                        pa.designer_colour,
                        p.product_type_id,
                        pt.product_type,
                        p.classification_id,
                        c.classification,
                        p.season_id,
                        s.season,
                        rq.status_id AS quantity_status_id
                   FROM rtv_quantity rq
                   JOIN location l
                     ON rq.location_id = l.id
                   JOIN variant v
                     ON rq.variant_id = v.id
                   JOIN product p
                     ON v.product_id = p.id
                   JOIN product_channel pc
                     ON p.id = pc.product_id
                    AND rq.channel_id = pc.channel_id
                   JOIN product_attribute pa
                     ON p.id = pa.product_id
                   JOIN product_type pt
                     ON p.product_type_id = pt.id
                   JOIN designer des
                     ON p.designer_id = des.id
                   JOIN colour col
                     ON p.colour_id = col.id
                   JOIN classification c
                     ON p.classification_id = c.id
                   JOIN season s
                     ON p.season_id = s.id
                   LEFT JOIN size sz
                     ON v.size_id = sz.id
                   LEFT JOIN size dsz
                     ON v.designer_size_id = dsz.id
                   LEFT JOIN item_fault_type ft
                     ON rq.fault_type_id = ft.id
                   LEFT JOIN rma_request_detail rrd
                     ON rq.id = rrd.rtv_quantity_id
                   LEFT JOIN delivery_item di
                     ON rq.delivery_item_id = di.id
                   LEFT JOIN delivery_item_type dit
                     ON di.type_id = dit.id
                   LEFT JOIN delivery_item_status dis
                     ON di.status_id = dis.id
                   LEFT JOIN delivery d
                     ON di.delivery_id = d.id
    };

    $qry .= qq{ WHERE rq.channel_id = ? };
    $qry .= qq{ AND $where_clause} if defined $where_clause;
    $qry .= qq{ AND $filter_clause} if $filter_clause;
    $qry .= qq{ ORDER BY $sort_clause} if defined $sort_clause;

    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);

    my $rtv_stock_details_ref = results_list($sth);

    ## get image_names if requested
    if ($get_image_names) {
        $_->{image_name} = get_images( { schema => $schema, product_id => $_->{product_id}, live => 1 } )
            foreach ( @$rtv_stock_details_ref );
    }

    ## get delivery_item_fault records if requested
    if ($get_di_fault_data) {
        $_->{delivery_item_fault} = get_delivery_item_fault( { dbh => $dbh, delivery_item_id => $_->{delivery_item_id} } ) foreach ( @$rtv_stock_details_ref );
    }
    return $rtv_stock_details_ref;
}

sub list_rtv_inspection_stock :Export(:rtv_inspection) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $type            = defined $arg_ref->{type} ? $arg_ref->{type} : 'all';
    my $id              = $arg_ref->{id};
    my $origin          = defined $arg_ref->{origin} ? $arg_ref->{origin} : 'ALL';
    my $columnsort_ref  = $arg_ref->{columnsort};

    $type   = lc(trim($type));
    croak "Invalid $type ($id)" if ( $type ne 'all' and $id !~ $FORMAT_REGEXP{id} );
    $origin = uc(trim($origin));
    croak "Invalid origin ($origin)" if $origin !~ m{\A(ALL|GI|CR|ST)\z}xms;

    ## build 'where' clause
    my $where_clause    = undef;
    my @exec_args       = ();
    for ($type) {
            m{\Aall\z}xmsi              && do { $where_clause = 'true'; last; };
            m{\Adesigner_id\z}xmsi      && do { $where_clause = 'designer_id = ?'; push @exec_args, $id; last; };
            m{\Aproduct_id\z}xmsi       && do { $where_clause = 'vw_ris.product_id = ?'; push @exec_args, $id; last; };
            croak "Unknown type ($_)";
    }

    if ($origin ne 'ALL') {
        $where_clause .= ' AND vw_ris.origin = ?';
        push @exec_args, $origin;
    }

    ## build 'order by' clause
    my $sort_clause = undef;
    my $asc_desc    = defined $columnsort_ref->{asc_desc} ? $columnsort_ref->{asc_desc} : 'ASC';
    my $order_by    = defined $columnsort_ref->{order_by} ? $columnsort_ref->{order_by} : '';
    for ($order_by) {
        m{\Aproduct_id\z}xmsi           && do { $sort_clause = "vw_ris.product_id $asc_desc"; last; };
        m{\Aorigin\z}xmsi               && do { $sort_clause = "vw_ris.origin $asc_desc, vw_ris.product_id"; last; };
        m{\Adesigner\z}xmsi             && do { $sort_clause = "designer $asc_desc, vw_ris.product_id"; last; };
        m{\Aproduct_type\z}xmsi         && do { $sort_clause = "product_type $asc_desc, designer, vw_ris.product_id"; last; };
        m{\Artv_quantity_date\z}xmsi    && do { $sort_clause = "rtv_quantity_date $asc_desc, designer, vw_ris.product_id"; last; };
        m{\Adelivery_date\z}xmsi        && do { $sort_clause = "delivery_date $asc_desc, designer, vw_ris.product_id"; last; };
        m{\Asum_quantity\z}xmsi         && do { $sort_clause = "sum_quantity $asc_desc, designer, vw_ris.product_id"; last; };
        m{\Aquantity_requested\z}xmsi   && do { $sort_clause = "quantity_requested $asc_desc, designer, vw_ris.product_id"; last; };
        m{\Aquantity_remaining\z}xmsi   && do { $sort_clause = "quantity_remaining $asc_desc, designer, vw_ris.product_id"; last; };
                                              { $sort_clause = "vw_ris.product_id $asc_desc"; };
    }

    # This query was based on the hugely inefficient (now dropped)
    # vw_rtv_inspection_list;
    my $qry = <<EOQ
SELECT vw_ris.product_id,
    vw_ris.channel_id,
    vw_ris.sales_channel,
    vw_ris.origin,
    vw_ris.rtv_quantity_date,
    vw_ris.txt_rtv_quantity_date,
    vw_ris.designer_id,
    vw_ris.designer,
    vw_ris.colour,
    vw_ris.product_type,
    vw_ris.delivery_id,
    vw_ris.delivery_date,
    vw_ris.txt_delivery_date,
    vw_ris.sum_quantity,
    COALESCE(vw_ripr.quantity_requested, 0) AS quantity_requested,
    vw_ris.sum_quantity - COALESCE(vw_ripr.quantity_requested, 0::bigint) AS quantity_remaining,
    vw_ripr.rtv_inspection_pick_request_id
FROM (
    SELECT v.product_id,
        rq.channel_id,
        ch.name AS sales_channel,
        rq.origin,
        MAX(rq.date_created) AS rtv_quantity_date,
        TO_CHAR(MAX(rq.date_created), 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_quantity_date,
        p.designer_id,
        des.designer,
        col.colour,
        pt.product_type,
        di.delivery_id,
        del.date AS delivery_date,
        TO_CHAR(del.date, 'DD-Mon-YYYY HH24:MI'::text) AS txt_delivery_date,
        SUM(rq.quantity) AS sum_quantity
    FROM rtv_quantity rq
    JOIN variant v ON rq.variant_id = v.id
    JOIN product p ON v.product_id = p.id
    JOIN product_channel pc ON p.id = pc.product_id AND rq.channel_id = pc.channel_id
    JOIN channel ch ON pc.channel_id = ch.id
    JOIN designer des ON p.designer_id = des.id
    JOIN colour col ON p.colour_id = col.id
    JOIN product_type pt ON p.product_type_id = pt.id
    LEFT JOIN delivery_item di ON rq.delivery_item_id = di.id
    LEFT JOIN delivery del ON di.delivery_id = del.id
    WHERE rq.status_id = $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS
    GROUP BY v.product_id,
        rq.channel_id,
        ch.name,
        rq.origin,
        p.designer_id,
        des.designer,
        col.colour,
        pt.product_type,
        di.delivery_id,
        del.date
) vw_ris
LEFT JOIN (
    SELECT pc.product_id,
        rq.origin,
        di.delivery_id,
        SUM(rq.quantity) AS quantity_requested,
        ripr.id AS rtv_inspection_pick_request_id
    FROM rtv_inspection_pick_request ripr
    JOIN rtv_inspection_pick_request_detail riprd ON riprd.rtv_inspection_pick_request_id = ripr.id
    JOIN rtv_quantity rq ON riprd.rtv_quantity_id = rq.id
    JOIN variant v ON v.id = rq.variant_id
    JOIN product_channel pc ON v.product_id = pc.product_id AND rq.channel_id = pc.channel_id
    LEFT JOIN delivery_item di ON rq.delivery_item_id = di.id
    WHERE ripr.status_id IN ($RTV_INSPECTION_PICK_REQUEST_STATUS__NEW, $RTV_INSPECTION_PICK_REQUEST_STATUS__PICKING)
    GROUP BY pc.product_id,
        rq.origin,
        di.delivery_id,
        ripr.id
) vw_ripr ON vw_ris.product_id = vw_ripr.product_id AND vw_ris.origin::text = vw_ripr.origin::text AND vw_ris.delivery_id = vw_ripr.delivery_id
EOQ
;
    $qry .= qq{ WHERE $where_clause} if defined $where_clause;
    $qry .= qq{ ORDER BY $sort_clause} if defined $sort_clause;

    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);

    my $rtv_inspection_stock_ref = results_list($sth);
    return $rtv_inspection_stock_ref;
}

sub list_rtv_workstation_stock :Export(:rtv_inspection) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $type            = defined $arg_ref->{type} ? $arg_ref->{type} : 'all';
    my $id              = $arg_ref->{id};
    my $origin          = defined $arg_ref->{origin} ? $arg_ref->{origin} : 'ALL';
    my $columnsort_ref  = $arg_ref->{columnsort};

    $type   = lc(trim($type));
    croak "Invalid $type ($id)" if ( $type ne 'all' and $id !~ $FORMAT_REGEXP{id} );
    $origin = uc(trim($origin));
    croak "Invalid origin ($origin)" if $origin !~ m{\A(ALL|GI|CR|ST)\z}xms;

    ## build 'where' clause
    my $where_clause    = undef;
    my @exec_args       = ();
    for ($type) {
            m{\Aall\z}xmsi              && do { $where_clause = 'true'; last; };
            m{\Adesigner_id\z}xmsi      && do { $where_clause = 'designer_id = ?'; push @exec_args, $id; last; };
            m{\Aproduct_id\z}xmsi       && do { $where_clause = 'product_id = ?'; push @exec_args, $id; last; };
            croak "Unknown type ($_)";
    }

    if ($origin ne 'ALL') {
        $where_clause .= ' AND origin = ?';
        push @exec_args, $origin;
    }

    ## build 'order by' clause
    my $sort_clause = undef;
    my $asc_desc    = defined $columnsort_ref->{asc_desc} ? $columnsort_ref->{asc_desc} : 'ASC';
    my $order_by    = defined $columnsort_ref->{order_by} ? $columnsort_ref->{order_by} : '';
    for ($order_by) {
        m{\Alocation\z}xmsi             && do { $sort_clause = "location, product_id $asc_desc"; last; };
        m{\Aproduct_id\z}xmsi           && do { $sort_clause = "location, product_id $asc_desc"; last; };
        m{\Aorigin\z}xmsi               && do { $sort_clause = "location, origin, product_id $asc_desc"; last; };
        m{\Adesigner\z}xmsi             && do { $sort_clause = "location, designer $asc_desc, product_id"; last; };
        m{\Aproduct_type\z}xmsi         && do { $sort_clause = "location, product_type $asc_desc, designer, product_id"; last; };
        m{\Artv_quantity_date\z}xmsi    && do { $sort_clause = "location, rtv_quantity_date $asc_desc, designer, product_id"; last; };
        m{\Adelivery_date\z}xmsi        && do { $sort_clause = "location, delivery_date $asc_desc, designer, product_id"; last; };
        m{\Asum_quantity\z}xmsi         && do { $sort_clause = "location, sum_quantity $asc_desc, designer, product_id"; last; };
                                              { $sort_clause = "location, product_id $asc_desc"; };
    }

    # This query is based on the (now-deleted) vw_rtv_workstation_stock
    my $qry = <<EOQ
SELECT vw_rtv_stock_details.channel_id,
       channel.name AS sales_channel,
       vw_rtv_stock_details.location_id,
       vw_rtv_stock_details.location,
       vw_rtv_stock_details.product_id,
       vw_rtv_stock_details.origin,
       MAX(vw_rtv_stock_details.rtv_quantity_date) AS rtv_quantity_date,
       TO_CHAR(MAX(vw_rtv_stock_details.rtv_quantity_date), 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_quantity_date,
       vw_rtv_stock_details.designer_id,
       vw_rtv_stock_details.designer,
       vw_rtv_stock_details.colour,
       vw_rtv_stock_details.product_type,
       vw_rtv_stock_details.delivery_id,
       vw_rtv_stock_details.delivery_date,
       TO_CHAR(vw_rtv_stock_details.delivery_date, 'DD-Mon-YYYY HH24:MI'::text) AS txt_delivery_date,
       SUM(vw_rtv_stock_details.quantity) AS sum_quantity
FROM (
    SELECT rq.channel_id,
           rq.location_id,
           l.location,
           v.product_id,
           rq.origin,
           rq.date_created AS rtv_quantity_date,
           p.designer_id,
           d.designer,
           col.colour,
           pt.product_type,
           di.delivery_id,
           del.date AS delivery_date,
           rq.quantity,
           rq.status_id AS quantity_status_id
    FROM rtv_quantity rq
    JOIN location l ON rq.location_id = l.id
    JOIN variant v ON rq.variant_id = v.id
    JOIN product p ON v.product_id = p.id
    JOIN product_channel pc ON rq.channel_id = pc.channel_id AND p.id = pc.product_id
    JOIN designer d ON p.designer_id = d.id
    JOIN colour col ON p.colour_id = col.id
    JOIN product_type pt ON p.product_type_id = pt.id
    LEFT JOIN delivery_item di ON rq.delivery_item_id = di.id
    LEFT JOIN delivery del ON di.delivery_id = del.id
    WHERE rq.status_id = $FLOW_STATUS__RTV_WORKSTATION__STOCK_STATUS
) vw_rtv_stock_details
JOIN channel ON vw_rtv_stock_details.channel_id = channel.id
EOQ
;
    $qry .= qq{ WHERE $where_clause} if defined $where_clause;
    $qry = join qq{\n}, $qry, <<EOGB
GROUP BY vw_rtv_stock_details.channel_id,
         channel.name,
         vw_rtv_stock_details.location_id,
         vw_rtv_stock_details.location,
         vw_rtv_stock_details.product_id,
         vw_rtv_stock_details.origin,
         vw_rtv_stock_details.designer_id,
         vw_rtv_stock_details.designer,
         vw_rtv_stock_details.colour,
         vw_rtv_stock_details.product_type,
         vw_rtv_stock_details.delivery_id,
         vw_rtv_stock_details.delivery_date
EOGB
;
    $qry .= qq{ ORDER BY $sort_clause} if defined $sort_clause;

    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);

    my $rtv_workstation_stock_ref = results_list($sth);
    return $rtv_workstation_stock_ref;
}

sub list_rtv_stock_designers :Export(:rtv_stock) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};

    my $qry = q{SELECT designer_id, designer FROM vw_rtv_stock_designers ORDER BY designer, designer_id};

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $rtv_stock_designers_ref = results_list($sth);
    return $rtv_stock_designers_ref;
}

sub list_item_fault_types :Export(:rtv_stock) {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};

    my $qry = q{SELECT id, fault_type FROM item_fault_type ORDER BY fault_type};

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $results_ref = results_list($sth);
    return $results_ref;
}

sub list_nonfaulty_stock :Export(:nonfaulty) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $product_ids_ref = $arg_ref->{product_ids};
    my $channel_id      = $arg_ref->{channel_id};

    my $msg_croak       = '';
    my @invalid_pids    = ();
    $msg_croak .= "No channel_id was specified" unless defined $channel_id;
    $msg_croak .= "No product_id's were specified" unless scalar @{$product_ids_ref};
    map { push @invalid_pids, $_ if $_ !~ $FORMAT_REGEXP{int_positive} } @{$product_ids_ref};
    $msg_croak .= "Invalid PID's: " . join(', ', @invalid_pids) if scalar @invalid_pids;
    croak $msg_croak if $msg_croak;

    my $qry
        = qq{SELECT
                d.id AS designer_id
            ,   d.designer
            ,   v.id AS variant_id
            ,   p.id AS product_id
            ,   v.size_id
            ,   v.product_id || '-' || sku_padding(v.size_id) as sku
            ,   ds.size AS designer_size
            ,   dc_stock.location_id
            ,   dc_stock.location
            ,   dc_stock.quantity_status
            ,   dc_stock.quantity_id
            ,   dc_stock.quantity
            FROM variant v
            INNER JOIN product p
                ON (v.product_id = p.id)
            INNER JOIN designer d
                ON (p.designer_id = d.id)
            LEFT JOIN size ds
                ON (v.designer_size_id = ds.id)
            LEFT JOIN
                (SELECT
                    v.id AS variant_id
                ,   q.id AS quantity_id
                ,   q.quantity
                ,   l.id AS location_id
                ,   l.location
                ,   f.name as quantity_status
                FROM variant v
                INNER JOIN quantity q
                    ON (q.variant_id = v.id)
                INNER JOIN location l
                    ON (q.location_id = l.id)
                INNER JOIN flow.status f
                    ON (q.status_id = f.id)
                AND q.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
                AND q.quantity > 0
                AND q.channel_id = ?) dc_stock
                ON (v.id = dc_stock.variant_id)
            WHERE p.id IN (@{[ join(', ', @{$product_ids_ref}) ]})
            ORDER BY d.designer, p.id, v.size_id, dc_stock.location
        };
    my $sth = $dbh->prepare($qry);

    $sth->execute( $channel_id );
    my $nonfaulty_stock_ref = results_list($sth);
    return $nonfaulty_stock_ref;
}

sub list_nonfaulty_allocated :Export(:nonfaulty) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $product_ids_ref = $arg_ref->{product_ids};
    my $channel_id      = $arg_ref->{channel_id};

    my $msg_croak       = '';
    my @invalid_pids    = ();
    $msg_croak .= "No channel_id was specified" unless defined $channel_id;
    $msg_croak .= "No product_id's were specified" unless scalar @{$product_ids_ref};
    map { push @invalid_pids, $_ if $_ !~ $FORMAT_REGEXP{int_positive} } @{$product_ids_ref};
    $msg_croak .= "Invalid PID's: " . join(', ', @invalid_pids) if scalar @invalid_pids;
    croak $msg_croak if $msg_croak;

    my $qry
        = qq{SELECT
                p.id AS product_id
            ,   allocated.variant_id
            ,   p.id || '-' || sku_padding(allocated.size_id) as sku
            ,   SUM(allocated.quantity) AS quantity
            FROM public.product p
            INNER JOIN
                (
                    SELECT product_id, size_id, id AS variant_id, 0 AS quantity
                    FROM variant
                    WHERE type_id = (SELECT id FROM variant_type WHERE type = 'Stock')
                UNION ALL
                    SELECT v.product_id, v.size_id, r.variant_id, COUNT(*) AS quantity
                    FROM reservation r
                    INNER JOIN variant v
                        ON (r.variant_id = v.id)
                    AND r.status_id = (SELECT id FROM reservation_status WHERE status = 'Uploaded')
                    AND r.channel_id = ?
                    GROUP BY v.product_id, v.size_id, r.variant_id
                UNION ALL
                    SELECT v.product_id, v.size_id, si.variant_id, COUNT(*) AS quantity
                    FROM shipment_item si
                    INNER JOIN variant v
                        ON (si.variant_id = v.id)
                    INNER JOIN link_orders__shipment los
                        ON (si.shipment_id = los.shipment_id)
                    INNER JOIN orders o
                        ON (los.orders_id = o.id)
                    AND si.shipment_item_status_id IN (SELECT id FROM shipment_item_status WHERE status IN ('New', 'Selected', 'Picked'))
                    AND o.channel_id = ?
                    GROUP BY v.product_id, v.size_id, si.variant_id
                ) AS allocated
                ON (allocated.product_id = p.id)
            GROUP BY p.id, allocated.variant_id, p.id || '-' || sku_padding(allocated.size_id), allocated.size_id
            HAVING p.id IN (@{[ join(', ', @{$product_ids_ref}) ]}) AND SUM(allocated.quantity) > 0
            ORDER BY p.id, allocated.size_id
        };
    my $sth = $dbh->prepare($qry);

    $sth->execute( $channel_id, $channel_id );
    my $nonfaulty_allocated_ref = results_hash2($sth, 'variant_id');
    return $nonfaulty_allocated_ref;
}

#-------------------------------------------------------------------------------
# RMA Request
#-------------------------------------------------------------------------------

sub list_rma_request_statuses :Export(:rma_request) {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};

    my $qry = q{SELECT * FROM rma_request_status ORDER BY status};

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $results_ref = results_list($sth);
    return $results_ref;
}

sub list_rma_request_detail_types :Export(:rma_request) {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $category    = defined $arg_ref->{category} ? $arg_ref->{category} : 'ALL';

    croak "Invalid category ($category)" if $category !~ m{\A(?:ALL|nonfaulty)\z}xms;

    my $qry
        = q{SELECT id, type
            FROM rma_request_detail_type
            WHERE id > 0
        };

    if ( $category eq 'nonfaulty' ) {
        $qry .= q{AND type IN ('Sale or Return', 'Stock Swap')}
    }

    $qry .= q{ ORDER BY type};

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $results_ref = results_list($sth);
    return $results_ref;
}

sub list_rma_request_designers :Export(:rma_request) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};

    my $qry = q{SELECT * FROM vw_rma_request_designers ORDER BY designer, designer_id};

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $rma_request_designers_ref = results_list($sth);
    return $rma_request_designers_ref;
}

sub list_rma_request_seasons :Export(:rma_request) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};

    my $qry
        = q{SELECT DISTINCT s.id, s.season
            FROM rma_request_detail rrd
            INNER JOIN variant v
                ON (rrd.variant_id = v.id)
            INNER JOIN product p
                ON (v.product_id = p.id)
            INNER JOIN season s
                ON (p.season_id = s.id)
            ORDER BY id
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $rma_request_seasons_ref = results_list($sth);
    return $rma_request_seasons_ref;
}

sub create_rma_request :Export(:rma_request) {
    my ($arg_ref)   = @_;
    my $dbh_trans   = $arg_ref->{dbh};
    my $head_ref    = $arg_ref->{head_ref};
    my $dets_ref    = $arg_ref->{dets_ref};

    croak 'Insufficient data! RMA request was ** NOT ** created' unless scalar keys %{$dets_ref};

    my $operator_id         = $head_ref->{operator_id};
    my $header_status_id    = $RMA_REQUEST_STATUS__NEW;
    my $detail_status_id    = $RMA_REQUEST_DETAIL_STATUS__NEW;
    my $date_request        = $head_ref->{date_request};
    my $date_followup       = $head_ref->{date_followup};
    my $comments            = $head_ref->{comments};
    my $channel_id          = $head_ref->{channel_id};

    croak 'No channel_id defined to create RMA request' unless defined $channel_id;

    ## insert rma_request record
    my $sql_insert_header
        = q{INSERT INTO rma_request (operator_id, status_id, date_request, date_followup, comments, channel_id)
                VALUES (?, ?, default, default, ?, ?)
        };
    my $sth_insert_header = $dbh_trans->prepare($sql_insert_header);
    $sth_insert_header->execute($operator_id, $header_status_id, $comments, $channel_id);

    my $rma_request_id = last_insert_id($dbh_trans, 'rma_request_id_seq');

    ## create initial rma_request_status_log record
    _log_status_update ({
        dbh         => $dbh_trans,
        type        => 'rma_request',
        id          => $rma_request_id,
        status_id   => $header_status_id,
        operator_id => $operator_id,
    });

    ## insert rma_request_detail_record
    my $sql_insert_detail
        = q{INSERT INTO rma_request_detail (rma_request_id, rtv_quantity_id, variant_id, quantity, delivery_item_id, fault_type_id, fault_description, type_id, status_id)
                (SELECT ?, id, variant_id, quantity, delivery_item_id, fault_type_id, fault_description, ?, ?
                FROM rtv_quantity
                WHERE id = ?)
        };

    my $sth_insert_detail = $dbh_trans->prepare($sql_insert_detail);

    foreach my $rtv_quantity_id ( sort keys %{$dets_ref} ) {
        my $fault_type_id   = $dets_ref->{$rtv_quantity_id}{type_id};
        $sth_insert_detail->execute($rma_request_id, $fault_type_id, $detail_status_id, $rtv_quantity_id);

        my $rma_request_detail_id = last_insert_id($dbh_trans, 'rma_request_detail_id_seq');

        ## create initial rma_request_detail_status_log record
        _log_status_update ({
            dbh         => $dbh_trans,
            type        => 'rma_request_detail',
            id          => $rma_request_detail_id,
            status_id   => $detail_status_id,
            operator_id => $operator_id,
        });
    }
    return $rma_request_id;
}

sub update_rma_request :Export(:rma_request) {
    my ($arg_ref)       = @_;
    my $dbh_trans       = $arg_ref->{dbh};
    my $rma_request_id  = $arg_ref->{rma_request_id};
    my $fields_ref      = $arg_ref->{fields_ref};

    croak "Invalid rma_request_id ($rma_request_id)" if $rma_request_id !~ $FORMAT_REGEXP{id};

    my $table_name      = 'rma_request';

    ## map %{$fields_ref} keys to database field names
    my %db_fieldmap = (
        date_followup   => 'date_followup',
        date_complete   => 'date_complete',
        rma_number      => 'rma_number',
        comments        => 'comments',
    );

    my %update_fields = ();
    foreach my $update_parameter_name ( keys %{$fields_ref} ) {
        my $db_field_name = $db_fieldmap{$update_parameter_name};

        if ( exists $fields_ref->{$update_parameter_name} ) {
            $update_fields{$table_name}{$rma_request_id}{$db_field_name} = $fields_ref->{$update_parameter_name};
        }
    }

    ## perform the update
    update_fields({
        dbh             => $dbh_trans,
        update_fields   => \%update_fields,
    });
    return;
}

sub list_rma_requests :Export(:rma_request) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $columnsort_ref  = $arg_ref->{columnsort};
    my $params             = $arg_ref->{params};

    ## build 'where' clause

    my %colname_map = (
        map { $_ => $_ } qw{
            rma_request_id
            designer_id
            product_id
            variant_id
            rma_request_status_id
        }
    );
    my @where_clause = map {
        my $colname = $colname_map{$_} || croak "Unknown type ($_)";
        my $val = $params->{$_};
        # Create the required SQL for the condition
        my $sql =  " $colname = ?";
        # Return a hashref tying the sql to its bind values
        +{ $sql => $val };
    } keys %$params;


    # build 'order by' clause
    my $sort_clause = undef;
    my $asc_desc    = defined $columnsort_ref->{asc_desc} ? $columnsort_ref->{asc_desc} : 'ASC';
    my $order_by    = defined $columnsort_ref->{order_by} ? $columnsort_ref->{order_by} : '';
    for ($order_by) {
        m{\Arma_request_id\z}xmsi   && do { $sort_clause = "rma_request_id $asc_desc"; last; };
        m{\Adesigner\z}xmsi         && do { $sort_clause = "designer $asc_desc"; last; };
        m{\Adate_request\z}xmsi     && do { $sort_clause = "date_request $asc_desc"; last; };
        m{\Astatus\z}xmsi           && do { $sort_clause = "rma_request_status $asc_desc"; last; };
        m{\Asum_quantity\z}xmsi     && do { $sort_clause = "sum(rma_request_detail_quantity) $asc_desc"; last; };
        m{\Adate_followup\z}xmsi    && do { $sort_clause = "date_followup $asc_desc"; last; };
        m{\Asales_channel\z}xmsi    && do { $sort_clause = "sales_channel $asc_desc"; last; };
                                          { $sort_clause = "rma_request_id $asc_desc"; };
    }

    my $qry
        = qq{SELECT
                rma_request_id,
                sales_channel,
                rma_request_status,
                rma_number,
                designer_id,
                designer,
                date_request,
                txt_date_request,
                date_followup,
                txt_date_followup,
                rma_request_comments,
                sum(rma_request_detail_quantity) AS sum_rma_request_detail_quantity
            FROM vw_rma_request_details
        };
    $qry .= qq{ WHERE rma_request_detail_status_id not in ($RMA_REQUEST_DETAIL_STATUS__SENT_TO_DEAD_STOCK, $RMA_REQUEST_DETAIL_STATUS__RTV)};
    $qry .= " AND".join q{ AND }, map { keys %$_ } @where_clause
        if @where_clause;
    $qry
        .= qq{ GROUP BY rma_request_id, sales_channel, rma_request_status, rma_number, designer_id, designer,
                    date_request, txt_date_request, date_followup, txt_date_followup,
                    rma_request_comments
        };
    $qry .= qq{ ORDER BY $sort_clause};

    my $sth = $dbh->prepare($qry);
    my @exec_args = map {
        (grep { $_ && $_ eq 'ARRAY' } ref $_) ? @$_ : $_
    } map { values %$_ } @where_clause;
    $sth->execute(@exec_args);

    my $rma_requests_ref = results_list($sth);
    return $rma_requests_ref;
}

sub list_rma_request_details :Export(:rma_request) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $type            = defined $arg_ref->{type} ? $arg_ref->{type} : 'all';
    my $id              = $arg_ref->{id};
    my $results_as_hash = defined $arg_ref->{results_as_hash} ? $arg_ref->{results_as_hash} : 0;
    my $get_image_names = defined $arg_ref->{get_image_names} ? $arg_ref->{get_image_names} : 0;
    my $schema          = get_schema_using_dbh( $dbh, 'xtracker_schema' );

    ## build 'where' clause
    my $where_clause    = undef;
    my @exec_args       = ();
    for ($type) {
        m{\Aall\z}xmsi              && do { $where_clause = undef; last; };
        m{\Arma_request_id\z}xmsi   && do { $where_clause = 'rma_request_id = ?'; push @exec_args, $id; last; };
        croak "Unknown type ($_)";
    }

    my $qry  = qq{SELECT * FROM vw_rma_request_details
                           LEFT JOIN price_purchase on vw_rma_request_details.product_id = price_purchase.product_id
                           LEFT JOIN  currency on price_purchase.wholesale_currency_id = currency.id};
    $qry    .= qq{ WHERE $where_clause} if defined $where_clause;
    $qry    .=  q{ ORDER BY rma_request_id, sku};

    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);

    my $rma_request_details_ref;

    if ($results_as_hash) {
        $rma_request_details_ref = results_hash2($sth, 'rma_request_detail_id');
    }
    else {
        $rma_request_details_ref = results_list($sth);

        ## get image_names if requested
        if ($get_image_names) {
            $_->{image_name} = get_images( { schema => $schema, 'product_id' => $_->{product_id}, live => 1 } )
                foreach ( @$rma_request_details_ref );
        }
    }
    return $rma_request_details_ref;
}

sub list_rma_request_notes :Export(:rma_request) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rma_request_id  = $arg_ref->{rma_request_id};

    my $qry
        = q{SELECT *
            FROM vw_rma_request_notes
            WHERE rma_request_id = ?
            ORDER BY date_time DESC
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($rma_request_id);

    my $rma_request_notes_ref = results_list($sth);
    return $rma_request_notes_ref;
}

sub insert_rma_request_note :Export(:rma_request) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rma_request_id  = $arg_ref->{rma_request_id};
    my $operator_id     = $arg_ref->{operator_id};
    my $note            = defined $arg_ref->{note} ? $arg_ref->{note} : '';
    return if ( length( trim($note) ) == 0 );

    my $sql
        = q{INSERT INTO rma_request_note (rma_request_id, date_time, operator_id, note)
                VALUES (?, default, ?, ?)
        };

    my $sth = $dbh->prepare($sql);
    $sth->execute($rma_request_id, $operator_id, $note);
    return;
}

sub create_rma_request_document :Export(:rma_request) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rma_request_id  = $arg_ref->{rma_request_id};
    my $operator_id     = $arg_ref->{operator_id};

    my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );

    my $rma_request_ref = sprintf('%05d', $rma_request_id);

    my $operator_details_ref = get_operator_details( { dbh => $dbh, operator_id => $operator_id } );

    my $rma_request_details_ref = list_rma_request_details( { dbh => $dbh, type => 'rma_request_id', id => $rma_request_id } );

    my $doc_path = XTracker::PrintFunctions::path_for_print_document({
        document_type => $DOCNAME_RMA_REQUEST{ $rma_request_details_ref->[0]{sales_channel} },
        id => $rma_request_ref,
    });
    my ($printdoc_path, $printdoc_basename) = ($doc_path =~ m|^(.*)/([^/]+)$|);

    my $doc_template    = 'stocktracker/rtv/rma_request_doc.tt';
    my $doc_data_ref;

    # This is the hardcoded logo text in the template
    my $channel_name = uc($rma_request_details_ref->[0]{sales_channel});
    my $channel = $schema->resultset('Public::Channel')->search({ name => $channel_name })->first;
    $doc_data_ref->{address_rtv}            = dc_address($channel);
    $doc_data_ref->{fax_rtv}                = dc_fax();
    $doc_data_ref->{rma_request_details}    = $rma_request_details_ref;
    $doc_data_ref->{operator_details}       = $operator_details_ref;
    $doc_data_ref->{channel_name}           = $channel_name;

    my $doc_html
        = create_html_document({
            basename        => $printdoc_basename,
            path            => $printdoc_path,
            doc_template    => $doc_template,
            doc_data_ref    => $doc_data_ref,
        });

        ## create .pdf file
        my $doc_name
            = convert_html_document({
                basename        => $printdoc_basename,
                path            => $printdoc_path,
                orientation     => 'landscape',
                output_format   => 'pdf',
                font_size       => 10,
            });
        return wantarray ? ($doc_name, $rma_request_details_ref) : $doc_name;
}

sub send_rma_request_email :Export(:rma_request) {
    my ($arg_ref)       = @_;
    my $to              = $arg_ref->{to};
    my $from            = $arg_ref->{from};
    my $reply_to        = $arg_ref->{reply_to};
    my $cc              = $arg_ref->{cc};
    my $subject         = $arg_ref->{subject};
    my $message         = $arg_ref->{message};
    my $attachment_name = $arg_ref->{attachment_name};

    my $msg_croak   = '';
    $msg_croak .= "Invalid 'to' address '$to'\n" unless is_valid_format( { value => $to, format => 'email_address' } );
    $msg_croak .= "Invalid 'from' address '$from'\n" unless is_valid_format( { value => $from, format => 'email_address' } );
    $msg_croak .= "Invalid 'cc' address '$cc'\n" if ( $cc and not is_valid_format( { value => $cc, format => 'email_address' } ) );
    $msg_croak .= "No subject line was entered\n" if is_valid_format( { value => $subject, format => 'empty_or_whitespace' } );
    $msg_croak .= "No message text was entered\n" if is_valid_format( { value => $message, format => 'empty_or_whitespace' } );
    $msg_croak .= "No attachment name was specified\n" if is_valid_format( { value => $attachment_name, format => 'empty_or_whitespace' } );
    croak $msg_croak if $msg_croak;

    my $doc_path = XTracker::PrintFunctions::path_for_print_document({
        %{ XTracker::PrintFunctions::document_details_from_name( $attachment_name ) },
    });

    return send_email(
        $from,
        $reply_to||'',
        $to,
        $subject,
        $message,
        'multipart/mixed',
        {
            type     => 'application/pdf',
            filename => $doc_path,
        },
    );
}

#-------------------------------------------------------------------------------
# RTV Shipment
#-------------------------------------------------------------------------------

sub list_rtv_shipment_statuses :Export(:rtv_shipment) {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};

    my $qry = q{SELECT * FROM rtv_shipment_status ORDER BY status};

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $results_ref = results_list($sth);
    return $results_ref;
}

sub update_rtv_shipment_statuses :Export(:rtv_shipment) {
    my ($arg_ref)                   = @_;
    my $dbh_trans                   = $arg_ref->{dbh};
    my $rtv_shipment_id             = $arg_ref->{rtv_shipment_id};
    my $rtv_shipment_status         = $arg_ref->{rtv_shipment_status};
    my $rtv_shipment_detail_status  = $arg_ref->{rtv_shipment_detail_status};
    my $operator_id                 = $arg_ref->{operator_id};

    update_rtv_status({
        dbh         => $dbh_trans,
        entity      => 'rtv_shipment',
        type        => 'rtv_shipment_id',
        id          => $rtv_shipment_id,
        status_id   => $rtv_shipment_status,
        operator_id => $operator_id,
    });

    update_rtv_status({
        dbh         => $dbh_trans,
        entity      => 'rtv_shipment_detail',
        type        => 'rtv_shipment_id',
        id          => $rtv_shipment_id,
        status_id   => $rtv_shipment_detail_status,
        operator_id => $operator_id,
    });
    return;
}

sub has_rma_number :Export(:rtv_shipment) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rma_request_id  = $arg_ref->{rma_request_id};

    my $qry = q{SELECT rma_number FROM rma_request WHERE id = ?};
    my $sth = $dbh->prepare($qry);
    $sth->execute($rma_request_id);

    my $rma_number;

    $sth->bind_columns( \$rma_number );

    $sth->fetch();
    $sth->finish();

    $rma_number = trim($rma_number);
    return $rma_number ? $rma_number : 0;
}

sub create_rtv_shipment :Export(:rtv_shipment) {
    my ($arg_ref)       = @_;
    my $dbh_trans       = $arg_ref->{dbh};
    my $head_ref        = $arg_ref->{head_ref};
    my $dets_ref        = $arg_ref->{dets_ref};
    my $operator_id     = $arg_ref->{operator_id};

    my $rma_request_id          = $head_ref->{rma_request_id};
    my $channel_id              = $head_ref->{channel_id};
    my @rma_request_detail_ids  = keys %{$dets_ref};
    my @rtv_shipment_detail_ids = ();

    croak "RMA Request $rma_request_id does not have an RMA Number assigned" unless has_rma_number( { dbh => $dbh_trans, rma_request_id => $rma_request_id } );
    croak 'Insufficient data! RTV shipment was * NOT * created' unless scalar @rma_request_detail_ids;

    ## check rma_request_detail statuses
    foreach my $rma_request_detail_id( @rma_request_detail_ids ) {
        my $status_ref = get_rtv_status( { dbh => $dbh_trans, entity => 'rma_request_detail', id => $rma_request_detail_id } );
        if ( $status_ref->{status_id} != $RMA_REQUEST_DETAIL_STATUS__NEW ) {
            croak "rma_request_detail_id $rma_request_detail_id has an incorrect status ($status_ref->{status_id})!  Shipment was NOT created";
        }
    }

    my $designer_rtv_carrier_id = $head_ref->{designer_rtv_carrier_id};
    my $designer_rtv_address_id = $head_ref->{designer_rtv_address_id};
    my $status_id               = $RTV_SHIPMENT_STATUS__NEW;

    my $sql = q{INSERT INTO rtv_shipment (designer_rtv_carrier_id, designer_rtv_address_id, status_id, channel_id) VALUES (?, ?, ?, ?)};
    my $sth = $dbh_trans->prepare($sql);
    $sth->execute($designer_rtv_carrier_id, $designer_rtv_address_id, $status_id, $channel_id);
    my $rtv_shipment_id = last_insert_id($dbh_trans, 'rtv_shipment_id_seq');

    foreach my $rma_request_detail_id( @rma_request_detail_ids ) {
        my $rtv_shipment_detail_id
            = _insert_rtv_shipment_detail_line({
                dbh                     => $dbh_trans,
                rtv_shipment_id         => $rtv_shipment_id,
                rma_request_detail_id   => $rma_request_detail_id,
                status_id               => $RTV_SHIPMENT_DETAIL_STATUS__NEW,
            });

        push @rtv_shipment_detail_ids, $rtv_shipment_detail_id;
    }

    ## Update rtv_shipment and rtv_shipment_detail statuses
    update_rtv_shipment_statuses({
        dbh                         => $dbh_trans,
        rtv_shipment_id             => $rtv_shipment_id,
        rtv_shipment_status         => $RTV_SHIPMENT_STATUS__NEW,
        rtv_shipment_detail_status  => $RTV_SHIPMENT_DETAIL_STATUS__NEW,
        operator_id                 => $operator_id,
    });

    ## Update rma_request_header status
    update_rtv_status({
        dbh         => $dbh_trans,
        entity      => 'rma_request',
        type        => 'rma_request_id',
        id          => $rma_request_id,
        status_id   => $RMA_REQUEST_STATUS__RTV_PROCESSING,
        operator_id => $operator_id,
    });

    ## Update rma_request_detail statuses
    update_rtv_status({
        dbh         => $dbh_trans,
        entity      => 'rma_request_detail',
        type        => 'rma_request_detail_id',
        id          => \@rma_request_detail_ids,
        status_id   => $RMA_REQUEST_DETAIL_STATUS__RTV,
        operator_id => $operator_id,
    });
    return $rtv_shipment_id;
}

sub _insert_rtv_shipment_detail_line {
    my ($arg_ref)               = @_;
    my $dbh_trans               = $arg_ref->{dbh};
    my $rtv_shipment_id         = $arg_ref->{rtv_shipment_id};
    my $rma_request_detail_id   = $arg_ref->{rma_request_detail_id};
    my $status_id               = $arg_ref->{status_id};

    my $sql
        = q{INSERT INTO rtv_shipment_detail (rtv_shipment_id, rma_request_detail_id, quantity, status_id)
                SELECT ? AS rtv_shipment_id, id AS rma_request_detail_id, quantity, ? AS status_id
                FROM rma_request_detail WHERE id = ?
        };
    my $sth = $dbh_trans->prepare($sql);
    $sth->execute($rtv_shipment_id, $status_id, $rma_request_detail_id);

    my $rtv_shipment_detail_id = last_insert_id($dbh_trans, 'rtv_shipment_detail_id_seq');
    return $rtv_shipment_detail_id;
}

sub update_rtv_shipment :Export(:rtv_shipment) {
    my ($arg_ref)       = @_;
    my $dbh_trans       = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};
    my $fields_ref      = $arg_ref->{fields_ref};

    croak "Invalid rtv_shipment_id ($rtv_shipment_id)" if $rtv_shipment_id !~ $FORMAT_REGEXP{id};

    my $table_name      = 'rtv_shipment';

    ## map %{$fields_ref} keys to database field names
    my %db_fieldmap = (
        airway_bill => 'airway_bill',
    );

    my %update_fields = ();
    foreach my $update_parameter_name ( keys %{$fields_ref} ) {
        my $db_field_name = $db_fieldmap{$update_parameter_name};

        if ( exists $fields_ref->{$update_parameter_name} ) {
            $update_fields{$table_name}{$rtv_shipment_id}{$db_field_name} = $fields_ref->{$update_parameter_name};
        }
    }

    ### perform the update
    update_fields({
        dbh             => $dbh_trans,
        update_fields   => \%update_fields,
    });
    return;
}

sub list_rtv_shipments :Export(:rtv_shipment) {
    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $columnsort          = $arg_ref->{columnsort};
    my $params              = $arg_ref->{params};

    my %colname_map = (
        status_id => 'rtv_shipment_status_id',
        map { $_ => $_ } qw{
            rma_request_id
            rma_number
            rtv_shipment_id
            designer_id
            product_id
            season_id
            variant_id
            airway_bill
            channel_id
        }
    );
    my @where_clause = map {
        my $colname = $colname_map{$_} || croak "Unknown type ($_)";
        my $val = $params->{$_};
        # Create the required SQL for the condition
        my $sql = ( grep { $_ && $_ eq 'ARRAY' } ref $val )
                ? sprintf "$colname IN ( %s )", join q{, }, map { q{?} } @$val
                : "$colname = ?";
        # Return a hashref tying the sql to its bind values
        +{ $sql => $val };
    } keys %$params;

    ## build 'order by' clause
    my $asc_desc = $columnsort->{asc_desc} // 'asc';
    my %order_map = (
        rma_request_id       => "rma_request_id $asc_desc, rtv_shipment_id",
        rma_number           => "rma_number $asc_desc, rtv_shipment_id",
        rma_request_date     => "date_request $asc_desc, rma_request_id",
        designer             => "designer $asc_desc, rma_request_id, rtv_shipment_id",
        rtv_shipment_date    => "rtv_shipment_date $asc_desc, rtv_shipment_id",
        rtv_shipment_status  => "rtv_shipment_status $asc_desc, rma_request_id, rtv_shipment_id",
        rtv_shipment_address => "address_line_1 $asc_desc, rma_request_id, rtv_shipment_id",
        rtv_shipment_carrier => "rtv_carrier_name $asc_desc, rma_request_id, rtv_shipment_id",
        airway_bill          => "airway_bill $asc_desc",
        rtv_shipment_id      => "rtv_shipment_id $asc_desc",
        sales_channel        => "sales_channel $asc_desc, rma_request_id, rtv_shipment_id",
        short_address        => "contact_name || address_line_1 || address_line_2 || town_city $asc_desc, rma_request_id, rtv_shipment_id",
    );
    my $sort_clause = $order_map{$columnsort->{order_by}||'rtv_shipment_id'};

    my $qry
        = qq{SELECT
                rma_request_id,
                rma_number,
                channel_id,
                sales_channel,
                date_request,
                txt_date_request,
                designer,
                rtv_shipment_id,
                rtv_shipment_date,
                txt_rtv_shipment_date,
                rtv_shipment_status,
                contact_name,
                address_line_1,
                address_line_2,
                address_line_3,
                town_city,
                region_county,
                postcode_zip,
                country,
                rtv_carrier_name,
                airway_bill
            FROM vw_rtv_shipment_details
        };
    $qry .= q{ WHERE } . join q{ AND }, map { keys %$_ } @where_clause
        if @where_clause;
    $qry .= qq{ GROUP BY rma_request_id, rma_number, channel_id, sales_channel, date_request, txt_date_request, designer,
                rtv_shipment_id, rtv_shipment_date, txt_rtv_shipment_date, rtv_shipment_status,
                contact_name, address_line_1, address_line_2, address_line_3, town_city,
                region_county, postcode_zip, country, rtv_carrier_name, airway_bill
        };
    $qry .= qq{ ORDER BY $sort_clause};

    my $sth = $dbh->prepare($qry);

    my @exec_args = map {
        (grep { $_ && $_ eq 'ARRAY' } ref $_) ? @$_ : $_
    } map { values %$_ } @where_clause;
    $sth->execute(@exec_args);

    my $rtv_shipments_ref = results_list($sth);
    return $rtv_shipments_ref;
}

sub list_rtv_shipment_details :Export(:rtv_shipment) {
    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $type                = defined $arg_ref->{type} ? $arg_ref->{type} : 'all';
    my $id                  = $arg_ref->{id};
    my $sort_order          = defined $arg_ref->{sort_order} ? $arg_ref->{sort_order} : 'rtv_shipment_id';
    my $get_image_names     = defined $arg_ref->{get_image_names} ? $arg_ref->{get_image_names} : 0;
    my $get_detail_results  = defined $arg_ref->{get_detail_results} ? $arg_ref->{get_detail_results} : 0;
    my $schema              = get_schema_using_dbh( $dbh, 'xtracker_schema' );

    ## build 'where' clause
    my $where_clause    = undef;
    my @exec_args       = ();
    for ($type) {
        m{\Aall\z}xmsi                      && do { $where_clause = undef; last; };
        m{\Artv_shipment_id\z}xmsi          && do { $where_clause = 'rtv_shipment_id = ?'; push @exec_args, $id; last; };
        m{\Artv_shipment_detail_id\z}xmsi   && do { $where_clause = 'rtv_shipment_detail_id = ?'; push @exec_args, $id; last; };
        m{\Aseason_id\z}xmsi                && do { $where_clause = 'season_id = ?'; push @exec_args, $id; last; };
        m{\Adesigner_id\z}xmsi              && do { $where_clause = 'designer_id = ?'; push @exec_args, $id; last; };
        croak "Unknown type ($_)";
    }

    ## build 'order by' clause
    my $sort_clause     = undef;
    for ($sort_order) {
        m{\Artv_shipment_id\z}xmsi  && do { $sort_clause = 'rtv_shipment_id, sku'; last; };
        m{\Alocation\z}xmsi         && do { $sort_clause = 'loc_dc, loc_floor DESC, loc_zone DESC, loc_section DESC, loc_shelf, sku'; last; };
        ### Not sure what to do with this. ^^^^
        croak "Invalid sort order ($_)";
    }

    my $qry;

    if ($get_detail_results) {
        $qry = qq{SELECT * FROM vw_rtv_shipment_details_with_results};
    }
    else {
        $qry = qq{SELECT * FROM vw_rtv_shipment_details};
    }

    $qry    .= qq{ WHERE $where_clause} if defined $where_clause;
    $qry    .= qq{ ORDER BY $sort_clause} if defined $sort_clause;

    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);

    my $rtv_shipment_details_ref = results_list($sth);

    ## get image_names if requested
    if ($get_image_names) {
        $_->{image_name} = get_images( { schema => $schema, 'product_id' => $_->{product_id}, live => 1 }  )
            foreach ( @$rtv_shipment_details_ref );
    }
    return $rtv_shipment_details_ref;
}

sub list_rtv_shipment_picklist :Export(:rtv_shipment) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};

    croak "Invalid rtv_shipment_id ($rtv_shipment_id)" if $rtv_shipment_id !~ $FORMAT_REGEXP{id};

    my $qry
        = q{SELECT *
            FROM vw_rtv_shipment_picklist
            WHERE rtv_shipment_id = ?
            ORDER BY loc_dc, loc_floor DESC, loc_zone DESC, loc_section DESC, loc_shelf, sku
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($rtv_shipment_id);

    my $rtv_shipment_picklist_ref = results_list($sth);
    return $rtv_shipment_picklist_ref;
}

sub create_rtv_shipment_picklist :Export(:rtv_shipment) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};

    croak "Invalid rtv_shipment_id ($rtv_shipment_id)" if $rtv_shipment_id !~ $FORMAT_REGEXP{id};

    my $print_time      = get_date_db( { dbh => $dbh, format_string => 'DD-Mon-YYYY HH24:MI' } );

    my $doc_path = XTracker::PrintFunctions::path_for_print_document({
        document_type => 'rtv_ship_picklist',
        id => $rtv_shipment_id,
    });
    my ($printdoc_path, $printdoc_basename) = ($doc_path =~ m|^(.*)/([^/]+)$|);

    my $doc_template    = 'stocktracker/rtv/rtv_ship_picklist.tt';
    my $doc_data_ref;

    my $rtv_shipment_picklist_ref
        = list_rtv_shipment_picklist({
            dbh             => $dbh,
            rtv_shipment_id => $rtv_shipment_id,
        });

    $doc_data_ref->{print_time}             = $print_time;
    $doc_data_ref->{rtv_shipment_picklist}  = $rtv_shipment_picklist_ref;
    $doc_data_ref->{barcode_path} = XTracker::PrintFunctions::path_for_print_document({
        document_type => 'barcode',
        id => "rtv_shipment_$rtv_shipment_id",
        extension => 'png',
    });

    create_barcode("rtv_shipment_$rtv_shipment_id", "RTVS-$rtv_shipment_id", 'small', 1, 1, 40);

    my $doc_html
        = create_html_document({
            basename        => $printdoc_basename,
            path            => $printdoc_path,
            doc_template    => $doc_template,
            doc_data_ref    => $doc_data_ref,
        });

    ## create .pdf file
    my $doc_name
        = convert_html_document({
            basename        => $printdoc_basename,
            path            => $printdoc_path,
            orientation     => 'portrait',
            output_format   => 'pdf',
        });
    $doc_name .= '.pdf';
    return wantarray ? ($doc_name, $rtv_shipment_picklist_ref) : $doc_name;
}

sub list_rtv_carriers :Export(:rtv_shipment) {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};

    my $qry = q{SELECT id, name FROM rtv_carrier};
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $rtv_carriers_ref = results_list($sth);
    return $rtv_carriers_ref;
}

sub list_designer_carriers :Export(:rtv_shipment) {
    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $designer_id         = $arg_ref->{designer_id};
    my $include_do_not_use  = defined $arg_ref->{include_do_not_use} ? $arg_ref->{include_do_not_use} : 0;

    my $where_clause = $include_do_not_use ? 'WHERE designer_id = ?' : 'WHERE designer_id = ? AND do_not_use IS NOT TRUE';

    my $qry = qq{SELECT * FROM vw_designer_rtv_carrier $where_clause ORDER BY rtv_carrier_name, account_ref};
    my $sth = $dbh->prepare($qry);
    $sth->execute($designer_id);

    my $designer_carriers_ref = results_list($sth);
    return $designer_carriers_ref;
}

sub insert_designer_carrier :Export(:rtv_shipment) {
    my ($arg_ref)       = @_;
    my $dbh_trans       = $arg_ref->{dbh};
    my $designer_id     = $arg_ref->{designer_id};
    my $name            = $arg_ref->{name};
    my $account_ref     = $arg_ref->{account_ref};

    $name           = trim($name);
    $account_ref    = trim($account_ref);

    croak "Invalid carrier name '$name'" if $name !~ m{\A\w+[\w\s]*\w+\z}xms;

    $name = 'Vendor Collection' if ( lc($name) eq 'vendor collection' );

    if ( lc($name) ne 'vendor collection' ) {
        croak "Invalid carrier account_ref '$account_ref'" if $account_ref !~ m{\A\w+[\w\s]*\w+\z}xms;
    }

    ## check if carrier exists, and if it is linked to the specified designer
    my ($rtv_carrier_id, $is_linked_to_specified_designer, $designer_rtv_carrier_id)
        = designer_rtv_carrier_exists({
                dbh             => $dbh_trans,
                designer_id     => $designer_id,
                carrier_name    => $name,
                account_ref     => $account_ref,
        });

    ## ...if the carrier doesn't exist, insert it
    if ( not $rtv_carrier_id ) {
        my $sql_insert_carrier = q{INSERT INTO rtv_carrier (name) VALUES (?)};
        my $sth_insert_carrier = $dbh_trans->prepare($sql_insert_carrier);
        $sth_insert_carrier->execute($name);

        $rtv_carrier_id = last_insert_id($dbh_trans, 'rtv_carrier_id_seq');
    }

    ## ...if it isn't linked to the specified designer, link it!
    if ( not $is_linked_to_specified_designer ) {
        my $sql_insert_link
            = q{INSERT INTO designer_rtv_carrier (designer_id, rtv_carrier_id, account_ref)
                    VALUES (?, ?, ?)
            };
        my $sth_insert_link = $dbh_trans->prepare($sql_insert_link);
        $sth_insert_link->execute($designer_id, $rtv_carrier_id, $account_ref);

        $designer_rtv_carrier_id = last_insert_id($dbh_trans, 'designer_rtv_carrier_id_seq');
    }
    return $designer_rtv_carrier_id;
}

sub designer_rtv_carrier_exists :Export(:rtv_shipment) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $designer_id     = $arg_ref->{designer_id};
    my $carrier_name    = $arg_ref->{carrier_name};
    my $account_ref     = $arg_ref->{account_ref};

    my $qry = q{SELECT designer_id, rtv_carrier_id, designer_rtv_carrier_id, account_ref FROM vw_designer_rtv_carrier WHERE rtv_carrier_name = ?};
    my $sth = $dbh->prepare($qry);
    $sth->execute($carrier_name);

    my ($linked_designer_id, $rtv_carrier_id, $designer_rtv_carrier_id, $linked_account_ref);
    $sth->bind_columns( \($linked_designer_id, $rtv_carrier_id, $designer_rtv_carrier_id, $linked_account_ref) );

    my $is_linked_to_specified_designer = 0;

    while ( $sth->fetch() ) {
        $is_linked_to_specified_designer = 1 if ( $linked_designer_id == $designer_id && lc($linked_account_ref) eq lc($account_ref) );
    }
    return wantarray ? ($rtv_carrier_id, $is_linked_to_specified_designer, $designer_rtv_carrier_id) : $rtv_carrier_id;
}

sub list_designer_addresses :Export(:rtv_shipment) {
    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $designer_id         = $arg_ref->{designer_id};
    my $list_format         = $arg_ref->{list_format};
    my $include_do_not_use  = defined $arg_ref->{include_do_not_use} ? $arg_ref->{include_do_not_use} : 0;

    my $where_clause = $include_do_not_use ? 'WHERE designer_id = ?' : 'WHERE designer_id = ? AND do_not_use IS NOT TRUE';

    my $qry = qq{SELECT * FROM vw_designer_rtv_address $where_clause ORDER BY contact_name, address_line_1};
    my $sth = $dbh->prepare($qry);
    $sth->execute($designer_id);
    my $designer_addresses_ref = results_list($sth);

    if ( lc($list_format) eq 'select_list' ) {
        my @designer_addresses  = ();

        foreach my $designer_address_ref ( @{$designer_addresses_ref} ) {
            my @address_elements = ();

            foreach ( qw(contact_name address_line_1 address_line_2 address_line_3 town_city region_county postcode_zip country) ) {
                push @address_elements, $designer_address_ref->{$_} if $designer_address_ref->{$_} !~ m{\A\s*\z}xms;
            }

            my $address_string  = join(', ', @address_elements);
            push @designer_addresses, { designer_rtv_address_id => $designer_address_ref->{designer_rtv_address_id}, address => $address_string };
        }

        $designer_addresses_ref = \@designer_addresses;
    }
    return $designer_addresses_ref;
}

sub insert_designer_address :Export(:rtv_shipment) {
    my ($arg_ref)       = @_;
    my $dbh_trans       = $arg_ref->{dbh};
    my $designer_id     = $arg_ref->{designer_id};
    my $contact_name    = $arg_ref->{contact_name};
    my $address_ref     = $arg_ref->{address_ref};

    my %address = %{$address_ref};

    ## trim whitespace
    foreach my $address_key ( keys %address ) {
        $address{$address_key} = trim( $address{$address_key} );
    }
    $contact_name = trim($contact_name);

    croak ('Invalid rtv_address supplied') unless ( $address{address_line_1} && $address{town_city} );

    ## check if address exists, and if it is linked to the specified designer...
    my ($rtv_address_id, $is_linked_to_specified_designer, $designer_rtv_address_id)
        = designer_rtv_address_exists({
                dbh             => $dbh_trans,
                designer_id     => $designer_id,
                contact_name    => $contact_name,
                address_ref     => \%address,
        });

    ## ...if the address doesn't exist, insert it
    if ( not $rtv_address_id ) {
        my $sql_insert_address
            = q{INSERT INTO rtv_address (address_line_1, address_line_2, address_line_3, town_city, region_county, postcode_zip, country)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
            };
        my $sth_insert_address = $dbh_trans->prepare($sql_insert_address);

        $sth_insert_address->execute(
            encode_db($address{address_line_1}),
            encode_db($address{address_line_2}),
            encode_db($address{address_line_3}),
            encode_db($address{town_city}),
            encode_db($address{region_county}),
            encode_db($address{postcode_zip}),
            encode_db($address{country}),
        );

        $rtv_address_id = last_insert_id($dbh_trans, 'rtv_address_id_seq');
    }

    ## ...if it isn't linked to the specified designer, link it!
    if ( not $is_linked_to_specified_designer ) {
        my $sql_link    = q{INSERT INTO designer_rtv_address (designer_id, rtv_address_id, contact_name) VALUES (?, ?, ?)};
        my $sth_link    = $dbh_trans->prepare($sql_link);

        $sth_link->execute($designer_id, $rtv_address_id, encode_db($contact_name));

        $designer_rtv_address_id = last_insert_id($dbh_trans, 'designer_rtv_address_id_seq');
    }
    return $designer_rtv_address_id;
}

sub designer_rtv_address_exists :Export(:rtv_shipment) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $designer_id     = $arg_ref->{designer_id};
    my $contact_name    = $arg_ref->{contact_name};
    my $address_ref     = $arg_ref->{address_ref};

    my $address_hash    = generate_digest( { data_ref => $address_ref } );

    my $qry = q{SELECT designer_id, rtv_address_id, designer_rtv_address_id, contact_name FROM vw_designer_rtv_address WHERE address_hash = ?};
    my $sth = $dbh->prepare($qry);
    $sth->execute($address_hash);

    my ($linked_designer_id, $rtv_address_id, $designer_rtv_address_id, $linked_contact_name);
    $sth->bind_columns( \($linked_designer_id, $rtv_address_id, $designer_rtv_address_id, $linked_contact_name) );

    my $is_linked_to_specified_designer = 0;

    while ( $sth->fetch() ) {
        $is_linked_to_specified_designer = 1 if ( $linked_designer_id == $designer_id && lc($linked_contact_name) eq lc($contact_name) );
    }
    return wantarray ? ($rtv_address_id, $is_linked_to_specified_designer, $designer_rtv_address_id) : $rtv_address_id;
}

sub generate_digest :Export(:rtv_shipment) {
    my ($arg_ref)   = @_;
    my $data_ref    = $arg_ref->{data_ref};

    my $md5 = Digest::MD5->new();

    foreach ( sort keys %{$data_ref} ) {
        my $value = trim( lc($data_ref->{$_} ) );
        $md5->add($value);
    }

    my $message_digest = $md5->hexdigest();
    return $message_digest;
}

#-------------------------------------------------------------------------------
# RTV Shipment Pick
#-------------------------------------------------------------------------------

sub list_rtv_shipment_validate_pick :Export(:rtv_shipment_pick) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};

    my $qry
        = q{SELECT *
            FROM vw_rtv_shipment_validate_pick
            WHERE rtv_shipment_id = ?
            ORDER BY loc_dc, loc_floor DESC, loc_zone DESC, loc_section DESC, loc_shelf, sku
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($rtv_shipment_id);

    my $rtv_shipment_validate_pick_ref = results_list($sth);
    return $rtv_shipment_validate_pick_ref;
}

sub insert_rtv_shipment_pick :Export(:rtv_shipment_pick) {
    my ($arg_ref)       = @_;
    my $dbh_trans       = $arg_ref->{dbh};
    my $operator_id     = $arg_ref->{operator_id};

    my $rtv_shipment_id;
    my $location;
    my $sku;
    my $item_pick_validation_ref;

    # if all the params already passed in .. no need to call get_rtv_shipment_item_pick_validation .. ie dont re-query the view
    if (defined($arg_ref->{item_ref})) {
       $rtv_shipment_id          = $arg_ref->{item_ref}->{rtv_shipment_id};
       $location                 = $arg_ref->{item_ref}->{location};
       $sku                      = $arg_ref->{item_ref}->{sku};
       $item_pick_validation_ref = $arg_ref->{item_ref};
    } else {
       $rtv_shipment_id = $arg_ref->{rtv_shipment_id};
       $location        = $arg_ref->{location};
       $sku             = $arg_ref->{sku};

       ## validate item pick
       $item_pick_validation_ref
           = get_rtv_shipment_item_pick_validation({
                   dbh             => $dbh_trans,
                   rtv_shipment_id => $rtv_shipment_id,
                   location        => $location,
                   sku             => $sku,
           });
    }

    {
        use Data::Dump qw(pp);
        xt_logger->debug(pp $item_pick_validation_ref);
    }

    croak 'Invalid pick - please check the location/SKU' unless defined $item_pick_validation_ref->{remaining_to_pick};

    if ( $item_pick_validation_ref->{remaining_to_pick} < 0 ) {
    ### I kinda hope we never get here!
        croak 'Invalid pick - this item has been over-picked';
    }

    if ( $item_pick_validation_ref->{remaining_to_pick} > 0 ) {
        my $sql_insert
            = q{INSERT INTO rtv_shipment_pick (operator_id, rtv_shipment_id, location, sku, date_time)
                VALUES (?, ?, ?, ?, default)
        };

        my $sth_insert = $dbh_trans->prepare($sql_insert);
        $sth_insert->execute($operator_id, $rtv_shipment_id, $location, $sku);
    }
    return;
}

sub get_rtv_shipment_item_pick_validation :Export(:rtv_shipment_pick) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};
    my $location        = $arg_ref->{location};
    my $sku             = $arg_ref->{sku};

    my $qry
        = q{SELECT
                sum_picklist_quantity,
                picked_quantity,
                remaining_to_pick
            FROM vw_rtv_shipment_validate_pick
            WHERE rtv_shipment_id = ?
            AND location = ?
            AND sku = ?
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($rtv_shipment_id, $location, $sku);

    my $results_ref = $sth->fetchrow_hashref();

    $sth->finish();

    croak 'Item pick validation error - quantity mismatch' unless $results_ref->{sum_picklist_quantity} == $results_ref->{picked_quantity} + $results_ref->{remaining_to_pick};
    return $results_ref;
}

sub get_rtv_shipment_pick_validation :Export(:rtv_shipment_pick) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};

    my $qry
        = q{SELECT
                sum(sum_picklist_quantity) AS total_picklist_quantity,
                sum(picked_quantity) AS sum_picked_quantity,
                sum(remaining_to_pick) AS sum_remaining_to_pick
            FROM vw_rtv_shipment_validate_pick
            WHERE rtv_shipment_id = ?
            GROUP BY rtv_shipment_id
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($rtv_shipment_id);

    my ($total_picklist_quantity, $sum_picked_quantity, $sum_remaining_to_pick);

    $sth->bind_columns(\($total_picklist_quantity, $sum_picked_quantity, $sum_remaining_to_pick));

    $sth->fetch();
    $sth->finish();

    my $results_ref = {
        total       => $total_picklist_quantity,
        picked      => $sum_picked_quantity,
        remaining   => $sum_remaining_to_pick,
    };

    croak 'Shipment pick validation error - quantity mismatch' unless $results_ref->{total} == $results_ref->{picked} + $results_ref->{remaining};
    return $results_ref;
}

sub commit_rtv_shipment_pick :Export(:rtv_shipment_pick) {
    my ($arg_ref)       = @_;
    my $dbh_trans       = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};
    my $operator_id     = $arg_ref->{operator_id};

    ## validate pick - ensure there are no items remaining to pick, or overpicked items, on the specified shipment
    my $shipment_pick_validation_ref
        = get_rtv_shipment_pick_validation({
                dbh             => $dbh_trans,
                rtv_shipment_id => $rtv_shipment_id,
        });

    if ( $shipment_pick_validation_ref->{remaining} > 0 ) {
        croak 'Unable to commit pick - this shipment has unpicked items';
    }
    elsif ( $shipment_pick_validation_ref->{remaining} < 0 ) {
        croak 'Unable to commit pick - this shipment has overpicked items';
    }

    ## move items out of stock
    my $rtv_shipment_detail_ids_ref = get_detail_ids( { dbh => $dbh_trans, type => 'rtv_shipment', id => $rtv_shipment_id } );

    foreach my $rtv_shipment_detail_id ( @{$rtv_shipment_detail_ids_ref} ) {
        move_rtv_stock_out({
            dbh             => $dbh_trans,
            rtv_stock_type  => 'RTV Process',
            type            => 'rtv_shipment_detail_id',
            id              => $rtv_shipment_detail_id,
        });
    }

    ## Update rtv_shipment and rtv_shipment_detail statuses
    update_rtv_shipment_statuses({
        dbh                         => $dbh_trans,
        rtv_shipment_id             => $rtv_shipment_id,
        rtv_shipment_status         => $RTV_SHIPMENT_STATUS__PICKED,
        rtv_shipment_detail_status  => $RTV_SHIPMENT_DETAIL_STATUS__PICKED,
        operator_id                 => $operator_id,
    });

    ## insert log_rtv_stock records
    log_rtv_shipment_pick({
        dbh             => $dbh_trans,
        rtv_shipment_id => $rtv_shipment_id,
        operator_id     => $operator_id,
    });
    return;
}

sub cancel_rtv_shipment_pick :Export(:rtv_shipment_pick) {
    my ($arg_ref)       = @_;
    my $dbh_trans       = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};
    my $operator_id     = $arg_ref->{operator_id};

    ## update rtv_shipment_pick records - set cancelled timestamp
    my $sql_update  = q{UPDATE rtv_shipment_pick SET cancelled = LOCALTIMESTAMP WHERE rtv_shipment_id = ? AND operator_id = ?};

    my $sth_update  = $dbh_trans->prepare($sql_update);
    $sth_update->execute($rtv_shipment_id, $operator_id);

    ## update rtv_shipment and rtv_shipment_detail statuses as necessary
    my $status_ref = get_rtv_status( { dbh => $dbh_trans, entity => 'rtv_shipment', id => $rtv_shipment_id } );

    if ( $status_ref->{status_id} == $RTV_SHIPMENT_STATUS__PICKING ) {
        update_rtv_shipment_statuses({
            dbh                         => $dbh_trans,
            rtv_shipment_id             => $rtv_shipment_id,
            rtv_shipment_status         => $RTV_SHIPMENT_STATUS__NEW,
            rtv_shipment_detail_status  => $RTV_SHIPMENT_DETAIL_STATUS__NEW,
            operator_id                 => $operator_id,
        });
    }
    return;
}

#-------------------------------------------------------------------------------
# RTV Shipment Pack
#-------------------------------------------------------------------------------

sub list_rtv_shipment_validate_pack :Export(:rtv_shipment_pack) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};

    my $qry
        = q{SELECT *
            FROM vw_rtv_shipment_validate_pack
            WHERE rtv_shipment_id = ?
            ORDER BY sku
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($rtv_shipment_id);

    my $rtv_shipment_validate_pack_ref = results_list($sth);
    return $rtv_shipment_validate_pack_ref;
}

sub insert_rtv_shipment_pack :Export(:rtv_shipment_pack) {
    my ($arg_ref)       = @_;
    my $dbh_trans       = $arg_ref->{dbh};
    my $operator_id     = $arg_ref->{operator_id};

    my $rtv_shipment_id;
    my $sku;
    my $item_pack_validation_ref;

    # if all the params already passed in .. no need to call get_rtv_shipment_item_pack_validation .. ie dont re-query the view
    if (defined($arg_ref->{item_ref})) {
       $rtv_shipment_id          = $arg_ref->{item_ref}->{rtv_shipment_id};
       $sku                      = $arg_ref->{item_ref}->{sku};
       $item_pack_validation_ref = $arg_ref->{item_ref};
    } else {
       $rtv_shipment_id = $arg_ref->{rtv_shipment_id};
       $sku             = $arg_ref->{sku};

       ## validate item pick
       $item_pack_validation_ref
           = get_rtv_shipment_item_pack_validation({
                   dbh             => $dbh_trans,
                   rtv_shipment_id => $rtv_shipment_id,
                   sku             => $sku,
           });
    }

    croak 'Invalid pack - please check the SKU' unless defined $item_pack_validation_ref->{remaining_to_pack};

    if ( $item_pack_validation_ref->{remaining_to_pack} == 0 ) {
        croak 'Invalid pack - this item has been fully packed';
    }
    elsif ( $item_pack_validation_ref->{remaining_to_pack} < 0 ) {
    ### I definitely hope we never get here!!
        croak 'Invalid pack - this item has been over-packed';
    }

    my $sql_insert
        = q{INSERT INTO rtv_shipment_pack (operator_id, rtv_shipment_id, sku, date_time)
                VALUES (?, ?, ?, default)
        };

    my $sth_insert = $dbh_trans->prepare($sql_insert);
    $sth_insert->execute($operator_id, $rtv_shipment_id, $sku);
    return;
}

sub get_rtv_shipment_item_pack_validation :Export(:rtv_shipment_pack) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};
    my $sku             = $arg_ref->{sku};

    my $qry
        = q{SELECT
                sum_packlist_quantity,
                packed_quantity,
                remaining_to_pack
            FROM vw_rtv_shipment_validate_pack
            WHERE rtv_shipment_id = ?
            AND sku = ?
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($rtv_shipment_id, $sku);

    my $results_ref = $sth->fetchrow_hashref();

    $sth->finish();

    croak 'Item pack validation error - quantity mismatch' if $results_ref->{sum_packlist_quantity} != $results_ref->{packed_quantity} + $results_ref->{remaining_to_pack};
    return $results_ref;
}

sub get_rtv_shipment_pack_validation :Export(:rtv_shipment_pack) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};

    my $qry
        = q{SELECT
                sum(sum_packlist_quantity) AS total_packlist_quantity,
                sum(packed_quantity) AS sum_packed_quantity,
                sum(remaining_to_pack) AS sum_remaining_to_pack
            FROM vw_rtv_shipment_validate_pack
            WHERE rtv_shipment_id = ?
            GROUP BY rtv_shipment_id
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($rtv_shipment_id);

    my ($total_packlist_quantity, $sum_packed_quantity, $sum_remaining_to_pack);

    $sth->bind_columns(\($total_packlist_quantity, $sum_packed_quantity, $sum_remaining_to_pack));

    $sth->fetch();
    $sth->finish();

    my $results_ref = {
        total       => $total_packlist_quantity,
        packed      => $sum_packed_quantity,
        remaining   => $sum_remaining_to_pack,
    };

    croak 'Shipment pack validation error - quantity mismatch' if $results_ref->{total} != $results_ref->{packed} + $results_ref->{remaining};
    return $results_ref;
}

sub commit_rtv_shipment_pack :Export(:rtv_shipment_pack) {
    my ($arg_ref)       = @_;
    my $dbh_trans       = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};
    my $operator_id     = $arg_ref->{operator_id};

    ## validate pack - ensure there are no items remaining to pack, or overpacked items, on the specified shipment
    my $shipment_pack_validation_ref
        = get_rtv_shipment_pack_validation({
                dbh             => $dbh_trans,
                rtv_shipment_id => $rtv_shipment_id,
        });

    if ( $shipment_pack_validation_ref->{remaining} > 0 ) {
        croak 'Unable to commit pack - this shipment has unpacked items';
    }
    elsif ( $shipment_pack_validation_ref->{remaining} < 0 ) {
        croak 'Unable to commit pack - this shipment has overpacked items';
    }

    ## Update rtv_shipment and rtv_shipment_detail statuses
    update_rtv_shipment_statuses({
        dbh                         => $dbh_trans,
        rtv_shipment_id             => $rtv_shipment_id,
        rtv_shipment_status         => $RTV_SHIPMENT_STATUS__AWAITING_DISPATCH,
        rtv_shipment_detail_status  => $RTV_SHIPMENT_DETAIL_STATUS__AWAITING_DISPATCH,
        operator_id                 => $operator_id,
    });
    return;
}

sub cancel_rtv_shipment_pack :Export(:rtv_shipment_pack) {
    my ($arg_ref)       = @_;
    my $dbh_trans       = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};
    my $operator_id     = $arg_ref->{operator_id};

    ## update rtv_shipment_pack records - set cancelled timestamp
    my $sql_update  = q{UPDATE rtv_shipment_pack SET cancelled = LOCALTIMESTAMP WHERE rtv_shipment_id = ? AND operator_id = ?};

    my $sth_update  = $dbh_trans->prepare($sql_update);
    $sth_update->execute($rtv_shipment_id, $operator_id);

    ## update rtv_shipment and rtv_shipment_detail statuses as necessary
    my $status_ref = get_rtv_status( { dbh => $dbh_trans, entity => 'rtv_shipment', id => $rtv_shipment_id } );

    if ( $status_ref->{status_id} == $RTV_SHIPMENT_STATUS__PACKING ) {
        update_rtv_shipment_statuses({
            dbh                         => $dbh_trans,
            rtv_shipment_id             => $rtv_shipment_id,
            rtv_shipment_status         => $RTV_SHIPMENT_STATUS__PICKED,
            rtv_shipment_detail_status  => $RTV_SHIPMENT_DETAIL_STATUS__PICKED,
            operator_id                 => $operator_id,
        });
    }
    return;
}

sub send_rtv_shipping_email :Export(:rtv_shipment_pack) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};

    croak "Invalid rtv_shipment_id ($rtv_shipment_id)" if $rtv_shipment_id !~ $FORMAT_REGEXP{id};

    my $rtv_shipment_details_ref
        = list_rtv_shipment_details( { dbh => $dbh, type => 'rtv_shipment_id', id => $rtv_shipment_id } );

    my $operator_details_ref
        = get_operator_details( { dbh => $dbh, operator_id => $rtv_shipment_details_ref->[0]{operator_id} } );

    my $product_shipping_attributes_ref
        = get_product_shipping_attributes( { dbh => $dbh, rtv_shipment_id => $rtv_shipment_id } );

    my $doc_template    = 'stocktracker/rtv/rtv_shipping_email.tt';
    my $tt_data_ref     = ();

    $tt_data_ref->{rtv_shipment_details}    = $rtv_shipment_details_ref;
    $tt_data_ref->{operator_details}        = $operator_details_ref;
    $tt_data_ref->{shipping_attributes}     = $product_shipping_attributes_ref;

    my $subject     = "RTV Shipment $rtv_shipment_details_ref->[0]{rtv_shipment_id}, ";
    $subject       .= "Carrier: $rtv_shipment_details_ref->[0]{rtv_carrier_name}";
    $subject       .= " ($rtv_shipment_details_ref->[0]{carrier_account_ref})" if $rtv_shipment_details_ref->[0]{carrier_account_ref};

    my $message     = '';
    my $template    = XTracker::XTemplate->template();
    $template->process( $doc_template, { template_type => 'email', %$tt_data_ref }, \$message );

    my $to          = $operator_details_ref->{email_address};
    my $cc          = '';
    my $from        = 'xtracker@net-a-porter.com';
    my $reply_to    = $operator_details_ref->{email_address};

    my $msg_croak   = '';
    $msg_croak .= "Invalid 'to' address '$to'\n" unless is_valid_format( { value => $to, format => 'email_address' } );
    $msg_croak .= "Invalid 'cc' address '$cc'\n" if ( $cc and not is_valid_format( { value => $cc, format => 'email_address' } ) );
    $msg_croak .= "Invalid 'from' address '$from'\n" unless is_valid_format( { value => $from, format => 'email_address' } );
    $msg_croak .= "No subject line was entered\n" if is_valid_format( { value => $subject, format => 'empty_or_whitespace' } );
    $msg_croak .= "No message text was entered\n" if is_valid_format( { value => $message, format => 'empty_or_whitespace' } );
    croak $msg_croak if $msg_croak;

    send_email(
        $from,
        $from,
        $to,
        $subject,
        $message,
        'html',
    );

    return;
}

sub get_product_shipping_attributes :Export(:rtv_shipment_pack) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};

    croak "Invalid rtv_shipment_id ($rtv_shipment_id)" if $rtv_shipment_id !~ $FORMAT_REGEXP{id};

    my $qry
        = q{SELECT DISTINCT
                rsd.rtv_shipment_id,
                v.product_id,
                hc.hs_code,
                sa.scientific_term,
                sa.packing_note,
                sa.weight,
                sa.fabric_content,
                sa.fish_wildlife,
                rsd.quantity,
                c.country
            FROM rtv_shipment_detail rsd
            INNER JOIN rma_request_detail rrd
                ON (rsd.rma_request_detail_id = rrd.id)
            INNER JOIN variant v
                ON (rrd.variant_id = v.id)
            INNER JOIN product p
                ON (v.product_id = p.id)
            INNER JOIN hs_code hc
                ON (p.hs_code_id = hc.id)
            INNER JOIN shipping_attribute sa
                ON (sa.product_id = p.id)
            LEFT JOIN country c
                ON (sa.country_id = c.id)
            WHERE rsd.rtv_shipment_id = ?
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($rtv_shipment_id);

    my $product_shipping_attributes_ref = results_hash2($sth, 'product_id');
    return $product_shipping_attributes_ref;
}

sub list_rtv_inspection_picklist :Export(:rtv_inspection) {
    my ($arg_ref)                       = @_;
    my $dbh                             = $arg_ref->{dbh};
    my $rtv_inspection_pick_request_id  = $arg_ref->{rtv_inspection_pick_request_id};

    # An improvement over vw_rtv_inspection_pick_request_details (+ the WHERE
    # and ORDER BY)
    my $qry = <<EOQ
SELECT ripr.id AS rtv_inspection_pick_request_id,
    ripr.date_time,
    to_char(ripr.date_time, 'DD-Mon-YYYY HH24:MI'::text) AS txt_date_time,
    riprd.id AS rtv_inspection_pick_request_item_id,
    riprd.rtv_quantity_id,
    ripr.status_id,
    riprs.status,
    v.product_id,
    rq.origin,
    v.product_id::text || '-' || sku_padding(v.size_id)::text AS sku,
    d.designer,
    pa.name,
    col.colour,
    dsz.size AS designer_size,
    rq.variant_id,
    di.delivery_id,
    rq.delivery_item_id,
    rq.quantity,
    ft.fault_type,
    rq.fault_description,
    l.location,
    -- These need to be quadruple-escaped because PG requires double
    -- backslashes in an E'' string for special characters, and the backslashes
    -- need to be escaped again in perl-space because we're in a heredoc
    substring(l.location, E'\\\\A(\\\\d{2})\\\\d[a-zA-Z]-?\\\\d{3,4}[a-zA-Z]\\\\Z') AS loc_dc,
    substring(l.location, E'\\\\A\\\\d{2}(\\\\d)[a-zA-Z]-?\\\\d{3,4}[a-zA-Z]\\\\Z') AS loc_floor,
    substring(l.location, E'\\\\A\\\\d{2}\\\\d([a-zA-Z])-?\\\\d{3,4}[a-zA-Z]\\\\Z') AS loc_zone,
    substring(l.location, E'\\\\A\\\\d{2}\\\\d[a-zA-Z]-?(\\\\d{3,4})[a-zA-Z]\\\\Z') AS loc_section,
    substring(l.location, E'\\\\A\\\\d{2}\\\\d[a-zA-Z]-?\\\\d{3,4}([a-zA-Z])\\\\Z') AS loc_shelf,
    rq.status_id AS quantity_status_id
FROM rtv_inspection_pick_request ripr
JOIN rtv_inspection_pick_request_status riprs ON ripr.status_id = riprs.id
JOIN rtv_inspection_pick_request_detail riprd ON riprd.rtv_inspection_pick_request_id = ripr.id
JOIN rtv_quantity rq ON riprd.rtv_quantity_id = rq.id
JOIN location l ON rq.location_id = l.id
JOIN variant v ON rq.variant_id = v.id
JOIN product p ON v.product_id = p.id
JOIN product_channel pc ON p.id = pc.product_id AND rq.channel_id = pc.channel_id
JOIN product_attribute pa ON p.id = pa.product_id
JOIN designer d ON p.designer_id = d.id
JOIN colour col ON p.colour_id = col.id
JOIN item_fault_type ft ON rq.fault_type_id = ft.id
LEFT JOIN size dsz ON v.designer_size_id = dsz.id
LEFT JOIN delivery_item di ON rq.delivery_item_id = di.id
WHERE ripr.id = ?
ORDER BY loc_dc,
    loc_floor,
    loc_zone,
    loc_section,
    loc_shelf,
    sku
EOQ
;

    my $sth = $dbh->prepare($qry);
    $sth->execute($rtv_inspection_pick_request_id);

    my $rtv_inspection_picklist_ref = results_list($sth);
    return $rtv_inspection_picklist_ref;
}

sub create_rtv_inspection_picklist :Export(:rtv_inspection) {
    my ($arg_ref)                       = @_;
    my $dbh                             = $arg_ref->{dbh};
    my $rtv_inspection_pick_request_id  = $arg_ref->{rtv_inspection_pick_request_id};

    my $print_time      = get_date_db( { dbh => $dbh, format_string => 'DD-Mon-YYYY HH24:MI' } );

    my $doc_path = XTracker::PrintFunctions::path_for_print_document({
        document_type => 'rtv_inspect_picklist',
        id => $rtv_inspection_pick_request_id,
    });
    my ($printdoc_path, $printdoc_basename) = ($doc_path =~ m|^(.*)/([^/]+)$|);

    my $doc_template    = 'stocktracker/rtv/rtv_inspection_picklist.tt';
    my $doc_data_ref;

    my $rtv_inspection_picklist_ref
        = list_rtv_inspection_picklist({
            dbh                             => $dbh,
            rtv_inspection_pick_request_id  => $rtv_inspection_pick_request_id,
        });

    $doc_data_ref->{print_time}                 = $print_time;
    $doc_data_ref->{rtv_inspection_picklist}    = $rtv_inspection_picklist_ref;
    $doc_data_ref->{barcode_path} = XTracker::PrintFunctions::path_for_print_document({
        document_type => 'barcode',
        id => "rtv_inspection_$rtv_inspection_pick_request_id",
        extension => 'png',
    });

    create_barcode("rtv_inspection_$rtv_inspection_pick_request_id", "RTVI-$rtv_inspection_pick_request_id", 'small', 1, 1, 40);

    my $doc_html
        = create_html_document({
            basename        => $printdoc_basename,
            path            => $printdoc_path,
            doc_template    => $doc_template,
            doc_data_ref    => $doc_data_ref,
        });

    ## create .pdf file
    my $doc_name
        = convert_html_document({
            basename        => $printdoc_basename,
            path            => $printdoc_path,
            orientation     => 'portrait',
            output_format   => 'pdf',
        });
    $doc_name .= '.pdf';
    return wantarray ? ($doc_name, $rtv_inspection_picklist_ref) : $doc_name;
}

sub create_rtv_inspection_pick_request :Export(:rtv_inspection) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $products_ref    = $arg_ref->{products_ref};
    my $operator_id     = $arg_ref->{operator_id};

    croak 'No products were specified' unless scalar @{$products_ref};

    foreach my $product_ref ( @{$products_ref} ) {
        croak "Invalid product_id ($_)" if $product_ref->{product_id} !~ $FORMAT_REGEXP{id};
    }

    ## insert header record
    my $sql_header
        = q{INSERT INTO rtv_inspection_pick_request (date_time, status_id, operator_id)
                VALUES (default, ?, ?)
        };
    my $sth_header  = $dbh->prepare($sql_header);
    $sth_header->execute($RTV_INSPECTION_PICK_REQUEST_STATUS__NEW, $operator_id);

    my $rtv_inspection_pick_request_id = last_insert_id($dbh, 'rtv_inspection_pick_request_id_seq');

    # location only in the join because it was an inner join in
    # the original comically large view definition, so
    # plausibly, if accidentally, it might constrain the
    # results in a desired way to those with locations
    # -- it should have a negligible effect on query timing
    my $qry_select_details
        = qq{SELECT DISTINCT rq.id AS rtv_quantity_id
               FROM rtv_quantity rq
               JOIN variant v
                 ON rq.variant_id = v.id
                AND rq.status_id = $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS
                AND v.product_id = ?
               JOIN delivery_item di
                 ON rq.delivery_item_id = di.id
                AND di.delivery_id = ?
               JOIN location l
                 ON rq.location_id = l.id
              WHERE NOT EXISTS ( SELECT NULL
                                   FROM rtv_inspection_pick_request_detail riptd
                                  WHERE riptd.rtv_quantity_id = rq.id
                               )
        };
    my $sth_select_details = $dbh->prepare($qry_select_details);

    my @rtv_quantity_ids    = ();

    foreach my $product_ref ( @{$products_ref} ) {
        my $product_id  = $product_ref->{product_id};
        my $delivery_id = $product_ref->{delivery_id};

        $sth_select_details->execute($product_id, $delivery_id);

        my $rtv_quantity_id;
        $sth_select_details->bind_columns(\$rtv_quantity_id);

        while ( $sth_select_details->fetch() ) {
            push @rtv_quantity_ids, $rtv_quantity_id;
        }
    }

    croak 'No detail records were returned' unless scalar @rtv_quantity_ids;

    foreach my $rtv_quantity_id ( @rtv_quantity_ids ) {
        _insert_rtv_inspection_pick_request_detail({
            dbh                             => $dbh,
            rtv_inspection_pick_request_id  => $rtv_inspection_pick_request_id,
            rtv_quantity_id                 => $rtv_quantity_id,
        });
    }
    return $rtv_inspection_pick_request_id;
}

sub _insert_rtv_inspection_pick_request_detail {
    my ($arg_ref)                       = @_;
    my $dbh                             = $arg_ref->{dbh};
    my $rtv_inspection_pick_request_id  = $arg_ref->{rtv_inspection_pick_request_id};
    my $rtv_quantity_id                 = $arg_ref->{rtv_quantity_id};

    croak "Invalid rtv_inspection_pick_request_id ($rtv_inspection_pick_request_id)" if $rtv_inspection_pick_request_id !~ $FORMAT_REGEXP{id};
    croak "Invalid rtv_quantity_id ($rtv_quantity_id)" if $rtv_quantity_id !~ $FORMAT_REGEXP{id};

    my $sql
        = q{INSERT INTO rtv_inspection_pick_request_detail (rtv_inspection_pick_request_id, rtv_quantity_id)
                VALUES (?, ?)
        };
    my $sth = $dbh->prepare($sql);
    $sth->execute($rtv_inspection_pick_request_id, $rtv_quantity_id);
    return;
}

#-------------------------------------------------------------------------------
# RTV Inspection Pick
#-------------------------------------------------------------------------------

sub list_rtv_inspection_validate_pick :Export(:rtv_inspection_pick) {
    my ($arg_ref)                       = @_;
    my $dbh                             = $arg_ref->{dbh};
    my $rtv_inspection_pick_request_id  = $arg_ref->{rtv_inspection_pick_request_id};

    # An improvement over the uncannily inefficient
    # vw_rtv_inspection_validate_pick
    my $qry = <<EOQ
SELECT a.rtv_inspection_pick_request_id,
       a.status_id,
       a.status,
       a.location,
       -- These need to be quadruple-escaped because PG requires double
       -- backslashes in an E'' string for special characters, and the backslashes
       -- need to be escaped again in perl-space because we're in a heredoc
       substring( a.location, E'\\\\A(\\\\d{2})\\\\d[a-zA-Z]-?\\\\d{3,4}[a-zA-Z]\\\\Z'::text) AS loc_dc,
       substring( a.location, E'\\\\A\\\\d{2}(\\\\d)[a-zA-Z]-?\\\\d{3,4}[a-zA-Z]\\\\Z'::text) AS loc_floor,
       substring( a.location, E'\\\\A\\\\d{2}\\\\d([a-zA-Z])-?\\\\d{3,4}[a-zA-Z]\\\\Z'::text) AS loc_zone,
       substring( a.location, E'\\\\A\\\\d{2}\\\\d[a-zA-Z]-?(\\\\d{3,4})[a-zA-Z]\\\\Z'::text) AS loc_section,
       substring( a.location, E'\\\\A\\\\d{2}\\\\d[a-zA-Z]-?\\\\d{3,4}([a-zA-Z])\\\\Z'::text) AS loc_shelf,
       a.quantity_status_id,
       a.sku,
       a.sum_picklist_quantity,
       COALESCE(b.picked_quantity, 0) AS picked_quantity,
       a.sum_picklist_quantity - COALESCE(b.picked_quantity, 0) AS remaining_to_pick
FROM (
    SELECT ripr.id AS rtv_inspection_pick_request_id,
        ripr.status_id,
        riprs.status,
        l.location,
        rq.status_id AS quantity_status_id,
        (v.product_id::text || '-'::text) || sku_padding(v.size_id)::text AS sku,
        SUM(rq.quantity) AS sum_picklist_quantity
    FROM rtv_inspection_pick_request ripr
    JOIN rtv_inspection_pick_request_status riprs ON ripr.status_id = riprs.id
    JOIN rtv_inspection_pick_request_detail riprd ON riprd.rtv_inspection_pick_request_id = ripr.id
    JOIN rtv_quantity rq ON riprd.rtv_quantity_id = rq.id
    JOIN location l ON rq.location_id = l.id
    JOIN variant v ON rq.variant_id = v.id
    JOIN product_channel pc ON v.product_id = pc.product_id AND rq.channel_id = pc.channel_id
    WHERE ripr.status_id IN ($RTV_INSPECTION_PICK_REQUEST_STATUS__NEW,$RTV_INSPECTION_PICK_REQUEST_STATUS__PICKING)
    GROUP BY ripr.id,
        ripr.status_id,
        riprs.status,
        l.location,
        rq.status_id,
        (v.product_id::text || '-'::text) || sku_padding(v.size_id)::text
) a
LEFT JOIN (
    SELECT rtv_inspection_pick.rtv_inspection_pick_request_id,
        rtv_inspection_pick.location,
        rtv_inspection_pick.sku,
    COUNT(*) AS picked_quantity
    FROM rtv_inspection_pick
    WHERE rtv_inspection_pick.cancelled IS NULL
    GROUP BY rtv_inspection_pick.rtv_inspection_pick_request_id,
        rtv_inspection_pick.sku,
        rtv_inspection_pick.location
) b ON a.sku = b.sku AND a.location::text = b.location::text AND a.rtv_inspection_pick_request_id = b.rtv_inspection_pick_request_id
WHERE a.rtv_inspection_pick_request_id = ?
ORDER BY loc_dc, loc_floor DESC, loc_zone DESC, loc_section DESC, loc_shelf, sku
EOQ
;

    my $sth = $dbh->prepare($qry);
    $sth->execute($rtv_inspection_pick_request_id);

    my $rtv_inspection_validate_pick_ref = results_list($sth);
    return $rtv_inspection_validate_pick_ref;
}

sub insert_rtv_inspection_pick :Export(:rtv_inspection_pick) {
    my ($arg_ref)                       = @_;
    my $dbh_trans                       = $arg_ref->{dbh};
    my $operator_id                     = $arg_ref->{operator_id};
    my $rtv_inspection_pick_request_id  = $arg_ref->{rtv_inspection_pick_request_id};
    my $location                        = $arg_ref->{location};
    my $sku                             = $arg_ref->{sku};

    ## validate item pick
    my $item_pick_validation_ref
        = get_rtv_inspection_item_pick_validation({
                dbh                             => $dbh_trans,
                rtv_inspection_pick_request_id  => $rtv_inspection_pick_request_id,
                location                        => $location,
                sku                             => $sku,
        });

    croak 'Invalid pick - please check the location/SKU' unless defined $item_pick_validation_ref->{remaining};

    if ( $item_pick_validation_ref->{remaining} == 0 ) {
        croak 'Invalid pick - this item has been fully picked';
    }
    elsif ( $item_pick_validation_ref->{remaining} < 0 ) {
    ### I kinda hope we never get here!
        croak 'Invalid pick - this item has been over-picked';
    }

    my $sql_insert
        = q{INSERT INTO rtv_inspection_pick (operator_id, rtv_inspection_pick_request_id, location, sku, date_time)
                VALUES (?, ?, ?, ?, default)
        };

    my $sth_insert = $dbh_trans->prepare($sql_insert);
    $sth_insert->execute($operator_id, $rtv_inspection_pick_request_id, $location, $sku);
    return;
}

sub get_rtv_inspection_item_pick_validation :Export(:rtv_inspection_pick) {
    my ($arg_ref)                       = @_;
    my $dbh                             = $arg_ref->{dbh};
    my $rtv_inspection_pick_request_id  = $arg_ref->{rtv_inspection_pick_request_id};
    my $location                        = $arg_ref->{location};
    my $sku                             = $arg_ref->{sku};

    my ($product_id,$size_id) = split /-/,$sku,2;

    # for speed, we provide each sub-query with its own WHERE parameters
    my $qry = qq{
           SELECT a.sum_picklist_quantity,
                  b.picked_quantity
             FROM (SELECT SUM(rq.quantity) AS sum_picklist_quantity,
                          l.location,
                          (v.product_id || '-' || sku_padding(v.size_id)) AS sku,
                          ripr.id AS ripr_id
            FROM rtv_inspection_pick_request ripr
            JOIN rtv_inspection_pick_request_detail riprd
              ON ripr.id=riprd.rtv_inspection_pick_request_id
             AND ripr.status_id IN ($RTV_INSPECTION_PICK_REQUEST_STATUS__NEW,
                                    $RTV_INSPECTION_PICK_REQUEST_STATUS__PICKING)
            JOIN rtv_quantity rq
              ON riprd.rtv_quantity_id = rq.id
            JOIN variant v
              ON rq.variant_id=v.id
            JOIN location l
              ON rq.location_id=l.id
           WHERE v.product_id = ?
             AND v.size_id = ?
             AND l.location = ?
             AND ripr.id = ?
           GROUP BY l.location,
                    sku,
                    ripr_id
               ) a
            LEFT JOIN (SELECT COUNT(id) AS picked_quantity,
                              location,
                              sku,
                              rtv_inspection_pick_request_id AS ripr_id
            FROM rtv_inspection_pick
           WHERE cancelled IS NULL
             AND sku = ?
             AND location = ?
             AND rtv_inspection_pick_request_id = ?
           GROUP BY location,
                    sku,
                    rtv_inspection_pick_request_id
                ) b
            USING (location,sku,ripr_id)
        };

    my $sth = $dbh->prepare($qry);

    $sth->execute( $product_id, $size_id, $location, $rtv_inspection_pick_request_id,
                                    $sku, $location, $rtv_inspection_pick_request_id );

    my ($sum_picklist_quantity, $picked_quantity, $remaining_to_pick);

    $sth->bind_columns(\($sum_picklist_quantity, $picked_quantity));

    $sth->fetch();
    $sth->finish();

    $sum_picklist_quantity ||= 0;
    $picked_quantity ||= 0;
    $remaining_to_pick = $sum_picklist_quantity - $picked_quantity;

    my $results_ref = {
        total       => $sum_picklist_quantity,
        picked      => $picked_quantity,
        remaining   => $remaining_to_pick
    };

    croak 'Item pick validation error - quantity mismatch' unless $results_ref->{total} == $results_ref->{picked} + $results_ref->{remaining};
    return $results_ref;
}

sub get_rtv_inspection_pick_validation :Export(:rtv_inspection_pick) {
    my ($arg_ref)                       = @_;
    my $dbh                             = $arg_ref->{dbh};
    my $rtv_inspection_pick_request_id  = $arg_ref->{rtv_inspection_pick_request_id};

    # The FROM subselect is based on vw_rtv_inspection_validate_pick
    my $qry = <<EOQ
SELECT SUM(a.sum_picklist_quantity) AS total_picklist_quantity,
SUM(COALESCE(b.picked_quantity, 0)) AS sum_picked_quantity,
SUM(a.sum_picklist_quantity - COALESCE(b.picked_quantity, 0)) AS sum_remaining_to_pick
FROM (
    SELECT ripr.id AS rtv_inspection_pick_request_id,
    ripr.status_id,
    riprs.status,
    l.location,
    rq.status_id AS quantity_status_id,
    (v.product_id::text || '-'::text) || sku_padding(v.size_id)::text AS sku,
    SUM(rq.quantity) AS sum_picklist_quantity
    FROM rtv_inspection_pick_request ripr
    JOIN rtv_inspection_pick_request_status riprs ON ripr.status_id = riprs.id
    JOIN rtv_inspection_pick_request_detail riprd ON riprd.rtv_inspection_pick_request_id = ripr.id
    JOIN rtv_quantity rq ON rq.id = riprd.rtv_quantity_id
    JOIN location l ON rq.location_id = l.id
    JOIN variant v ON rq.variant_id = v.id
    JOIN product_channel pc ON v.product_id = pc.product_id AND rq.channel_id = pc.channel_id
    WHERE ripr.status_id IN ($RTV_INSPECTION_PICK_REQUEST_STATUS__NEW,$RTV_INSPECTION_PICK_REQUEST_STATUS__PICKING)
    GROUP BY ripr.id,
    ripr.status_id,
    riprs.status,
    l.location,
    rq.status_id,
    (v.product_id::text || '-'::text) || sku_padding(v.size_id)::text
) a
LEFT JOIN (
    SELECT rtv_inspection_pick.rtv_inspection_pick_request_id, rtv_inspection_pick.location, rtv_inspection_pick.sku, count(*) AS picked_quantity
    FROM rtv_inspection_pick
    WHERE rtv_inspection_pick.cancelled IS NULL
    GROUP BY rtv_inspection_pick.rtv_inspection_pick_request_id, rtv_inspection_pick.sku, rtv_inspection_pick.location
) b ON a.sku = b.sku AND a.location::text = b.location::text AND a.rtv_inspection_pick_request_id = b.rtv_inspection_pick_request_id
WHERE a.rtv_inspection_pick_request_id = ?
GROUP BY a.rtv_inspection_pick_request_id
EOQ
;

    my $sth = $dbh->prepare($qry);
    $sth->execute($rtv_inspection_pick_request_id);

    my ($total_picklist_quantity, $sum_picked_quantity, $sum_remaining_to_pick);

    $sth->bind_columns(\($total_picklist_quantity, $sum_picked_quantity, $sum_remaining_to_pick));

    $sth->fetch();
    $sth->finish();

    my $results_ref = {
        total       => $total_picklist_quantity,
        picked      => $sum_picked_quantity,
        remaining   => $sum_remaining_to_pick,
    };

    croak 'Shipment pick validation error - quantity mismatch' unless $results_ref->{total} == $results_ref->{picked} + $results_ref->{remaining};
    return $results_ref;
}

sub commit_rtv_inspection_pick :Export(:rtv_inspection_pick) {
    my ($arg_ref)                       = @_;
    my $dbh_trans                       = $arg_ref->{dbh};
    my $rtv_inspection_pick_request_id  = $arg_ref->{rtv_inspection_pick_request_id};
    my $operator_id                     = $arg_ref->{operator_id};

    ## validate pick - ensure there are no items remaining to pick, or overpicked items, on the specified inspection_pick_request
    my $inspection_pick_validation_ref
        = get_rtv_inspection_pick_validation({
                dbh                             => $dbh_trans,
                rtv_inspection_pick_request_id  => $rtv_inspection_pick_request_id,
        });

    if ( $inspection_pick_validation_ref->{remaining} > 0 ) {
        croak 'Unable to commit pick - this shipment has unpicked items';
    }
    elsif ( $inspection_pick_validation_ref->{remaining} < 0 ) {
        croak 'Unable to commit pick - this shipment has overpicked items';
    }

    ## get 'RTV Workstation' location_id
    my $location_details_ref    = get_location_details( { dbh => $dbh_trans, location => 'RTV Workstation' } );
    my $location_id             = $location_details_ref->{location_id};

    my $rtv_quantity_ids_ref
        = get_detail_ids({
                dbh     => $dbh_trans,
                type    => 'rtv_inspection_pick_request',
                id      => $rtv_inspection_pick_request_id
        });

    foreach my $rtv_quantity_id ( @{$rtv_quantity_ids_ref} ) {
        transfer_rtv_stock({
            dbh                 => $dbh_trans,
            rtv_stock_type_from => 'RTV Goods In',
            rtv_stock_type_to   => 'RTV Workstation',
            location_id_to      => $location_id,
            type                => 'rtv_quantity_id',
            id                  => $rtv_quantity_id,
            operator_id         => $operator_id,
        });
    }

    ## Update rtv_inspection_pick_request status
    update_rtv_status({
        dbh         => $dbh_trans,
        entity      => 'rtv_inspection_pick_request',
        type        => 'rtv_inspection_pick_request_id',
        id          => $rtv_inspection_pick_request_id,
        status_id   => $RTV_INSPECTION_PICK_REQUEST_STATUS__PICKED,
        operator_id => $operator_id,
    });
    return;
}

sub cancel_rtv_inspection_pick :Export(:rtv_inspection_pick) {
    my ($arg_ref)                       = @_;
    my $dbh_trans                       = $arg_ref->{dbh};
    my $rtv_inspection_pick_request_id  = $arg_ref->{rtv_inspection_pick_request_id};
    my $operator_id                     = $arg_ref->{operator_id};

    ## update rtv_inspection_pick records - set cancelled timestamp
    my $sql_update  = q{UPDATE rtv_inspection_pick SET cancelled = LOCALTIMESTAMP WHERE rtv_inspection_pick_request_id = ? AND operator_id = ?};

    my $sth_update  = $dbh_trans->prepare($sql_update);
    $sth_update->execute($rtv_inspection_pick_request_id, $operator_id);

    ## update rtv_inspection_pick_request_status as necessary
    my $status_ref = get_rtv_status( { dbh => $dbh_trans, entity => 'rtv_inspection_pick_request', id => $rtv_inspection_pick_request_id } );

    if ( $status_ref->{status_id} == $RTV_INSPECTION_PICK_REQUEST_STATUS__PICKING ) {
        update_rtv_status({
            dbh         => $dbh_trans,
            entity      => 'rtv_inspection_pick_request',
            type        => 'rtv_inspection_pick_request_id',
            id          => $rtv_inspection_pick_request_id,
            status_id   => $RTV_INSPECTION_PICK_REQUEST_STATUS__NEW,
            operator_id => $operator_id,
        });
    }
    return;
}

#-------------------------------------------------------------------------------
# RTV Shipment Detail Result
#-------------------------------------------------------------------------------

sub list_rtv_shipment_result_details :Export(:rtv_shipment_result) {
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $rtv_shipment_id = $arg_ref->{rtv_shipment_id};

    croak "Invalid rtv_shipment_id ($rtv_shipment_id)" if $rtv_shipment_id !~ $FORMAT_REGEXP{id};

    my $qry
        = q{SELECT
                rsd.rtv_shipment_id
            ,   rsdr.id
            ,   rsdr.rtv_shipment_detail_id
            ,   rsdrt.type
            ,   rsdr.quantity
            ,   rsdr.reference
            ,   to_char(rsdr.date_time, 'DD-Mon-YYYY HH24:MI') AS txt_date_time
            ,   o.name AS operator
            FROM rtv_shipment_detail rsd
            INNER JOIN rtv_shipment_detail_result rsdr
                ON (rsdr.rtv_shipment_detail_id = rsd.id)
            INNER JOIN rtv_shipment_detail_result_type rsdrt
                ON (rsdr.type_id = rsdrt.id)
            INNER JOIN operator o
                ON (rsdr.operator_id = o.id)
            WHERE rtv_shipment_id = ?
            ORDER BY rsdr.date_time
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($rtv_shipment_id);

    my $results_ref = results_list($sth);

    my $rtv_shipment_result_details_ref;

    foreach my $detail_ref ( @{$results_ref} ) {
        push @{ $rtv_shipment_result_details_ref->{ $detail_ref->{rtv_shipment_detail_id} } }, $detail_ref;
    }
    return $rtv_shipment_result_details_ref;
}

sub insert_rtv_shipment_detail_result :Export(:rtv_shipment_result) {
    my ($arg_ref)               = @_;
    my $dbh_trans               = $arg_ref->{dbh};
    my $rtv_shipment_detail_id  = $arg_ref->{rtv_shipment_detail_id};
    my $type_id                 = $arg_ref->{type_id};
    my $quantity                = $arg_ref->{quantity};
    my $reference               = $arg_ref->{reference};
    my $notes                   = $arg_ref->{notes};
    my $operator_id             = $arg_ref->{operator_id};

    croak "Invalid rtv_shipment_detail_id ($rtv_shipment_detail_id)" if $rtv_shipment_detail_id !~ $FORMAT_REGEXP{id};
    croak "Invalid rtv_shipment_detail_result type_id ($type_id)" if $type_id !~ $FORMAT_REGEXP{id};
    croak "Invalid quantity ($quantity)" if $quantity !~ m{\A[1-9]\d{0,2}\z}xms;    ## allow positive integers 1 - 999
    croak "Invalid operator_id ($operator_id)" if $operator_id !~ $FORMAT_REGEXP{id};

    my $sql
        = q{INSERT INTO rtv_shipment_detail_result (operator_id, rtv_shipment_detail_id, type_id, quantity, reference, notes, date_time)
                VALUES (?, ?, ?, ?, ?, ?, default)
        };
    my $sth = $dbh_trans->prepare($sql);
    $sth->execute($operator_id, $rtv_shipment_detail_id, $type_id, $quantity, $reference, encode_db($notes));

    my $rtv_shipment_detail_result_id = last_insert_id($dbh_trans, 'rtv_shipment_detail_result_id_seq');
    return $rtv_shipment_detail_result_id;
}

sub create_rtv_replacement_stock_order :Export(:rtv_shipment_result) {
    my ($arg_ref)   = @_;
    my $dbh_trans   = $arg_ref->{dbh};
    my $variant_id  = $arg_ref->{variant_id};
    my $quantity    = $arg_ref->{quantity};

    croak "Invalid variant_id ($variant_id)" unless is_valid_format( { value => $variant_id, format => 'id' } );
    croak "Invalid quantity '$quantity'" unless is_valid_format( { value => $quantity, format => 'int_positive' } );

    ## get product_id, purchase_order_id
    my $qry_po_details
        = qq{SELECT so.product_id, so.purchase_order_id
            FROM purchase_order po
            INNER JOIN stock_order so
                ON (so.purchase_order_id = po.id)
            INNER JOIN stock_order_item soi
                ON (soi.stock_order_id = so.id)
            WHERE soi.variant_id = ?
            --AND so.status_id = $STOCK_ORDER_STATUS__DELIVERED
            AND po.type_id IN ($PURCHASE_ORDER_TYPE__FIRST_ORDER, $PURCHASE_ORDER_TYPE__RE_DASH_ORDER)
        };
    my $sth_po_details = $dbh_trans->prepare($qry_po_details);
    $sth_po_details->execute($variant_id);

    my $po_details_row_ref  = $sth_po_details->fetchrow_hashref();
    my $purchase_order_id   = $po_details_row_ref->{purchase_order_id};
    my $product_id          = $po_details_row_ref->{product_id};

    croak 'Unable to find purchase_order' unless is_valid_format( { value => $purchase_order_id, format => 'id' } );
    croak 'Invalid product_id' unless is_valid_format( { value => $product_id, format => 'id' } );

    my $qry_update_po_status = qq{UPDATE purchase_order SET status_id = $PURCHASE_ORDER_STATUS__PART_DELIVERED where id = ?};
    my $sth_update_po_status = $dbh_trans->prepare($qry_update_po_status);
    $sth_update_po_status->execute($purchase_order_id);

    ## get stock_order_id
    my $qry_so_id
        = qq{SELECT id
            FROM stock_order
            WHERE product_id = ?
            AND purchase_order_id = ?
            AND type_id = $STOCK_ORDER_TYPE__REPLACEMENT
            ORDER BY id DESC
            LIMIT 1
        };
    my $sth_so_id = $dbh_trans->prepare($qry_so_id);
    $sth_so_id->execute($product_id, $purchase_order_id);

    my $stock_order_id;
    $sth_so_id->bind_columns(\$stock_order_id);
    $sth_so_id->fetch();
    $sth_so_id->finish();

    if ( not is_valid_format( { value => $stock_order_id, format => 'id' } ) ) {
    ## if no stock order returned, insert one and retrieve it's id

        my $qry_insert_so
            = qq{INSERT INTO stock_order (product_id, purchase_order_id, start_ship_date, cancel_ship_date, status_id, comment, type_id, consignment, cancel)
                    VALUES ( ?, ?, NULL, NULL, $STOCK_ORDER_STATUS__ON_ORDER, '', $STOCK_ORDER_TYPE__REPLACEMENT, false, false)
            };
        my $sth_insert_so = $dbh_trans->prepare($qry_insert_so);
        $sth_insert_so->execute($product_id, $purchase_order_id);

        $stock_order_id = last_insert_id($dbh_trans, 'stock_order_id_seq');
    }

    croak 'Unable to find new stock_order' unless is_valid_format( { value => $stock_order_id, format => 'id' } );

    ## insert stock_order_item
    my $qry_insert_soi
        = qq{INSERT INTO stock_order_item (stock_order_id, variant_id, quantity, status_id, type_id, cancel)
                VALUES (?, ?, ?, $STOCK_ORDER_ITEM_STATUS__ON_ORDER, 0, false)
        };
    my $sth_insert_soi = $dbh_trans->prepare($qry_insert_soi);
    $sth_insert_soi->execute($stock_order_id, $variant_id, $quantity);

    my $stock_order_item_id = last_insert_id($dbh_trans, 'stock_order_item_id_seq');
    return $stock_order_item_id;
}

1;
