package XT::Data::StockReconcile::IwsStockReconciler;
# vim: set ts=4 sw=4 sts=4:
use namespace::autoclean;

use Moose;
use File::Temp;
use XTracker::Config::Local qw( config_var );
use XT::Data::StockReconcile::StockReconciler;

# This module reconciles XTracker's stock with IWS's.


has reconciler => ( is => 'rw', isa => 'Object' );


# Do comparison of two stock files and return a hash describing discrepancies
sub compare_stock {
    my ( $self, $export_dirname ) = @_;

    # Column definitions for the stock files, in order
    my $key_columns  = [   {   name  => 'channel',
                               alias => ['client'],
                               type => 'text',
                           },
                           {   name  => 'sku',
                               alias => ['article'],
                               type => 'sku',
                           },
                           {   name  => 'status',
                               type => 'text',
                           },
                           ];
    my $data_columns = [   {   name  => 'unavailable',
                               type => 'count',
                           },
                           {   name  => 'allocated',
                               type => 'count',
                           },
                           {   name  => 'available',
                               type => 'count',
                           },
                       ];


    # Make a StockReconciler object. It will have a 'stock' field which stores all the stock we find
    # in the reference file, and subsequently will be mangled according to what we find in the
    # comparison file, before being used to create all of our outputs.
    my $reconciler = XT::Data::StockReconcile::StockReconciler->new({ key_columns => $key_columns,
                                                                      data_columns => $data_columns });
    $self->reconciler($reconciler);


    # Here are all the files we expect to be reading or writing.  We toss in file handles for
    # summary and errors for the case where the file names are never used, to avoid cluttering up
    # the code later -- we just scribble over these file handles if we need to.
    my $files={ reference        => { name    => config_var('Reconciliation','xt_stock_export_file'),
                                      columns => $reconciler->stock_columns,
                                      mode    => 'read',
                                    },
                comparison       => { name    => config_var('Reconciliation','iws_stock_export_file'),
                                      columns => $reconciler->stock_columns,
                                      mode    => 'read',
                                    },
              };

    # Fail fast when we can't read or create the files we're supposed to
    foreach my $file (values %{$files}) {
        # create all the paths to target files here, not before, since
        # the command line args affect these

        $file->{path} = File::Spec->catfile ( $export_dirname, $file->{name} );

        if (exists $file->{mode}) {
            if ($file->{mode} eq 'read') {
                open ($file->{fh}, '<:utf8', $file->{path})
                    or die qq/Cannot read from '$file->{path}': $!\n/;
            }
            elsif ($file->{mode} eq 'write') {
                open ($file->{fh}, '>:utf8', $file->{path})
                    or die qq/Cannot write to '$file->{path}': $!\n/;
            }
        }
    }

    # Call method to do the actual reconciliation
    my $reference_column_names_by_number = [];
    my $comparison_column_names_by_number = [];
    $reconciler->reconcile_files( $files->{reference}->{name},
                                  $files->{reference}->{fh},
                                  $reference_column_names_by_number,
                                  $files->{comparison}->{name},
                                  $files->{comparison}->{fh},
                                  $comparison_column_names_by_number );

    # Close files
    foreach my $file (values %{$files}) {
        close ($file->{fh});
    }

    return $reconciler->stock;
}


# Given a hash describing descrepancies, return a string which is a summary stock reconciliation report
# suitable for use as an email body.
sub gen_summary {
    my ( $self, $starttime ) = @_;

    return $self->reconciler->gen_summary($starttime);
}


# Generate a stock reconciliation detail report and return the full path of the file containing the report.
sub gen_report {
    my ( $self ) = @_;

    return $self->reconciler->gen_report;
}


# Email the report of discrepancies
sub email_report {
    my ( $self, $summary, $reportfile, $prl, $recipient ) = @_;

    $self->reconciler->email_report($summary, $reportfile, $prl, $recipient);
}

1;
