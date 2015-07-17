package XTracker::Admin::SelectPrinterStation;

use strict;
use warnings;

use List::MoreUtils qw[uniq];
use URI;

use XTracker::Error;
use XTracker::Handler;
use XTracker::PrinterMatrix;
use XTracker::Printers;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my ( $section, $subsection, $channel_id )
        = @{$handler->{param_of}}{qw{section subsection channel_id}};

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Select Printer Station';
    $handler->{data}{channel_id}    = $channel_id;
    $handler->{data}{content}       = 'user/selectprinterstation.tt';

    # As we are gradually porting printers to the 'new' way, we will need to
    # keep supporting both ways of displaying printer lists. The 'old' way can
    # be deleted once everything has been ported.
    my @ps = new_location_list($subsection);

    @ps = legacy_location_list($handler) unless @ps;

    my @ps_sorted;
    if (@ps) {
        # Printer Stations are called things like "Printer Station Foo 01".
        # But sometimes they are called "Printer Station Foo Spare 01" or
        # something like that.
        # Update - we now also support stations with no digits on the end, so
        # the digit match needs to be optional.
        # This code attempts to deal with both of those alternatives and
        # sort the strings into a sensible order.
        @ps_sorted = sort { ## no critic(RequireSimpleSortBlock)
            my ($a_txt, $a_num) = $a =~ /(.+?)(\d+)?$/;
            my ($b_txt, $b_num) = $b =~ /(.+?)(\d+)?$/;
            ($a_txt cmp $b_txt) || ($a_num <=> $b_num);
        } uniq @ps;
    }
    foreach my $ps_name ( @ps_sorted ) {
        next unless defined $ps_name;
        $ps_name =~ s/_/ /g;
    }
    $handler->{data}{ps_list} = \@ps_sorted;

    if ( !@ps_sorted ) {
        xt_warn( join q{ },
            'There are no available printers for the section you are in.',
            'Please get in touch with Service Desk to resolve this.'
        );
        return $handler->redirect_to( '/Home' );
    }
    elsif( $handler->{param_of}{force_selection} || @ps_sorted > 1){
        return $handler->process_template;
    }
    else {
        # FIXME: We're doing a GET here to set a printer station. This is wrong
        # - we should merge the handler below with this one so we can set this
        # in a POST.
        my ($ps_name)=@ps;
        my $uri = URI->new('/Admin/Actions/SetPrinterStation');
        $uri->query_form(
            section    => $section,
            subsection => $subsection,
            ps_name    => $ps_name,
            channel_id => $channel_id,
        );
        return $handler->redirect_to($uri);
    }
}

# Remove this sub once we have just 'one' way of getting location lists
sub new_location_list {
    my $subsection = shift;

    # A fugly map... remove/improve as we port more stuff over. We should
    # probably have a url parameter that explicitly sets the printer section.
    return map { $_->name }
        XTracker::Printers->new->locations_for_section(
            new_printer_section_map()->{$subsection}
        );
}

# A legacy sub, remove this once we've ported all printers to use the new
# printer framework
sub legacy_location_list {
    my $handler = shift;
    my $schema = $handler->schema;
    my $channels = $schema->resultset('Public::Channel');
    my $printer_matrix = XTracker::PrinterMatrix->new({schema => $schema});

    my @ps;
    foreach my $channel ( $channels->all ){
        $handler->{data}{channel_list}{$channel->id} = lc($channel->name);
        my $printer_stations = $printer_matrix->get_printers_by_section($handler->{data}{subsection} , $channel->id );
        next unless $printer_stations;# this shouldn't happen, but does.
        push @ps, ref $printer_stations && ref $printer_stations eq 'ARRAY'
                ? @$printer_stations
                : $printer_stations;
    }

    return @ps;
}

sub new_printer_section_map {
    return {
        Airwaybill     => 'airwaybill',
        ItemCount      => 'item_count',
        QualityControl => 'goods_in_qc',
        Quarantine     => 'rtv_workstation',
        Recode         => 'recode',
        ReturnsIn      => 'returns_in',
        ReturnsQC      => 'returns_qc',
        StockIn        => 'stock_in',
        Surplus        => 'surplus',
    };
}

1;
