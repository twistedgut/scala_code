package XTracker::Stock::Inventory::ProductApproval;

use strict;
use warnings;
use Carp;

use Data::Dumper;
use Data::Serializer;
use Spreadsheet::WriteExcel;
use LWP::Simple;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database                      qw( get_database_handle );
use XTracker::Database::Operator            qw( get_operator_by_id );
use XTracker::Database::Channel             qw( get_channels );
use XTracker::Database::Utilities           qw( results_list results_hash2 );
use XTracker::Database::Product::Approval   qw( archive_product_approval_list build_approval_list get_availability_details delete_approval_list );
use XTracker::Database::Pricing             qw( get_discounts );
use XTracker::Navigation                    qw( build_sidenav );
use XTracker::Utilities                     qw( get_date_db trim );
use XTracker::XTemplate;

use XTracker::Config::Local                 qw( xt_url_dc1 xt_url_dc2 config_var);

use DateTime;
use File::Temp qw/ tempfile /;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);
    my $dt          = DateTime->now( time_zone => "local" );

    $handler->{data}{section}           = 'Stock Control';
    $handler->{data}{subsection}        = 'Product Approval';
    $handler->{data}{subsubsection}     = '';
    $handler->{data}{content}           = 'stocktracker/inventory/product_approval.tt';
    $handler->{data}{tt_process_block}  = 'frm_enter_product_ids';
    $handler->{data}{xt_url_dc1}        = xt_url_dc1( );
    $handler->{data}{xt_url_dc2}        = xt_url_dc2( );
    $handler->{data}{txta_product_ids}  = $handler->{param_of}{txta_product_ids};
    $handler->{data}{operator}          = get_operator_by_id( $handler->{dbh}, $handler->{data}{operator_id} );
    $handler->{data}{channels}          = get_channels( $handler->{dbh} );
    $handler->{data}{sidenav}           = build_sidenav( { navtype => 'productapproval' } );

    my $dbh_read_dc1 = get_database_handle( { name => 'XTracker_DC1', type => 'readonly' } );
    my $dbh_read_dc2 = get_database_handle( { name => 'XTracker_DC2', type => 'readonly' } );

    my $regex_txta_product_ids  = qr/(^\s*(?:\d+\s*,?\s*)+\d+\s*$)/;

    # view archived lists
    if ( defined $handler->{param_of}{action} and $handler->{param_of}{action} eq 'archive' ) {

        $handler->{data}{tt_process_block}  = 'archive';
        $handler->{data}{subsubsection}     = 'List Archive';
        $handler->{data}{archive}           = archive_product_approval_list( { dbh => $handler->{dbh} } );

    }
    # delete list
    elsif ( defined $handler->{param_of}{delete} ) {

        delete_approval_list( $handler->{dbh}, $handler->{param_of}{delete} );

    }
    # read in an archived list
    elsif ( defined $handler->{param_of}{archive_id} ) {

        my ( $serialized, $a_created_timestamp, $a_operator, $a_title, $a_created_date ) = archive_product_approval_list( { dbh => $handler->{dbh}, id => $handler->{param_of}{archive_id} } );

        my $serializer = Data::Serializer->new() or die "error initialising: Data::Serializer->new()";

        my $archive = $serializer->deserialize( $serialized );

        my $values = join( ',', @{ $archive } );

        $handler->{data}{subsubsection}         = 'View Archived List';
        $handler->{data}{tt_process_block}      = 'frm_enter_product_ids';
        $handler->{data}{values}                = $values;
        $handler->{data}{a_title}               = $a_title;
        $handler->{data}{a_operator}            = $a_operator;
        $handler->{data}{a_created_timestamp}   = $a_created_timestamp;
        $handler->{data}{a_created_date}        = $a_created_date;
        $handler->{data}{archive_id}            = $handler->{param_of}{archive_id};

    }
    # archive a list
    elsif ( defined $handler->{param_of}{action} and $handler->{param_of}{action} eq 'archive_products' ) {

        eval {

            my @product_id;

            foreach my $key ( keys %{ $handler->{param_of} } ) {
                if ( $key =~m%^product_id-(\d+)$% ) {
                    my $product_id = $1;
                    push @product_id, $product_id;
                }
            }

            my $serializer = Data::Serializer->new() or die "error initialising: Data::Serializer->new()";

            my $serial = $serializer->serialize( \@product_id );

            archive_product_approval_list( { dbh          => $handler->{dbh},
                                             list         => $serial,
                                             operator_id  => $handler->{data}{operator_id},
                                             title        => $handler->{param_of}{archive_title},
                         } );

        };

    }
    # no action - user is entering products for first time
    elsif ( !$handler->{param_of}{action} ) {

        $handler->{data}{subsubsection}     = 'Enter Products';
        $handler->{data}{tt_process_block}  = 'frm_enter_product_ids';

    }
    # process list of pids
    elsif ( defined $handler->{param_of}{action} && lc($handler->{param_of}{action}) eq 'processlist' && $handler->{param_of}{txta_product_ids} =~ m/$regex_txta_product_ids/ ) {

        my @product_ids = split /,/, $1;
        $_ = trim($_) foreach (@product_ids);

        $handler->{data}{sales_channel} = $handler->{param_of}{channel};

        my ($approval_list_ref, $invalid_pids_ref) = build_approval_list( { dbh_dc1 => $dbh_read_dc1, dbh_dc2 => $dbh_read_dc2, product_ids => \@product_ids, channel => $handler->{param_of}{channel} } );
        $handler->{data}{error_msg} .= "WARNING: No data was returned for the following PID's: ".join(', ', sort { $a <=> $b } @$invalid_pids_ref) if scalar @$invalid_pids_ref;

        if ( @$approval_list_ref ) {
            $handler->{data}{subsubsection}         = 'View List';
            $handler->{data}{product_approval_list} = $approval_list_ref;
            $handler->{data}{tt_process_block}      = 'product_approval_list';
            $handler->{data}{dc1_discounts}         = get_discounts( { dbh => $dbh_read_dc1, id_ref => $approval_list_ref, type => 'product_id' } );
            $handler->{data}{dc2_discounts}         = get_discounts( { dbh => $dbh_read_dc2, id_ref => $approval_list_ref, type => 'product_id', site => 'am', } );
        }
        else {
            $handler->{data}{subsubsection}         = 'Enter Products';
            $handler->{data}{tt_process_block}      = 'frm_enter_product_ids';
            $handler->{data}{posted_keyword}        = $handler->{param_of}{txt_keyword};
            $handler->{data}{posted_product_ids}    = $handler->{param_of}{txta_product_ids};
        }
    }
    else {
        $handler->{data}{error_msg} .= "  Please ensure that your list of Product ID\'s is in the correct format!" unless ( $handler->{param_of}{txta_product_ids} =~ m/$regex_txta_product_ids/ );

        $handler->{data}{subsubsection}         = 'Enter Products';
        $handler->{data}{tt_process_block}      = 'frm_enter_product_ids';
        $handler->{data}{posted_keyword}        = $handler->{param_of}{txt_keyword};
        $handler->{data}{posted_product_ids}    = $handler->{param_of}{txta_product_ids};

    }

    $dbh_read_dc1->disconnect();
    $dbh_read_dc2->disconnect();

    if ( defined $handler->{param_of}{media} and $handler->{param_of}{media} eq 'xls' ) {
        saveXLS( $handler );
    }
    else {
        $handler->process_template( undef );
    }

    return OK;

}


