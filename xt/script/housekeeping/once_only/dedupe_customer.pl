#!/opt/xt/xt-perl/bin/perl -w
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use strict;
use warnings;
use lib '/opt/xt/deploy/xtracker/lib/';
use FindBin::libs qw( base=lib_dynamic );
use feature "state";

use XTracker::Config::Local     qw( config_var );
use XTracker::Database          qw( get_database_handle );
use XTracker::Constants::FromDB qw( :note_type :customer_category );
use XTracker::Constants         qw( :application );
use XTracker::EmailFunctions    qw( send_email );

use Log::Log4perl               qw( get_logger );

use DateTime;
use IO::File;
use Text::CSV;

use Data::Dump qw( pp );


my $dc          = config_var( 'DistributionCentre', 'name' );
my $file_path   = "/tmp/dedupe_customer_output/";

# set-up the directory to output
# the files and log file to
if ( !-d $file_path ) {
    mkdir( $file_path ) or die "Can't create directory: $file_path";
}

my $logger  = _setup_logger( $dc );
my $now     = DateTime->now( time_zone => 'local' );

$logger->info( "-" x 50 );
$logger->info( "$dc - (attempt 2) START DE-DUPLICATE CUSTOMERS - " . $now );
$logger->info( "Outputting to: $file_path" );

my ( $output_fname, $relation_fname );
my @dupes;

