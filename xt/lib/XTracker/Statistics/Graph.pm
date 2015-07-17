package XTracker::Statistics::Graph;

use warnings;
use strict;
use Carp;
use Fatal qw( open close );

use version; our $VERSION = qv('0.0.2');

use Perl6::Say;
use Perl6::Export::Attrs;
use GD;
use GD::Graph::bars;
use GD::Graph::bars3d;
use GD::Graph::hbars;
use GD::Graph::lines;
use XML::LibXML;
use XML::Writer;
use Data::Dump qw( pp );
use List::Util qw( max );
use Math::Round qw( nearest_ceil );

use XTracker::Config::Local qw( config_var );


sub read_graph_file :Export {

    my ( $file, $axis_value ) = @_;

    # parse graph data file
    my $parser = XML::LibXML->new();
    my $tree = $parser->parse_file($file);
    my $root = $tree->getDocumentElement;

    my $labels_ref = _extract_labels($root);

    # extract data points (using DOM)
    my @data      = ();
    my @legend    = ();
    my @data_sets = $root->getElementsByTagName('dataset');

    # only extract y axis labels once
    push @data, _extract_axis_labels( $data_sets[0], $axis_value );

    # extract data points for each data set
    foreach my $data_set ( @data_sets ){
        push @legend, _extract_legend( $data_set );
        push @data,   _extract_data_points( $data_set );
    }

    # return graph data structure
    return (\@data, $labels_ref, \@legend);
}


sub write_graph_image :Export {

    my ($data_ref, $label_ref, $graph_type, $canvas_size, $legend, $img_file, $settings )   = @_;

    my %canvas = ( large    => [ 720, 260 ],
                   med      => [ 250, 200 ],
                   small    => [ 100, 75  ],
                   dc_home  => [ 819, 260 ] );

    my %type_dispatch = ( bars   => sub { GD::Graph::bars->new( @_ ) },
                          bars3d => sub { GD::Graph::bars3d->new( @_ ) },
                          hbars  => sub { GD::Graph::hbars->new( @_ ) },
                          hbars_c=> sub { GD::Graph::hbars->new( @_ ) },
                          lines  => sub { GD::Graph::lines->new( @_ ) }, );

    my $y_max = _graph_size( $data_ref );

    # create graph object
    my $graph =  $type_dispatch{$graph_type}->( @{ $canvas{ $canvas_size } } );

    _set_parameters( $graph, $data_ref, $label_ref, $graph_type, $legend, $settings );

    # plot the data
    my $gd = $graph->plot($data_ref) || die "Can't plot graph data: $!";

    # write the png image file
    open my $png, ">", "$img_file";
    binmode $png;
    print $png $gd->png;
    close $png;

    return;
}


sub write_graph_file :Export {

    my ($data_ref, $labels_ref, $xml_file, $data_grps)  = @_;

    open my $file, '>', $xml_file;

    my $writer = XML::Writer->new( OUTPUT      => $file,
                                   DATA_MODE   => 1,
                                   ENCODING    => 'utf-8',
                                   DATA_INDENT => 4, );


    $writer->xmlDecl("UTF-8");

    $writer->startTag('graph');

    $writer->startTag('labels');

    $writer->startTag('title');
    $writer->characters( $labels_ref->{title} );
    $writer->endTag('title');

    $writer->startTag('y_axis_label');
    $writer->characters( $labels_ref->{y_axis}   );
    $writer->endTag('y_axis_label');

    $writer->startTag('x_axis_label');
    $writer->characters(  $labels_ref->{x_axis} );
    $writer->endTag('x_axis_label');

    $writer->endTag('labels');

    foreach my $dataset_key ( sort keys %{ $data_ref->[2] } ){

         $writer->startTag('dataset', name => $dataset_key );

         $writer->startTag('data_points');

         for my $point ( 0..( @{ $data_ref->[2]->{$dataset_key} } - 1 ) ){
             $writer->startTag('data_point', 'name' => $data_ref->[0]->[$point],
                                             'date' => $data_ref->[1]->[$point], );


            # perl 5.16: defined(@array) is deprecated
             if ('ARRAY' eq ref($data_grps) and @$data_grps ) {
                my $grp = ${ $data_ref->[2] }{$dataset_key}[$point];

                $writer->startTag('data_values');
                $writer->emptyTag('data_value', ($_ => ($grp->{$_} || 0)))
                    for @$data_grps;
                $writer->endTag('data_values');
             }
             else {
                $writer->characters( ${ $data_ref->[2] }{$dataset_key}[$point] );
             }

             $writer->endTag('data_point');
         }

          $writer->endTag('data_points');

          $writer->endTag('dataset');
     }

    $writer->endTag('graph');

    $writer->end();

    close $file;

    return;
}


sub _graph_size {

    my ($data_ref) = @_;

    # extract data point array
    my @data_points = ();
    for my $list_index (1..(@$data_ref - 1)){
        push ( @data_points, @{ $data_ref->[$list_index] } );
    }

    # fix maximum data point
    my $y_max_value = max @data_points;

    # round upwards to nearest 50
    my $y_max = nearest_ceil( 50, $y_max_value + 30 );

    return $y_max;
}


