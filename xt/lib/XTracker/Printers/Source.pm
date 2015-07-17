package XTracker::Printers::Source;

use NAP::policy qw/tt class/;

use Module::Runtime 'require_module';

use XTracker::Config::Local 'config_var';
use XT::Data::Printer;

=head1 NAME

XTracker::Printers::Source - A base class for printer source classes.

=head1 DESCRIPTION

Extend this class to create your new printer source classes.

=head1 SYNOPSIS

    package XTracker::Printers::Source::Foo;

    use NAP::policy qw/tt class/;
    extends 'XTracker::Printers::Source';

    sub parse_source { ... }

=head1 ABSTRACT METHODS

=head2 parse_source() : ArrayRef[HashRef]

Your subclass will need to provide its own C<parse_source> method. This will
have to return an arrayref of hashrefs. Each hashref will be used to
instantiate a new L<XT::Data::Printer> object.

=cut

sub parse_source { die 'Abstract method'; }

=head1 ATTRIBUTES

=head2 printers

This is an arrayref of L<XT::Data::Printer> objects.

=cut

has printers => (
    is => 'ro',
    isa => 'ArrayRef[XT::Data::Printer]',
    builder => '_build_printers',
    lazy => 1,
);
sub _build_printers {
    my $self = shift;
    return [
        map { XT::Data::Printer->new(%$_) }
        map { ref $_ eq 'ARRAY' ? @$_ : $_ } $self->parse_source
    ];
}

=head2 new_from_config

Returns a new subclass of the type defined in the config.

=cut

sub new_from_config {
    my ($class,%args) = @_;
    my $subclass = join q{::},
        $class, config_var(qw/Warehouse printer_source/);
    require_module($subclass);
    return $subclass->new(%args);
}
