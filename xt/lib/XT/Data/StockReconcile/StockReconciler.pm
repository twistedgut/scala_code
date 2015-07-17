package XT::Data::StockReconcile::StockReconciler;

use Moose;
use Carp qw( croak );
use namespace::autoclean;
use POSIX qw( strftime );
use File::Temp qw{ tempdir };
use Text::CSV_XS;

use NAP::policy "tt", 'class';
use XTracker::Utilities qw ( strip );
use XTracker::Database::Variant qw ( :validation );
use XTracker::Config::Local qw( config_var );
use XTracker::EmailFunctions qw( send_email );

=head1 NAME

XT::Data::StockReconcile::StockReconciler - class for reconciling XTracker's inventory against another
                                            systems, for example IWS or a PRL.
=cut


sub BUILD {
    my ($self,$args) = @_;

    my $key_columns  = $args->{key_columns};
    my $data_columns  = $args->{data_columns};

    # Set checking function for columns
    for my $colset ($key_columns, $data_columns) {
      for my $col (@$colset) {
        $col->{check} = { count => \&check_count, text => \&check_text, sku => \&check_sku }->{$col->{type}};
      }
    }

    $self->key_column_names( [ map { $_->{name} } @{$key_columns} ] );
    $self->data_column_names( [ map { $_->{name} } @{$data_columns} ] );

    # Except, for the differences file we create, we spit out
    # delta columns so that whatever picks up this file has enough
    # to go on.
    my $delta_columns = [ map { ( { name => 'xt_'.$_   },
                                  { name => $self->attr_prefix . '_' . $_ },
                                  { name => 'difference_'.$_ } ) }
                          @{$self->data_column_names}
                        ];

    # Put together the definitions for all the types of
    # file we expect to encounter, using the above pieces as
    # the building blocks
    $self->stock_columns( { columns => [ @{$key_columns}, @{$data_columns} ] } );
    $self->difference_columns( { columns => [ @{$key_columns}, @{$delta_columns}] } );

    # Now some oft-accessed attributes that are derived from the others
    # (which does create a slightly redundant structure).
    foreach my $cols ( $self->stock_columns, $self->difference_columns ) {
        $cols->{count}      = scalar(@{$cols->{columns}});
        $cols->{names}      = [ map { $_->{name} } @{$cols->{columns}} ];
        $cols->{first_name} = $cols->{names}->[0];

        # we map everything to a text type as far as Text::CSV is concerned,
        # because we want to do nice checking ourselves, rather than having
        # poopy messages squirted out by the underlying parser
        $cols->{types}      = [ ( Text::CSV_XS::PV() ) x $cols->{count} ];
    }
}


has key_column_names   => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );
has data_column_names  => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );
has stock_columns      => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has difference_columns => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has stock              => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has errors_by_filename => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has error_count        => ( is => 'rw', isa => 'Int', default => 0 );
has attr_prefix        => ( is => 'rw', isa => 'Str', default => 'iws' );
has stockholder_name   => ( is => 'rw', isa => 'Str', default => 'IWS' );
has report_file        => ( is => 'ro', isa => 'Str', default => 'stock_discrepancies.csv' );
has report_dir         => ( is => 'rw', isa => 'Str' );
has keep_report_dir    => ( is => 'rw', isa => 'Bool', default => 0 );


# some data checking subs for the stuff we expect to read
sub check_sku {
      my ($name,$sku) = @_;

      die qq{$name is missing\n} unless $sku;

      die qq{$name is not a well-formed SKU\n} unless is_valid_sku($sku);

      return 1;
}

sub check_count {
      my ($name,$count) = @_;

      die qq{$name is missing\n} unless defined $count;

      die qq{$name is not a count\n} unless $count =~ m{\A[+-]?\d+\z};

      return 1;
}

sub check_text {
      my ($name,$text) = @_;

      die qq{$name is missing\n} unless defined($text) and $text ne q{};

      return 1;
}