eval {
    my $schema  = get_database_handle( { name => 'xtracker_schema', type => 'transaction' } );
    my $dbh     = $schema->storage->dbh;

    my $customer_rs     = $schema->resultset('Public::Customer');
    my $channel_rs      = $schema->resultset('Public::Channel');
    my $credit_logs_rs  = $schema->resultset('Public::CustomerCreditLog');

    my $upd_actions     = _prepare_cursors( $dbh );

    # fields in the 'customer' table that I want to do something
    # different with and so don't get automatically updated
    my %exception_fields= (
            category                => 1,
            category_id             => 1,
            ddu_terms_accepted      => 1,
            legacy_comment          => 1,
            credit_check            => 1,
            no_marketing_contact    => 1,
            no_signature_required   => 1,
        );

    @dupes  = $customer_rs
                    ->search(
                            {},
                            {
                                select  => [ qw( is_customer_number channel_id count ) ],
                                as      => [ qw( is_customer_number channel_id dupe_count ) ],
                                group_by=> [ qw( is_customer_number channel_id ) ],
                                having  => 'count(*) > 1',
                                order_by=> 'is_customer_number',
                            }
                        )->all;

    $logger->info( "Number of Customers: ".@dupes );

    foreach my $dupe ( @dupes ) {
        $schema->txn_do( sub {
            my $channel     = $channel_rs->find( $dupe->channel_id );

            $logger->info( "Customer Number: ".$dupe->is_customer_number
                           . ", for Channel: ".$channel->name
                           . ", Number of Duplicates: " . $dupe->get_column('dupe_count') );

            my %customer_record;
            my @customers   = $customer_rs->search(
                                            {
                                                is_customer_number => $dupe->is_customer_number,
                                                channel_id => $channel->id,
                                            },
                                            {
                                                order_by    => 'id ASC',
                                            }
                                        )->all;

            my $first_customer;
            my @to_delete;

            foreach my $customer ( @customers ) {
                my $category    = $customer->category->category;
                if ( !%customer_record ) {
                    $logger->info( "Orig Id: " . $customer->id
                                   . ", Category: " . $category
                                   . ", Orders: " . $customer->orders->count
                                   . ", Reservations: " . $customer->reservations->count
                                   . ", Customer Notes: " . $customer->customer_notes->count
                                   . ", Customer Flags: ".$customer->customer_flags->count );

                    $first_customer = $customer;
                    %customer_record    = (
                                title       => $customer->title,
                                first_name  => $customer->first_name,
                                last_name   => $customer->last_name,
                                email       => $customer->email,
                                category_id => $customer->category_id,
                                category    => $category,
                                telephone_1 => $customer->telephone_1,
                                telephone_2 => $customer->telephone_2,
                                telephone_3 => $customer->telephone_3,
                                ddu_terms_accepted => $customer->ddu_terms_accepted,            # boolean
                                legacy_comment => $customer->legacy_comment,                    # text
                                credit_check=> $customer->credit_check,                         # timestamp
                                no_marketing_contact => $customer->no_marketing_contact,        # timestamp
                                no_signature_required => $customer->no_signature_required,      # boolean
                            );
                    _output_record_to_csv( 'start', $customer, $upd_actions );
                }
                else {
                    # update fields in the First Customer Record that are not in the exceptions list
                    foreach my $key ( grep { !exists( $exception_fields{ $_ } )  } keys %customer_record ) {
                        if ( $customer->$key && ( $customer_record{ $key } ne $customer->$key ) ) {
                            # if it's got a value in the new rec that's different to what's currently there then update it
                            $customer_record{ $key }    = $customer->$key;
                        }
                    }
                    # don't overwrite a non 'None' category with 'None'
                    if ( $category ne 'None' && $customer_record{'category'} ne $category ) {
                        $customer_record{'category'}    = $category;
                        $customer_record{'category_id'} = $customer->category_id;
                    }
                    # don't overwrite a TRUE ddu_terms_accepted with FALSE
                    if ( $customer->ddu_terms_accepted ) {
                        $customer_record{ddu_terms_accepted}    = $customer->ddu_terms_accepted;
                    }
                    # append any legacy_comment's
                    if ( $customer->legacy_comment ) {
                        $customer_record{legacy_comment}    .= ' '      if ( $customer_record{legacy_comment} );    # seperate last comments with new
                        $customer_record{legacy_comment}    .= $customer->legacy_comment;
                    }
                    # only update credit_check if new value is more recent
                    if ( defined $customer->credit_check ) {
                        if ( !defined $customer_record{'credit_check'}
                               || ( DateTime->compare( $customer->credit_check, $customer_record{'credit_check'} ) > 0 ) ) {
                            $customer_record{'credit_check'}    = $customer->credit_check;
                        }
                    }
                    # only update no_marketing_contact if new value is more recent
                    if ( defined $customer->no_marketing_contact ) {
                        if ( !defined $customer_record{'no_marketing_contact'}
                               || ( DateTime->compare( $customer->no_marketing_contact, $customer_record{'no_marketing_contact'} ) > 0 ) ) {
                            $customer_record{'no_marketing_contact'}    = $customer->no_marketing_contact;
                        }
                    }
                    # don't overwrite a TRUE no_signature_required with FALSE
                    if ( $customer->no_signature_required ) {
                        $customer_record{no_signature_required} = $customer->no_signature_required;
                    }

                    # this record will need to be deleted
                    push @to_delete, $customer;

                    # out this record so we know what it looked like
                    _output_record_to_csv( 'dupe', $customer, $upd_actions );
                }
            }

            # now delete all of the duplicate customer records
            foreach my $rec ( @to_delete ) {
                $logger->info( "Dupe Id: " . $rec->id
                               . ", Category: " . $rec->category->category
                               . ", Orders: " . $rec->orders->count
                               . ", Reservations: " . $rec->reservations->count
                               . ", Customer Notes: " . $rec->customer_notes->count
                               . ", Customer Flags: ".$rec->customer_flags->count );

                $rec->reservations->update( { customer_id => $first_customer->id } );
                $rec->orders->update( { customer_id => $first_customer->id } );
                $rec->customer_notes->update( { customer_id => $first_customer->id } );

                # check dupe's 'customer_flag' table against original customer
                my @cusflags    = $rec->customer_flags->search()->all;
                foreach my $cusflag ( @cusflags ) {
                    if ( $first_customer->customer_flags->search( { flag_id => $cusflag->flag_id } )->count() ) {
                        # same flag exists on First Customer, so delete duplicate's
                        $cusflag->delete;
                    }
                    else {
                        # same flag doesn't exist on First Customer, so update duplicate's 'customer_id'
                        $cusflag->update( { customer_id => $first_customer->id } );
                    }
                }

                if ( defined $rec->customer_credit ) {
                    my $credit_logs = $credit_logs_rs->search( { customer_id => $rec->id } );
                    $credit_logs->update( { customer_id => $first_customer->id } );
                    if ( defined $first_customer->customer_credit ) {
                        $first_customer->customer_credit->update( { credit => $first_customer->customer_credit->credit
                                                                              + $rec->customer_credit->credit } );
                        $rec->customer_credit->delete;
                    }
                    else {
                        $rec->customer_credit->update( { customer_id => $first_customer->id } )
                    }
                }

                $upd_actions->{update_segment}( $rec->id, $first_customer->id );
                $upd_actions->{update_cat_log}( $rec->id, $first_customer->id );

                # delete the Duplicate Customer Record
                $rec->delete;
            }

            delete $customer_record{'category'};            # don't need the Category description anymore just the 'category_id'
            $first_customer->update( \%customer_record );   # update the original customer record with all the new details
            $first_customer->create_related( 'customer_notes', {
                                                    note_type_id    => $NOTE_TYPE__GENERAL,
                                                    operator_id     => $APPLICATION_OPERATOR_ID,
                                                    date            => \"now()",
                                                    note            => "DUPE FIX: This Customer had ".$dupe->get_column('dupe_count')." duplicate records with the same Customer Number, it has now been cleaned up to only have one.",
                                                } );

            # output the original record with the changes (if there were any) so we can see how it was changed
            _output_record_to_csv( 'last', $first_customer->discard_changes, $upd_actions );
        } );
    }
};
if ( my $err = $@ ) {
    $logger->error( $err );
}

