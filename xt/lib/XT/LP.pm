package XT::LP;

use NAP::policy "tt", 'class';
use XTracker::Logfile qw(xt_logger);

sub print {
    my ( $class, $print_options ) = @_;

    my $output = '';
    my $command = sprintf( '%s 2>&1 |', $class->prepare( $print_options ) );
    open( my $sc, $command ) or die "Error opening '$command': $!"; ## no critic(ProhibitTwoArgOpen)

    {
        local $/ = undef;
        $output = <$sc>;
    }
    close( $sc );

    xt_logger->info("Printed: $command - $output");

    return $output;
}

sub prepare {
    my ( $class, $print_options ) = @_;

    my @options = ();
    push @options, XTracker::Config::Local::config_var( 'Printing', 'lp_path' );

    # Check the printer is sane
    croak "You must provide a 'printer' option to XT::LP" unless( $print_options->{printer} && ! ref( $print_options->{printer} ) );

    # Filename
    my $filename = $print_options->{filename};
    croak "You must provide a 'filename' option to XT::LP" unless( $filename );
    warn "Your filename '$filename' doesn't appear to exist - expect weirdness" unless( -e $filename );

    # Convert pdf to postscript if necessary
    if ( $filename =~ /\.pdf$/ ) {
        (my $ps_filename = $filename) =~ s/\.pdf$/.ps/;
        system( "pdftops '$filename' '$ps_filename'" ) == 0
            or die "Failed to convert PDF '$filename' to PS '$ps_filename': $!";
        $filename = $ps_filename;
    }

    push( @options, '-d', $print_options->{printer} );

    # Copies?
    if ( exists $print_options->{copies} ) {
        push( @options, '-n', ( $print_options->{copies} || 1 ) );
    }

    # No banner, for great justice
    push( @options, '-o', 'nobanner' );

    if ( defined( $print_options->{orientation} ) && ( $print_options->{orientation} eq 'landscape' ) ) {
        push( @options, '-o', 'orientation-requested=5' ); # rotate 270 degrees
    }

    push( @options, $filename );

    return join( ' ', @options );
}

1;