sub key_of {
    my ($self,$item) = @_;

    # it doesn't really matter if '/' turns up in the data fields
    # we compose to make the key, since we never decompose the key
    # back into the constituent fields from the key
    #
    # the only problem would be if '/' was added to all of the
    # fields, *and* the fragments either side of it could legitimately
    # exist in channel names, SKUs and statuses; in which case,
    # I'd presume it was being done just to annoy me

    # remove "stock" at the end of any field, because DCD sends e.g.
    # "Main Stock" where we expect "MAIN" - quick hack for DCA-2520.
    # it's safe enough for now, we should fix it better later though.
    # TODO: DCA-2526

    # up-case the resulting key, since case is not significant
    # in channel, SKU or status names, and we've had some
    # encounters with 'theOutnet.com' versus 'THEOUTNET.COM',
    # in actual data, which shouldn't be seen as different

    return uc join(q{/}, map { s/\s?stock$//ri } @{$item}{ @{$self->key_column_names} });
}


# Perform the reconciliation against two stock files
sub reconcile_files {
  my ( $self,
       $ref_filename, $ref_fh, $ref_column_names_by_number,
       $com_filename, $com_fh, $com_column_names_by_number ) = @_;

    # Process the reference file first, and stash it ourself
    $self->_process_stock_file(
                        $ref_filename,
                        $ref_fh,
                        $ref_column_names_by_number,
                        sub {
                           my $reference_item = shift;
                           my $key=$self->key_of($reference_item);

                           die qq{Duplicate record found for $key -- IGNORED\n}
                               if exists $self->stock->{reference}->{$key};

                           $self->stock->{reference}->{$key} = $reference_item;
                        }
    );

    # Process the comparison file, and use that to drive the reconciliation processing as we
    # read it, since storing it doesn't gain us anything but memory overhead
    $self->_process_stock_file(
                        $com_filename,
                        $com_fh,
                        $com_column_names_by_number,
                        sub {
                           my $comparison_item = shift;
                           my $key=$self->key_of($comparison_item);

                           # did we do this one already?
                           die qq{Duplicate record found for $key -- IGNORED\n}
                               if exists $self->stock->{comp_only}->{$key} or
                                  exists $self->stock->{identical}->{$key} or
                                  exists $self->stock->{different}->{$key}
                                ;

                           # can we do a comparison anyway?
                           unless (exists $self->stock->{reference}->{$key}) {
                               $self->stock->{comp_only}->{$key} = $comparison_item;

                               return;
                           }

                           my $reference_item = $self->stock->{reference}->{$key};
                           my $different = 0;

                         DATA_COLUMN:
                           foreach ( @{$self->data_column_names} ) {
                               if ($reference_item->{$_} ne $comparison_item->{$_}) {
                                   $different = 1;

                                   last DATA_COLUMN; # no need to compare any further
                               }
                           }

                           if ($different) {
                               my $different_item = {};

                               @{$different_item}{@{$self->key_column_names}} =
                                   @{$reference_item}{@{$self->key_column_names}};

                               foreach ( @{$self->data_column_names} ) {
                                   $different_item->{'xt_'  .$_} = $reference_item->{$_};
                                   $different_item->{$self->attr_prefix . '_' . $_} = $comparison_item->{$_};
                                   $different_item->{'difference_'.$_} =
                                       $comparison_item->{$_} - $reference_item->{$_};
                               }

                               $self->stock->{different}->{$key} = $different_item;

                               delete $self->stock->{reference}->{$key};
                           }
                           else {
                               $self->stock->{identical}->{$key} =
                                   delete $self->stock->{reference}->{$key};
                           }
                        }
    );

    # Sweep any uncompared reference items into ref_only
    $self->stock->{ref_only} = delete $self->stock->{reference};

    # Knock out *_only entries that are entirely zero
    foreach my $stock_type (qw( ref comp )) {
        my $only_key = $stock_type.'_only';

      ITEM_KEY:
        foreach my $item_key (keys %{$self->stock->{$only_key}}) {
            foreach my $data_column (@{$self->data_column_names}) {
                next ITEM_KEY unless $self->stock->{$only_key}{$item_key}{$data_column} == 0;
            }

            # only found zeros for that $ref_key, move them aside
            my $zero_key = $stock_type.'_zero';

            $self->stock->{$zero_key}{$item_key} = delete $self->stock->{$only_key}{$item_key};
        }
}
}


# Since we parse our way through two CSV stock files with identical formats, and since much
# of that work is the same for each file, only differing in how we deal with each row of data
# once it's been checked and accepted, we implement this as a single subroutine that gets
# passed an anonymous function to do the differing portion.
sub _process_stock_file {
    my ($self,$filename,$fh,$column_names_by_number,$andthen) = @_;

    # If we're not passed a file handle then we expect the file name to be a full path and
    # we open it for reading.
    unless (defined($fh)) {
        open ($fh, '<:utf8', $filename)
            or die qq/Cannot read from '$filename': $!\n/;
    }

    my $file_columns = $self->stock_columns;

    my $csv = Text::CSV_XS->new( { binary => 1 } );

    $csv->types(          $file_columns->{types}  );

  HEADING:
    while (my $heading_row = $csv->getline( $fh )) {
        next HEADING unless $heading_row;

        $heading_row = [
            grep {$_}
            map {
                my $t=$_;
                $t=~s/(?:\p{C}|\p{M}|\p{Z})+//g;
                $t
            }
            @$heading_row
        ];

        # there needs to be at least something on the line
        next HEADING unless scalar(grep { $_ } @{$heading_row});
        next HEADING if    $heading_row->[0] =~ m{^\s*#}; # hey, a comment in a CSV file!

        my $column_count=@$heading_row;

        if ($column_count < $file_columns->{count}) {
            # short record
            $self->_note_error($filename,qq!too few columns -- got $column_count, expected $file_columns->{count} -- SKIPPING!);

            next HEADING;
        }
        elsif ($column_count > $file_columns->{count}) {
            # long record
            $self->_note_error($filename,qq!too many columns -- got $column_count, expected $file_columns->{count} -- IGNORING extra columns!);

            next HEADING;
        }

        for my $col_num (0..$column_count-1) {
            my $column_lc = lc $heading_row->[$col_num];

          CANDIDATE_COLUMN:
            foreach my $file_column (@{$file_columns->{columns}}) {
                # relies on no two names having a common prefix
                my $is_this_name = grep {
                    $column_lc =~ m{^$_}i
                } ($file_column->{name}, @{ $file_column->{alias} || [] });

                if ($is_this_name) {
                    $column_names_by_number->[$col_num] = $file_column->{name};

                    last CANDIDATE_COLUMN;
                }
            }
        }

        last HEADING;
    }

    $csv->column_names( $column_names_by_number );

  RECORD:
    while (my $stock_item = $csv->getline_hr( $fh )) {
        next RECORD unless $stock_item;

        # there needs to be at least something on the line
        next RECORD unless scalar(grep { $_ } @{$stock_item}{@{$file_columns->{names}}});
        next RECORD if    $stock_item->{$file_columns->{first_name}} =~ m{^\s*#}; # hey, a comment in a CSV file!

        my $column_count=keys %{$stock_item};

        if ($column_count < $file_columns->{count}) {
            # short record
            $self->_note_error($filename,qq{too few columns -- got $column_count, expected $file_columns->{count} -- SKIPPING});

            next RECORD;
        }
        elsif ($column_count > $file_columns->{count}) {
            # long record
            $self->_note_error($filename,qq{too many columns -- got $column_count, expected $file_columns->{count} -- IGNORING extra columns});
        }

        # Pokemon error handling...
        #
        # we don't bail out on the first error in a row,
        # because we gotta catch 'em all!

        my $apply_andthen = 1;

      COLUMN:
        foreach my $col_num (0..($file_columns->{count}-1)) {
            my $column_name = $column_names_by_number->[$col_num];

            unless (    exists $stock_item->{$column_name}
                    && defined $stock_item->{$column_name}) {
                $self->_note_error($filename,qq{couldn't find column with name '$column_name' -- SKIPPING});

                $apply_andthen = 0;

                next COLUMN;
            }

            # naughtily strips spaces from the field it's checking,
            # since we know we never want those, and we do get them

            $stock_item->{$column_name} = strip($stock_item->{$column_name});

            eval {
                my $col_ref = $file_columns->{columns}->[$col_num];

                die qq{Unable to check column $col_num\n}
                    unless exists $col_ref->{check};

                $col_ref->{check}($column_name,$stock_item->{$column_name});
            };

            if ($@) {
                chomp(my $error=$@);

                $self->_note_error($filename,qq{$error -- SKIPPING});

                $apply_andthen = 0;
            }
        }

        eval {
            $andthen->($stock_item) if $apply_andthen;
        };

        if ($@) {
            $self->_note_error($filename,$@);
        }
    }

    unless ($csv->eof) {
        $self->_note_error($filename,qq/Didn't make it to the end of '$filename': /.$csv->err_dia);
    }

    close $fh
        or $self->_note_error($filename,qq/Trouble closing '$filename': $!/);
}


# We accumulate errors as we go along, and deliver them at the end;
# this allows us to be more organized in how we whine about stuff.
sub _note_error {
    my ($self,$filename,@errors) = @_;

    croak 'BUG: error not provided' unless @errors;

    push @{$self->errors_by_filename->{$filename}},qq{$.: }.join(q{, },@errors);

    $self->error_count( $self->error_count + 1 );
}


# Return a string which is a summary stock reconciliation report suitable for use as an email body.
sub gen_summary {
    my ( $self, $starttime ) = @_;

    # If there were errors in the reconciliation then return an error report
    return $self->_gen_error_report($starttime) if $self->error_count;

    my $name = $self->stockholder_name;
    my @types = (
        [ "identical", "Items with no discrepancies in XTracker and $name" ],
        [ "different", "Items with different details in XTracker and $name" ],
        [ "ref_only",  "Items in XTracker only" ],
        [ "comp_only", "Items in $name only" ],
        [ "ref_zero",  "Zero items in XTracker" ],
        [ "comp_zero", "Zero items in $name" ],
    );

    my $formatted_time = strftime "%H:%M:%S on %A, %e %B %Y", localtime( $starttime );
    my $report = "Here are the results of the data reconciliation between XTracker and $name.\n" .
                 "This was run at $formatted_time.\n\n";

    my $discreps = $self->stock;
    for my $type ( @types ) {
        my ( $typename, $typelabel ) = @$type;
        my $subhash = $discreps->{$typename} // {};
        my $count = keys %$subhash;
        $report .= "$typelabel: $count\n";
    }

    $report .= "\nA file with detailed results is attached.\n";

    return $report;
}


# Return a string which is an error report suitable for use as an email body.
sub _gen_error_report {
    my ( $self, $starttime ) = @_;

    my $name = $self->stockholder_name;
    my $formatted_time = strftime "%H:%M:%S on %A, %e %B %Y", localtime( $starttime );
    my $report = "There were errors running the data reconciliation between XTracker and $name.\n" .
                 "This was run at $formatted_time.\n\n";

    foreach (sort keys %{$self->errors_by_filename}) {
        $report .= "Errors processing file $_:\n" . join("\n",@{$self->errors_by_filename->{$_}}) . "\n\n";
    }

    return $report;
}


# Generate a stock reconciliation detail report and return the full path of the file containing the report.
sub gen_report {
    my ( $self ) = @_;

    # If there were errors in the reconciliation then don't do anything
    return if $self->error_count;

    # Create a temporary directory where we will put our file. (We need a specific file name in a
    # temporary directory so this file will have right name when it's an attachment.)
    my $dir = tempdir( CLEANUP => 0 );
    $self->report_dir($dir);
    my $filename = File::Spec->catfile( $dir, $self->report_file );
    open (my $fh, '>:utf8', $filename)
            or die qq/Cannot open '$filename' for writing: $!\n/;

    # Start the report file with CSV column headers
    my $csv = Text::CSV_XS->new ({ binary => 1 })
        or die "Cannot use CSV: ".Text::CSV_XS->error_diag ();
    $csv->eol("\n");
    my $column_names = [ map {$_->{name}} @{$self->difference_columns->{columns}} ];
    $csv->print( $fh, $column_names );

    # Now write the data rows in CSV file. We do this for the five
    # types of discrepancies.
    for my $type ( qw{different ref_only comp_only} ) {

        # Get access to subhash for this discrepancy type, ditching
        # out if there isn't one.
        my $subhash = $self->stock->{$type};
        next unless $subhash;

        # Now we prepare for magically hacking the subhash so that it
        # looks the same for all types. For type 'different' the
        # subhash has data columns for XT and for the PRL/IWS as well
        # as difference counts, but for other types the subhash just
        # has counts for XT or for PRL/IWS. So we hack everything to
        # look like type 'different'.
        my ($this_pfx, $other_pfx, $negator);
        if ($type eq 'ref_only' || $type eq 'ref_zero') {
            ($this_pfx, $other_pfx) = ( 'xt', $self->attr_prefix );
            $negator = -1;
        }
        else {
            ($this_pfx, $other_pfx) = ( $self->attr_prefix, 'xt' );
            $negator = 1;
        }

        # Now go through all the subhashes for this type.
        my @items = sort keys %$subhash;
        for my $itemname (@items) {
            my $item = $subhash->{$itemname};

            # If we're not doing type 'different', then do the magical hacking.
            if ($type ne 'different') {
                for my $col (@{$self->data_column_names}) {
                    $item->{"${this_pfx}_${col}"} = $item->{$col};
                    $item->{"${other_pfx}_${col}"} = 0;
                    $item->{"difference_${col}"} = $item->{$col} * $negator;
                }
            }

            # Now print the (possibly hacked) subhash to the CSV file
            $csv->print( $fh, [ @{$item}{ @$column_names } ] );
        }
    }

    close($fh);
    return $filename;
}


# Email the report of discrepancies
sub email_report {
    my ( $self, $summary, $reportfile, $prl, $recipient ) = @_;

    my $details = $self->_gen_email_info($summary, $reportfile, $prl);

    eval { send_email( $details->{sender},
                       $details->{sender},
                       $recipient,
                       $details->{subject},
                       $details->{message_body},
                       'text',
                       $details->{attachment}
                     ); };
    die "Trouble sending e-mail: $@\n" if ($@);

    return;
}


# Return a hash containing the details for email to be sent
sub _gen_email_info {
    my ( $self, $summary, $reportfile, $prl ) = @_;

    my $dc = config_var('DistributionCentre', 'name')
        || die "Missing DistributionCentre/name in config";
    my $sender = config_var('Email','xtracker_email')
        || die "Missing Email/xtracker_email in config";

    $prl = "PRL '$prl'" unless $prl eq 'IWS';
    my $details = {
        sender       => $sender,
        subject      => "$dc XTracker Stock Reconciliation Report for $prl",
        message_body => $summary,
        attachment  => $reportfile ? [{ type => 'text/plain', filename => $reportfile }] : undef,
    };

    return $details;
}


# Method to clean up after reconciler
sub DEMOLISH {
  my $self = shift;
  return if( $self->keep_report_dir );
  my $dir = $self->report_dir or return;

  my $file = $self->report_file;
  my $filename = File::Spec->catfile( $dir, $file );
  unlink( $filename );
  rmdir( $dir );

  return;
}


__PACKAGE__->meta->make_immutable;

1;
