package XT::JQ::DC::Receive::StockControl::ReconcilePrlInventory;
# vim: ts=8 sts=4 et sw=4 sr sta
use NAP::policy "tt", "class";
extends 'XT::JQ::Worker';
with 'XT::Data::StockReconcile::PrlStockReconcile';

=head1 NAME

XT::JQ::DC::Receive::Generate::ReconcilePrlInventory

=head1 DESCRIPTION

Expected Payload should look like:

    my $job_payload = {
       prl       => $prl,
       file_name => $file_name,
    };

=cut

use File::Spec;
use Moose::Util::TypeConstraints;
use MooseX::Types::Moose qw(Str Int Num Undef ArrayRef HashRef);
use MooseX::Types::Structured qw(Dict Optional);

use XTracker::Logfile qw( xt_logger );
use XTracker::Config::Local 'config_var';
use XT::Domain::PRLs;


has payload => (
    is => 'ro',
    isa => Dict[
        function => Str,
        prl => Str,
        file_name => Optional[Str],
    ],
    required => 1
);

has logger => (
    is => 'rw',
    default => sub { return xt_logger('TheSchwartz'); }
);


sub do_the_task {
    my ($self, $job) = @_;

    # Get info from job payload
    my $function = $self->payload->{function};
    # Note: Although the field in the message payload is called
    # 'prl', it actually contains the AMQ identifier.
    my $amq_identifier = $self->payload->{prl};
    my $file_name = $self->payload->{file_name};

    my $prl = XT::Domain::PRLs::get_prl_from_amq_identifier({
        amq_identifier => $amq_identifier,
    });

    # Call method to do the real work
    if ($function eq 'dump') {
        $self->gen_xt_stockfile( $prl );
    }
    elsif ($function eq 'reconcile') {
        $self->reconcile_against_prl({
            amq_identifier => $amq_identifier,
            file_name      => $file_name,
        });
        $self->email_report_to_recipient( $amq_identifier );
    }

    return;
}

sub check_job_payload {
    my ($self, $job) = @_;
    return ();
}

