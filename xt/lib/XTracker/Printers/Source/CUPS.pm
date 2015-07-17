package XTracker::Printers::Source::CUPS;

use NAP::policy "tt", 'class';

use Config::Any;
use XTracker::Config::Local 'config_var';

extends 'XTracker::Printers::Source';

=head1 NAME

XTracker::Printers::Source::CUPS - CUPS source parsers for printers

=head1 DESCRIPTION

This class will parse CUPS's config to obtain a list of printers. Note that
configured printers will need to have values for 'C<XTLocation>',
'C<XTSection>' and 'C<XTType>', which map to 'C<location>', 'C<section>' and
'C<type>' respectively. Any printers without these values won't be picked up.

=head1 SYNOPSIS

use XTracker::Printers::Source::CUPS;

my $xpp = XTracker::Printers::Source::CUPS->new;

=cut

=head1 ATTRIBUTES

=head2 source_file

Specify the location of the config file containing the printer data. Defaults
to reading it from the config.

=cut

has source_file => (
    is      => 'ro',
    isa     => 'Str',
    default => sub { config_var(qw/Warehouse cups_printer_source/); },
);

=head1 METHODS

=head2 parse_source() : ArrayRef[HashRef]

See L<XTracker::Printers::Source::parse_source>.

=cut

sub parse_source {
    my $self = shift;

    my $file = $self->source_file;
    # I *should* be able to stack these (unless -f -r $file) according to
    # perlfunc but for some reason it doesn't seem to work. I'm probably doing
    # something stupid but I don't see it :(
    die "Could not read file '$file'\n" unless -f $file && -r _;

    my %merged_printer = map { %{$_//{}} } @{
        Config::Any->load_files({ use_ext => 1, files => [$file] })->[0]{$file}
    }{qw/Printer DefaultPrinter/};

    # Check we have no duplicate CUPS entries - they would cause printing
    # problems down the line
    if ( my @duplicates = grep { ref $merged_printer{$_} eq 'ARRAY' } keys %merged_printer ) {
        die sprintf(
            "Duplicate CUPS entries found in 'printers.conf' file: %s\n",
            join q{, }, @duplicates
        );
    }

    # Make sure that we only return printers that define all the keys we need.
    # This is to prevent importing legacy CUPS printers.
    my @required_keys = (qw{XTLocation XTSection XTType});
    return [ map { +{
        location => $merged_printer{$_}{XTLocation},
        lp_name  => $_,
        section  => $merged_printer{$_}{XTSection},
        type     => $merged_printer{$_}{XTType},
    } } grep {
        my @array = grep { defined } @{$merged_printer{$_}}{@required_keys};
        @array == @required_keys;
    } keys %merged_printer ];
}