eval {
    # close the output file
    ( $output_fname, $relation_fname )  = _output_record_to_csv('close');
};
if ( my $err = $@ ) {
    $logger->error( $err );
}

$logger->info( "Customers Deduped" );

# add a unique index to the customer table so this sort of thing doesn't happen again
my $sql =<<SQL
CREATE UNIQUE INDEX customer_idx_is_customer_number__channel_id ON customer( is_customer_number, channel_id )
SQL
;
$logger->info( "Now MANUALLY Add Unique Index:\n\n$sql" );

my $outfile = {};
if ( $output_fname ) {
    $outfile    = {
            type => 'text/csv',
            filename => $output_fname,
        };
}
my $relationfile = {};
if ( $relation_fname ) {
    $relationfile   = {
            type => 'text/csv',
            filename => $relation_fname,
        };
}

# email both the log file and the output file, so people know what happened
send_email(
        config_var('Email', 'xtracker_email'),
        config_var('Email', 'xtracker_email'),
        'andrew.beech@net-a-porter.com,cando-team@net-a-porter.com,selina.kantepudi@net-a-porter.com',
        "$dc - Dedupe Customer BAU Script - " . $now->ymd("-") . " " . $now->hms(":"),
        "There were ".@dupes." Duplicate Customers. Attached '.csv' files are actually pipe ('|') delimited.",
        "text",
        [
            {
                type => 'text/plain',
                filename => "${file_path}${dc}_dedupe_customer.log",
            },
            $outfile,
            $relationfile,
        ],
    );
$logger->info( "Email Sent" );

$logger->info( "END" );

#--------------------------------------------------------------------