sub saveXLS {

    my $handler = shift;

    my $p       = $handler->{data};

    my $export_dir  =  config_var('SystemPaths', 'export_dir');

    if (! -d "/$export_dir/productapproval/") {
        mkdir ("/$export_dir/productapproval/") or die $!;
    }

    my ($fh, $filename) = tempfile( 'xlsXXXXX', DIR => "/$export_dir/productapproval/") or die $!;

    my $workbook    = Spreadsheet::WriteExcel->new( $fh );
    my $worksheet   = $workbook->add_worksheet();

    # set-up some standard formatting
    my $col_format  = $workbook->add_format( align => 'left', valign => 'top' );
    my $hdr_format  = $workbook->add_format( bold => 1);
    my $date_format = $workbook->add_format( num_format => 'dd/mm/yyyy', align => 'left', bold => 1 );

    my @to_delete;

    # array to store the main rows/columns of data
    my @main_rows;

    # array to store length of each column (from col B onwards)
    my @col_lens;

    # get today's date
    my $dt          = DateTime->now( time_zone => "local" );


    $worksheet->set_column(0, 0, 40);

    $worksheet->write( 0, 0, $p->{section}, $hdr_format );
    $worksheet->write_date_time( 0, 1, $dt->ymd."T", $date_format );

    my $col = 0;
    my $row = 2;

    foreach my $d ( "Photo", "Product ID", "Legacy SKU", "Season", "Designer", "Product Name", "Description", "DC1 On Hand", "DC1 Sample Room", "DC2 On Hand", "Upload Date", ) {
        $worksheet->write($row, $col, $d, $hdr_format);
        ++$col;
        push @col_lens, length($d);         # store the length of each header
    }
    shift @col_lens;                        # don't need the first header field

    ++$row;

    foreach my $data ( @{$p->{product_approval_list}} ) {

        # switched from converting jpg to bmp before inserting
        # just insert jpg directly - bmp was hit and miss

        my $product_id  = $data->{product_id};
        my $prod_image  = $data->{image}->[0];

        if ( $prod_image ) {

            # copy down image to tmp to include in Excel doc
            if( my $image = get($prod_image) ){

                # write filename with current Proc ID so as to minimise people getting the same image at the same time
                # when it comes to deleting it later
                my $local_file = '/tmp/prod_'.$product_id.'_'.$$.'.jpg';

                open my $fh, '>', $local_file;
                binmode $fh;
                print $fh $image;
                close $fh;
                chmod 0777,$local_file;

                if ( -f $local_file ) {

                    $worksheet->set_row( $row, 180 );
                    $worksheet->insert_image($row, 0, $local_file);

                    # store file to be deleted later
                    push @to_delete, $local_file;
                }
            }
        }
        else {
            $worksheet->write( $row, 0,  $data->{product_id} );
        }

        # push rest of data onto the main data array
        push @main_rows, [
                            $data->{product_id},
                            'n/a',
                            $data->{season},
                            $data->{designer},
                            $data->{name},
                            $data->{description},
                            $data->{dc1_stock}{free_stock},
                            $data->{quantity_in_sample_room},
                            $data->{dc2_stock}{free_stock},
                            $data->{upload_date}
                        ];

        ++$row;
    }

    # get the max lengths of each column (col B onwards)
    if ( @main_rows ) {
        foreach my $tmp_row ( @main_rows ) {
            foreach ( 0..$#{$tmp_row} ) {
                $col_lens[$_]   = ( length( $tmp_row->[$_] ) > $col_lens[$_] ? length( $tmp_row->[$_] ) : $col_lens[$_] );
            }
        }
    }
    # set the width of each column (col B onwards)
    foreach ( 0..$#col_lens ) {
        $worksheet->set_column( ($_+1), ($_+1), ($col_lens[$_]+2), $col_format );
    }

    # write the main body of data in one go from cell B4 onwards
    $worksheet->write_col( 3, 1, \@main_rows );

    # close the spreadsheet, otherwise not everything gets written and can lead to ZERO BYTE length file
    $workbook->close();

    # delete any images created
    map { unlink($_) } @to_delete;

    # get ready to output the spearsheet directly to STDOUT
    my $sheetname= "product_approval.xls";
    $handler->{r}->headers_out->set('Content-Disposition' => "attachment;filename=$sheetname");
    $handler->{r}->content_type('application/vnd.ms-excel');
    $handler->{r}->{sendfile} = $filename;

    return;

}


1;

__END__