sub _set_parameters {

    my ($graph, $data_ref, $label_ref, $graph_type, $legend, $settings )    = @_;

    # set parameters
    $graph->set(
            y_max_value       => _graph_size( $data_ref ),
            y_tick_number     => 10,
            y_label_skip      => 2,
            bgclr             => 'white',
            fgclr             => 'black' ,
            borderclrs        => [ '#333333' ],
            box_axis          => 0,
            show_values       => 1,
            bar_spacing       => 6,
            cycle_clrs        => 0,
            labelclr          => '#333333',
            axislabelclr      => '#333333',
            legendclr         => '#333333',
            valuesclr         => '#333333',
            textclr           => '#333333',
            transparent       => 1,
            l_margin          => 20,
            t_margin          => 20,
            b_margin          => 10
         ) || die "Can't set graph parameters: $!";


    # this should work to cater for builds without support for align_values
    eval{ $graph->set( align_values => 1 ) };


    # cycle default colours if multiple data sets
    my @colours = ( config_var('CSS', 'primary_colour') );
    my @col_list= ();

    for my $dataset (0..@$data_ref) {
        push @col_list, $colours[$dataset];
    }
    $graph->set( dclrs => \@col_list );

    # set optional labels
    if( $label_ref->{title} ){
        $graph->set( title => $label_ref->{title} );
    }

    if( $label_ref->{y_axis} ){
        $graph->set( y_label => $label_ref->{y_axis} );
    }

    if( $label_ref->{x_axis} ){
        $graph->set( x_label => $label_ref->{x_axis} );
    }

    unless( $graph_type =~ /^hbars/ ){
        $graph->set( x_labels_vertical => 1 );
    }

    if ( $graph_type eq "hbars_c" ) {
        $graph->set( cumulate => 1 );
    }

    if ( @$data_ref > 2 ) {
        $graph->set_legend( @$legend );
        $graph->set( legend_placement => 'BR' );
        $graph->set( show_values => 0 );
    }

    my $liberation_fonts_dir = config_var('SystemPaths', 'liberation_fonts_dir');
    # font config
    $graph->set_title_font( $liberation_fonts_dir . '/LiberationSans-Bold.ttf',   11);
    $graph->set_x_label_font( $liberation_fonts_dir . '/LiberationSans-Regular.ttf', 9);
    $graph->set_y_label_font( $liberation_fonts_dir . '/LiberationSans-Regular.ttf', 9) ;
    $graph->set_x_axis_font( $liberation_fonts_dir . '/LiberationSans-Bold.ttf',  9) ;
    $graph->set_y_axis_font( $liberation_fonts_dir . '/LiberationSans-Regular.ttf',  9) ;
    $graph->set_values_font( $liberation_fonts_dir . '/LiberationSans-Regular.ttf',  9) ;
    $graph->set_legend_font( $liberation_fonts_dir . '/LiberationSans-Regular.ttf',  9);

    # go through any additional passed in settings
    if ( defined $settings && ref($settings) eq "HASH" ) {
        foreach ( keys %$settings ) {
            eval{ $graph->set( $_ => $settings->{$_} ) };
        }
    }
}


sub _extract_labels {

    my ($root) = @_;

    my %labels = ();

    # extract graph labels (using xpath)
    foreach my $label ( $root->findnodes('labels') ) {
        $labels{y_axis} = $label->findvalue('y_axis_label');
        $labels{x_axis} = $label->findvalue('x_axis_label');
        $labels{title}  = $label->findvalue('title');
    }

    return \%labels;
}


sub _extract_legend {

    my ($data_set_ref) = @_;

    my $legend = $data_set_ref->getAttribute('name');

    return $legend;
}


sub _extract_axis_labels {

    my ( $data_set_ref, $axis_value ) = @_;

    my @data_points = $data_set_ref->getElementsByTagName('data_point');

    my @y_labels = ();

    # extract named data points
    foreach my $data_point ( @data_points ){

        if( defined($axis_value) && $axis_value eq 'date' ){
            push @y_labels, $data_point->getAttribute('date');
        }
        else{
            push @y_labels, $data_point->getAttribute('name');
        }
    }

    return \@y_labels;
}

sub _extract_data_points {

    my ( $data_set_ref ) = @_;

    my @data_points = $data_set_ref->getElementsByTagName('data_point');

    my @values   = ();

    foreach my $data_point ( @data_points ){

        if ( my @dvalues = $data_point->getElementsByTagName('data_value') ) {
            my $dgrps;
            foreach my $data ( @dvalues ) {
                # get all the attribute names for this node
                my @attrib  = $data->attributes();
                # get the data value and group name which should always be the first attribute
                $dgrps->{ $attrib[0]->name }    = $attrib[0]->value;
            }
            push @values,$dgrps;
        }
        else {
            if( $data_point->getFirstChild ){
                push @values, $data_point->getFirstChild->getData;
            }
        }
    }

    return \@values;
}



1; # Magic true value required at end of module
__END__

=head1 NAME

XTracker::Statistics::Graph - Build graphs for display within XTracker


=head1 VERSION

This document describes XTracker::Statistics::Graph version 0.0.1


=head1 SYNOPSIS

    use XTracker::Statistics::Graph;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.


=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.

=head2 Exported Subroutines

=over

=item C<read_graph_file()>
    Collects statistics data from a defined file

=item C<write_graph()>
    Write the graph image in png format


=back



=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.

XTracker::Statistics::Graph requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-xtracker-statistics-graph@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Matthew Ryall  C<< <matt.ryall@net-a-porter.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Matthew Ryall C<< <matt.ryall@net-a-porter.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