sub _prepare_cursors {
    my $dbh     = shift;

    my %cursors;
    my %actions;

    $cursors{get_segment}       = $dbh->prepare( "SELECT COUNT(*) FROM customer_segment WHERE customer_id = ?" );
    $cursors{upd_segment}       = $dbh->prepare( "UPDATE customer_segment SET customer_id = ? WHERE customer_id = ?" );
    $cursors{upd_segment_log}   = $dbh->prepare( "UPDATE customer_segment_log SET customer_id = ? WHERE customer_id = ?" );
    $cursors{del_segment}       = $dbh->prepare( "DELETE FROM customer_segment WHERE customer_id = ?" );
    $cursors{del_segment_log}   = $dbh->prepare( "DELETE FROM customer_segment_log WHERE customer_id = ?" );
    $cursors{upd_category_log}  = $dbh->prepare( "UPDATE customer_category_log SET customer_id = ? WHERE customer_id = ?" );
    $cursors{get_flag}          = $dbh->prepare( "SELECT description FROM flag WHERE id = ?" );

    $actions{update_segment}= sub {
                        my ( $cust_id, $orig_id )   = @_;

                        # see if there are any 'customer_segment' records for the original customer rec
                        $cursors{get_segment}->execute( $orig_id );
                        my ( $count )   = $cursors{get_segment}->fetchrow_array();
                        if ( $count ) {
                            # if there are any records for the original customer rec
                            # then just delete the records for the new customer as this
                            # table is not used anymore so no point in worrying about it
                            # but no harm in trying to clean it up if possible
                            $cursors{del_segment}->execute( $cust_id );
                            $cursors{del_segment_log}->execute( $cust_id );
                        }
                        else {
                            # if there weren't any records for the original customer then update the
                            # new ones to be for the original just to keep things as tidy as we can
                            $cursors{upd_segment}->execute( $orig_id, $cust_id );
                            $cursors{upd_segment_log}->execute( $orig_id, $cust_id );
                        }

                        return;
                    };

    $actions{update_cat_log}= sub {
                        my ( $cust_id, $orig_id )   = @_;

                        $cursors{upd_category_log}->execute( $orig_id, $cust_id );

                        return;
                    };
    $actions{get_flag}      = sub {
                        my $flag_id = shift;
                        $cursors{get_flag}->execute( $flag_id );
                        my ( $flag )    = $cursors{get_flag}->fetchrow_array();
                        return $flag;
                    };

    return \%actions;
}

