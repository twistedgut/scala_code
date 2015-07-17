package XT::Order::Parser;
use NAP::policy "tt";

use Module::PluginFinder;
use POSIX qw(strftime);
use File::Path qw/make_path/;
use Carp qw/ croak /;
use XTracker::Config::Local qw( config_var );


=head1 NAME

XT::Order::Parser

=head1 DESCRIPTION

Factory class for creating XT::Order::Parser::* objects based on the order
data format.

=head1 METHODS

=cut

# This factory implementation is inspired by:
# http://acidcycles.wordpress.com/2010/11/24/implementing-factories-in-perl/
my $finder = Module::PluginFinder->new(
    search_path => 'XT::Order::Parser',
    filter      => sub {
        my ($class, $args) = @_;
        $class->is_parsable($args);
    }
);

=head2 new_parser

    my $parser = XT::Order::Parser->new_parser({ data => $data });

Create a new parser. Parser returned will depened on format of order data
provided. For exmaple, if a hash is passed in, it will be assumed that the
order was in JSON format.

=cut

sub new_parser {
    my ( $class, $args ) = @_;

    # use the order data to determine which parser to construct
    # pass the full args to the parser constructor
    my $parser = $finder->construct( $args->{data}, $args );

    croak 'Parser [' . ref($parser) . '] does not conform to parser interface'
        unless $parser->meta->does_role( 'XT::Order::Role::Parser' );

    return $parser;
}

=head2 full_backup_filename

     my $filename = XT::Order::Parser->full_backup_pathname($type, $message))

$type is one of 'processed', 'waiting', 'problem' returns a full pathname
defined in xtracker.conf and a fiename of the format
[OrderConsumerName]_UTC_[DD.MMM.YYYY]-[hh].[mm].[ss]_order_[o_id]
eg.
JimmyChooOrder_UTC_19.May.2011-02.17.22_order_2156713057714415

=cut

sub full_backup_pathname {
    my ($self, $type, $message) = @_;

    my $basepath;
    if ($type eq 'processed') {
        $basepath = config_var('AMQOrders', 'proc_dir');
    }
    elsif ($type eq 'waiting') {
        $basepath = config_var('AMQOrders', 'waiting_dir');
    }
    elsif ($type eq 'problem') {
        $basepath = config_var('AMQOrders', 'problem_dir');
    }
    else {
        die 'Invalid path type '.pp($type);
    }

    my $fname_suffix = 'order_';
    if ( $message &&
        $message->{orders} &&
        $message->{orders}->[0] &&
        $message->{orders}->[0]->{o_id}) {
        $fname_suffix .= $message->{orders}->[0]->{o_id};
    }
    else {
        $fname_suffix .= 'WARNING-EMPTY';
    }

    ## Make sure the basepath is there
    unless (-d $basepath) {
        make_path($basepath);
    }

    ## Use the consumer package name to decide on the type
    my $filename = ref($self) || $self;
    $filename =~ s/.*\:\:(.*)$/$1/;

    $filename .= '_UTC_'.strftime "%d.%b.%Y-%H.%M.%S", gmtime();
    $filename .= '_'.$fname_suffix;

    return $basepath.'/'.$filename;
}

=head1 AUTHOR

Adam Taylor <adam.taylor@net-a-porter.com>

=cut

1;
