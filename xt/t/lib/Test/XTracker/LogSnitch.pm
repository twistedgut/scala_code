package Test::XTracker::LogSnitch;

=head1 NAME

Test::XTracker::LogSnitch - Monitor log files

=head1 DESCRIPTION

Monitors files during the test run, and then lets you know if they've been added
to during the test run. Meant for nagging developers who write noisy code.

=head1 SYNOPSIS

  $mech->log_snitch->add_file( 'filename' );

=cut

use NAP::policy qw( test class );


has 'filelist' => (
    is      => 'rw',
    isa     => 'ArrayRef[Test::XTracker::LogSnitch::Watcher]',
    default => sub{[]},
);

sub add_file {
    my ( $self, $filename ) = @_;
    my $obj = Test::XTracker::LogSnitch::Watcher->new( filename => $filename );
    push( @{ $self->filelist }, $obj );
    return $obj;
}

sub complain { $_[0]->_run_all('complain') }
sub pause    { $_[0]->_run_all('pause')    }
sub unpause  { $_[0]->_run_all('unpause')  }

sub _run_all {
    my ( $self, $method ) = @_;
    foreach my $file ( @{ $self->filelist } ) { $file->$method; }
}


package Test::XTracker::LogSnitch::Watcher; ## no critic(ProhibitMultiplePackages)
use NAP::policy qw( test class );
use Carp 'croak';

has 'filename'     => ( is => 'ro', isa => 'Str' );
has 'ignore_spans' => ( is => 'rw', isa => 'ArrayRef', default => sub {[]} );
has 'fh'           => ( is => 'rw', lazy => 1, builder => '_build_fh' );

sub _build_fh {
    my $self = shift;
    my $filename = $self->filename;
    open my $fh, '<', $filename
        or return; # silent fail, yes
    return $fh;
}

sub current_end {
    my $self = shift;
    my $fh = $self->fh;
    return unless $fh;
    my $current = tell($fh);
    seek $fh,0,2; # seek to the end
    my $end = tell($fh);
    seek $fh,$current,0;
    return $end;
}

sub BUILD {
    my $self = shift;

    my $pos = $self->current_end;
    return unless defined $pos;
    push @{ $self->ignore_spans() }, [0, $pos];
}

# Turn the log snitch on and off temporarily - for known errors
sub pause {
    my $self = shift;
    my $pos = $self->current_end;
    return unless defined $pos;

    push @{ $self->ignore_spans() }, [$pos,-1];
    return;
}
sub unpause {
    my $self = shift;

    my $pos = $self->current_end;
    return unless defined $pos;

    my $last_span = $self->ignore_spans()->[-1];
    croak "->unpause called without corresponding ->pause!"
        unless $last_span->[1] == -1;

    $last_span->[1] = $pos;
    return;
}

sub complain {
    my $self = shift;
    my $fh = $self->fh;
    return unless $fh;
    my @spans = @{ $self->ignore_spans };
    my $end_position = $self->current_end;

    # $spans[0] is the one created by BUILD, so its second element is
    # the length at BUILD time
    if ($end_position > $spans[0]->[1]) {

        diag "*** Your test added unhandled diagnostics or warnings to " . $self->filename;
        diag "*** Lines were:";
        diag "***";

        my $line_count = 0;
        seek $fh,0,0;my $current_position = tell($fh);
        while ($current_position <= $end_position) {
            # if we're inside an ignorable span
            while (@spans && $current_position >= $spans[0]->[0]) {
                seek $fh,$spans[0]->[1],0; # seek to its end
                $current_position = tell($fh);
                shift @spans; # and skip to the next span
            }
            my $line = readline($fh);last unless $line;
            $current_position = tell($fh);
            ++$line_count;
            diag "*** \t$line";
        }
        diag "***";
        diag "*** for a total of $line_count lines";
        diag "*** That's not good! Please fix it, or TechOps will kill you, and that would be a shame.";
    } else {
        note "Monitored log [" . $self->filename . "] had no added lines";
    }
}

sub DEMOLISH {
    my $self = shift;
    $self->complain;
}

1;