sub _output_record_to_csv {
    my ( $action, $record, $cursors )   = @_;

    my $sep_char    = '|';

    state $dc   = config_var( 'DistributionCentre', 'name' );
    state @fields;
    state $csv  = Text::CSV->new( {
                                    sep_char    => $sep_char,
                                    quote_char  => '"',
                                    escape_char => '\\',
                                    eol         => "\n",
                                    binary      => 1,
                                    always_quote=> 1,
                                } );
    state $now          = DateTime->now( time_zone => 'local' );
    state $file_suffix  = $now->ymd('') . "_" . $now->hms('') . ".csv";

    state $file_name    = $file_path . $dc."_duplicate_customers_update_".$file_suffix;
    state $file         = IO::File->new("> $file_name") or die "Can't create file: $file_name";

    # used to store the list of Orders, Reservations & Customer Notes for the Dupe Customer Records
    state $relation_file_name   = $file_path . $dc."_duplicate_customer_relations_update_".$file_suffix;
    state $relation_file        = IO::File->new("> $relation_file_name") or die "Can't create file: $file_name";

    state @lines;
    state @relation_lines;

    # save the first category id
    state $first_category_id;

    if ( !@fields ) {
        @fields = ( qw(
                id
                is_customer_number
                created
                title
                first_name
                last_name
                email
                category_id
                telephone_1
                telephone_2
                telephone_3
                ddu_terms_accepted
                legacy_comment
                credit_check
                no_marketing_contact
                no_signature_required
            ) );
        $csv->print( $file, [ 'Type', @fields, 'Category', 'Sales Channel' ] );

        # headers for the Customer Relations File
        $csv->print( $relation_file, [ 'Customer Id', 'Customer Nr', 'Relation', 'Relation Id', 'Date', 'Relation Other' ] );
    }

    CASE: {
        if ( $action eq "start" || $action eq "close" ) {
            if ( @lines ) {
                print $file join( '', @lines );
                # empty line to divide Customers
                print $file "\n"        if ( $action ne "close" );
                @lines          = ();
            }
            if ( @relation_lines ) {
                print $relation_file join( '', @relation_lines );
                # empty line to divide Customer Relations
                print $relation_file "\n"        if ( $action ne "close" );
                @relation_lines = ();
            }
            $first_category_id  = $record->category_id      if ( $action eq "start" );
        }

        if ( $action eq "close" ) {
            $file->close();
            $relation_file->close();
            return ( $file_name, $relation_file_name );
        }

        # output the relation's for the Duplicate Customer
        if ( $action eq "dupe" ) {
            # Output Orders
            my @relations   = $record->orders->search( {}, { order_by => 'id' } )->all;
            foreach my $relation ( @relations ) {
                $csv->combine(
                                $record->id,
                                $record->is_customer_number,
                                'orders',
                                $relation->id,
                                $relation->date,
                                $relation->order_nr,
                            );
                push @relation_lines, $csv->string();
            }
            # Output Reservations
            @relations      = $record->reservations->search( {}, { order_by => 'id' } )->all;
            foreach my $relation ( @relations ) {
                $csv->combine(
                                $record->id,
                                $record->is_customer_number,
                                'reservation',
                                $relation->id,
                                $relation->date_created,
                                $relation->variant->sku,
                            );
                push @relation_lines, $csv->string();
            }
            # Output Customer Notes
            @relations      = $record->customer_notes->search( {}, { order_by => 'id' } )->all;
            foreach my $relation ( @relations ) {
                my $note= $relation->note;
                $note   =~ s/[\n\r]//g;
                $csv->combine(
                                $record->id,
                                $record->is_customer_number,
                                'customer_note',
                                $relation->id,
                                $relation->date,
                                $note,
                            );
                push @relation_lines, $csv->string();
            }
            # Output Customer Flag
            @relations      = $record->customer_flags->search( {}, { order_by => 'id' } )->all;
            foreach my $relation ( @relations ) {
                $csv->combine(
                                $record->id,
                                $record->is_customer_number,
                                'customer_flag',
                                $relation->id,
                                '',
                                $relation->flag_id . ' - ' . $cursors->{get_flag}( $relation->flag_id ),
                            );
                push @relation_lines, $csv->string();
            }
        }

        $csv->combine( ( map { $record->$_ } @fields ), $record->category->category, $record->channel->name );
        my $line = $csv->string();

        if ( $action eq 'last' ) {
            my $last_type   = 'UPDATED';
            if ( $lines[0] ne $line ) {
                $last_type  .= '-IS_DIFF_TO_FIRST';
            }
            $lines[0]   = "FIRST$sep_char" . $lines[0];     # prefix the first line
            foreach my $idx ( 1..$#lines ) {
                # prefix all the dupes
                $lines[$idx]    = "DUPE$sep_char" . $lines[$idx];
            }
            $line   = $last_type.$sep_char.$line;           # prefix the last line

            # check if the Customer's Category has Changed - except from 'None'
            if ( $first_category_id != $CUSTOMER_CATEGORY__NONE
                 && $first_category_id != $record->category_id ) {
                # if so append the last line with a notifier
                chomp($line);
                $line   .= $sep_char . '"*** CATEGORY CHANGED ***"' . "\n";
            }
        }

        push @lines, $line;
    };

    return;
}

sub _setup_logger {
    my $dc  = shift;

    my $conf    = qq(
            log4perl.category.DedupeCust                = INFO, DedupeCust, Screen

            log4perl.appender.DedupeCust                = Log::Log4perl::Appender::File
            log4perl.appender.DedupeCust.filename       = ${file_path}${dc}_dedupe_customer.log
            log4perl.appender.DedupeCust.DatePattern    = yyyy-MM-dd
            log4perl.appender.DedupeCust.max            = 7
            log4perl.appender.DedupeCust.TZ             = GMT
            log4perl.appender.DedupeCust.mode           = append
            log4perl.appender.DedupeCust.layout         = PatternLayout
            log4perl.appender.DedupeCust.layout.ConversionPattern   = [\%d] <\%M> \%6p: \%m\%n

            log4perl.appender.Screen                    = Log::Log4perl::Appender::Screen
            log4perl.appender.Screen.stderr             = 0
            log4perl.appender.Screen.layout             = Log::Log4perl::Layout::SimpleLayout
        );

    Log::Log4perl::init( \$conf );

    return get_logger( 'DedupeCust' );
}
