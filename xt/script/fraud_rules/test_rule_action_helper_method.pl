#!/opt/xt/xt-perl/bin/perl
use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XT::FraudRules::Actions::HelperMethod;
use XTracker::Database qw(
    schema_handle
);

if ( my $expression = shift ) {
# If a parameter was passed

    my $helper = XT::FraudRules::Actions::HelperMethod->new(
        schema => schema_handle()
    );

    if ( $helper->compile( $expression ) ) {
    # If the expression compiles.

        if ( my $result = $helper->execute ) {
        # If it executes.

            print "\nWe got a " . $result->result_source->source_name . ' ResultSet with ' . $result->count . " rows:\n\n";
            my $count = 0;

            while ( my $row = $result->next ) {
            # Display each row.

                print 'ROW: ' . ++$count . "\n";
                my %columns = $row->get_columns;

                foreach my $column ( sort keys %columns ) {
                # Display each column for the row.

                    my $value = $columns{$column} || '<EMPTY>';
                    print "  $column: $value\n";

                }

                print "\n";

            }

        } else {

            show_error( $helper );

        }

    } else {

        show_error( $helper );

    }

} else {

    print "Usage: $0 <expression>\n";

}

sub show_error {
    my ( $helper ) = @_;

    my $error = $helper->last_error;

    if ( $error ) {

        print "ERROR: $error\n"

    } else {

        print "ERROR: Something went wrong, but there was no error message!\n";

    }

}

