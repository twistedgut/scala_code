package XTracker::Printers::Source::File;

use NAP::policy "tt", 'class';

use Config::Any;
use XTracker::Config::Local 'config_var';

extends 'XTracker::Printers::Source';

=head1 NAME

XTracker::Printers::Source::File - File source parser for printers

=head1 DESCRIPTION

A class that will parse a file with printer information. This file supports
any config L<Config::Any> can parse, although using L<Config::General> for now.
The file needs to look like one or more of the following block:

  <printer>
    lp_name         lp_name
    location        location
    section         shipping            # this is an enum
    type            doc_printer         # this is an enum
  </printer>

=cut

=head1 ATTRIBUTES

=head2 source_file

Specify the location of the config file containing the printer data. Defaults
to reading it from the config.

=cut

has source_file => (
    is  => 'ro',
    isa => 'Str',
    default => sub { config_var(qw/Warehouse file_printer_source/); },
);

=head1 METHODS

=head2 parse_source() : ArrayRef[HashRef]

See L<XTracker::Printers::Source::parse_source>.

=cut

sub parse_source {
    my $self = shift;

    my $file = $self->source_file;
    die "Could not read file '$file'"
        unless ( grep { -f $_ && -r $_ } $file );

    return [ map { $_ && ref $_ eq 'ARRAY' ? @$_ : $_ } Config::Any
        ->load_files({
            use_ext => 1,
            files => [$file],
            driver_args => { General => { -IncludeRelative => 1, }, },
        })->[0]
        ->{$file}
        ->{printer} ];
}
