package XTracker::Order::Finance::TransactionReporting;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Config::Local qw( config_var );
use XTracker::Handler;
use XTracker::Error;

use XTracker::Utilities qw( portably_get_basename );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $upload_file = $handler->{request}->upload('upload_file') || undef;

    $handler->{data}{customer_id}   = $handler->{request}->param('customer_id');

    $handler->{data}{content}       = 'ordertracker/finance/transaction_reporting.tt';
    $handler->{data}{section}       = 'Finance';
    $handler->{data}{subsection}    = 'Transaction Reporting';


    # Extract the datacash payments and refunds
    if ( $upload_file ) {

        if ( has_csv_extension( $upload_file->filename ) ) {

            # extract transaction refs from file
            my $transaction_ref = extract_psp_references($upload_file);

            # get order number for transaction ref from Payment service
            my $payment_ws      = XT::Domain::Payment->new();
            my $payment_info    = $payment_ws->getorder_numbers( $transaction_ref );

            my $to_order_ref;

            PAYMENT_INFO:
            while ( my ( $key, $value ) = each %{$payment_info} ) {
                next PAYMENT_INFO unless $key =~ /\d+/;
                $to_order_ref->{$key} = $value;
            }

            $handler->{data}{download_link} = '/export/'.replace_psp_references( $upload_file, $to_order_ref);

        }
        else {
            xt_warn( $upload_file->filename.' is not a .csv file' );
        }
    }

    $handler->process_template( undef );

    return OK;
}

### Subroutine : extract_psp_references    ###
# usage        : extract_psp_references($upload_file)                 #
# description  : Extracts payment service references     #
#                from the given csv file and      #
#                returns them in an array      #
# parameters   : $upload_file                     #
# returns      : \@transactions             #

sub extract_psp_references {

    my ( $upload_file ) = @_;

    my ( @transactions );

    open( my $CSV_INPUT_FILE, "<", $upload_file->path )
        || warn "Cannot open csv file: ".$upload_file->path." $!";

    LINE:
    while( my $line = <$CSV_INPUT_FILE> ) {

        # match internal psp-ref
        if ( $line =~ /(\d+\-\d{13})/ ) {
            push @transactions, $1;
        }
    }

    close $CSV_INPUT_FILE;

    return \@transactions;
}

### Subroutine : replace_psp_references    ###
# usage        : replace_psp_references(     #
#                   $upload_file,                 #
#                   $to_order_ref)       #
# description  : Reads the csv upload file,       #
#                replaces the psp references #
#                stored as keys in the given hash #
#                with order ids stored as values, #
#                writing an updated csv file      #
# parameters   : $upload_file,                    #
#                $to_order_ref           #
# returns      : $output_file                     #

sub replace_psp_references {

    my ( $upload_file, $to_order_ref ) = @_;

    my $output_path = config_var('SystemPaths','export_dir').'/';
    my $output_file = set_output_filename( portably_get_basename( $upload_file->filename ) );

    eval {
        open my $CSV_INPUT_FILE, "<", $upload_file->path or die "Could not read ".$upload_file->path." $!";
        open my $CSV_OUTPUT_FILE, '>', $output_path.$output_file or die "Couldn't write to $output_file: $!";

        LINE:
        while (<$CSV_INPUT_FILE>) {
            my $line = $_;

            # try to match transaction ref in line
            if ( $line =~ /(\d+\-\d{13})/ ) {

                my $transaction_ref = $1;

                # we have an order number for transaction ref
                if ( defined $to_order_ref->{$transaction_ref} ) {

                    # add order number to start of the line
                    $line = $to_order_ref->{$transaction_ref} . ',' . $line;
                }
                else {
                    $line = 'UNKNOWN,' . $line;
                }

            }
            else {
                $line = 'NO MATCH,' . $line;
            }

            # print line to output file
            print {$CSV_OUTPUT_FILE} $line;
        }

        close $CSV_INPUT_FILE;
        close $CSV_OUTPUT_FILE;

    };

    if ( my $error = $@ ) {
        xt_warn( $error );
        return;
    }

    return $output_file;
}

### Subroutine : set_output_filename            ###
# usage        : set_output_filename(             #
#                   $upload_filename)             #
# description  : Reads a filename and adds        #
#                _parsed before its extension     #
# parameters   : $upload_filename                 #
# returns      : $output_filename                 #

sub set_output_filename {

    my ( $upload_filename ) = @_;
    my $output_filename;

    if ( $upload_filename =~ /(.*)\.csv$/ ) {
        $output_filename = "$1_parsed.csv";
    }

    return $output_filename;
}

### Subroutine : has_csv_extension              ###
# usage        : has_csv_extension(               #
#                   $upload_filename)             #
# description  : Checks if the filename has a csv #
#                extension                        #
# parameters   : $upload_filename                 #
# returns      : 1 on success, 0 on failure       #

sub has_csv_extension {

    my ( $upload_filename ) = @_;
    my $output_filename;

    if ( $upload_filename =~ /(.*)\.csv$/ ) {
        return $upload_filename;
    }

    return 0;
}

1;
