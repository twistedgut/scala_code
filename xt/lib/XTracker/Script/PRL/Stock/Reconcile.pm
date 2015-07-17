package XTracker::Script::PRL::Stock::Reconcile;
use NAP::policy "class", "tt";
extends "XTracker::Script";

with(
    "MooseX::Getopt",
    "XTracker::Script::Feature::Schema",
    "XTracker::Script::Feature::Verbose",

    "XT::Data::StockReconcile::PrlStockReconcile",
);

=head1 NAME

XTracker::Script::PRL::Stock::Reconcile

=head1 DESCRIPTION

Make a stock report in XT, then reconcile that against a PRL stock
report file and report any differences.

=cut

# Don't die with full stack traces
__PACKAGE__->meta->error_class("Moose::Error::Human");


use XTracker::Config::Local 'config_var';
use XT::Domain::PRLs; # PRLName

has [
    "+reconciler",
    "+schema",
    "+dbh",
    "+report_file",
    "+summary",
] => ( traits => [ "NoGetopt" ] );


has prl => (
    is       => "ro",
    isa      => "PRLName",
    required => 1,
);

has prl_stock_file => (
    is       => "ro",
    isa      => "Str",
    required => 1,
);

=head1 METHODS

=head2 invoke

=cut

sub invoke {
    my ($self, $args) = @_;

    my $prl_stock_file = $self->prl_stock_file;
    my $prl = XT::Domain::get_prl_from_name({
        prl_name => $self->prl,
    });
    $self->inform("*** Reconcile XT stock against the ($prl) PRL stock ***\n");

    $self->inform("PRL file: ($prl_stock_file)\n");
    -r $prl_stock_file or die("Could not read PRL file ($prl_stock_file)\n");

    $self->inform("Generating XT Stock report for ($prl) PRL...\n");

    $self->gen_xt_stockfile( $prl );
    my $xt_file_name = $self->xt_stockfile_fullpath( $prl->amq_identifier );
    $self->inform("XT file: ($xt_file_name)\n");

    $self->inform("Reconciling XT Stock report against ($prl) PRL...\n");
    $self->reconcile_against_prl({
        amq_identifier => $prl->amq_identifier,
        prl_stock_path => $prl_stock_file,
    });
    $self->inform("\n\n" . $self->summary);

    $self->reconciler->keep_report_dir(1);
    my $report_file = $self->report_file;
    $self->inform("Report file ($report_file)\n");

    return 0;
}

