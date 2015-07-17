package XTracker::Document::Role::LogPrintDoc;

use NAP::policy 'role';

requires 'log_document';

=head1 NAME

XTracker::Document::Role::LogPrintDoc

=head1 DESCRIPTION

For the documents that require reprinting, usually the
first print is log into DB so when the reprinting is done
the data will be retrieved from DB

=cut


around print_at_location => sub {
    my ( $orig, $class, @args ) = @_;

    my $printer_name = $args[0] //
        confess "No printer name provided, skiping document logging";

    $class->log_document($printer_name);

    # Move forward with the action
    $class->$orig(@args);
}
