#!/opt/xt/xt-perl/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

my $VERBOSE             = 0;

use Log::Log4perl ':easy';
Log::Log4perl->easy_init({ level => $INFO });
use File::Find ();
use File::Basename;

my $VERSION             = 0.1;          # Is there a GIT VERSION macro?
my $LINES_TODO  = undef;        # Define a limit on lines to parse from files
my $FILES_TODO  = undef; # Deine a limit on files to process

# $LINES_TODO   = 100;
# $FILES_TODO   = 2;

my $LOG_DIR = shift(@ARGV) || '/var/modok-garbage/';
LOGCONFESS "Logs' dir does not exist, $LOG_DIR" if !-d $LOG_DIR;

my $Files_Done  = 0;            # Tally cf FILES_TODO
my $Uri2Time    = {};           # On-gonig totals
my $Uri2Hits    = {};           # For averaging
my $Uri2Avrg    = {};           # Final averages
my $Uri2Max             = {};           # Slowest literal value
my $Uri2MaxLine = {};           # Log the log line in q
my $Output_Path = $0.".log";

# Open now to get errors ASAP
open my $OUT, ">", $Output_Path or LOGCONFESS "$! - $Output_Path";
print $OUT sprintf( "%10s\t%10s\t%10s\t%s\t%s\n","Average (s)", "Hits", "Lit max", "URI", "Log line");
warn sprintf( "%10s\t%10s\t%10s\t%s\t%s\n","Average (s)", "Hits", "Lit max", "URI", "Log line");

File::Find::find(
        {
                wanted => \&wanted, 
                follow => 0,
        },
        $LOG_DIR,
);

INFO "Sorting ...";
$Uri2Avrg->{$_} = $Uri2Time->{$_} / $Uri2Hits->{$_}
        foreach keys %$Uri2Time;

INFO "Report in descending order to $Output_Path ...";
foreach my $uri (
        sort {
                $Uri2Avrg->{$b} <=> $Uri2Avrg->{$a} 
        } keys %$Uri2Avrg
){
        print $OUT sprintf( 
                "% 10d\t% 10d\t% 10d\t%-s\t%-s\n",      # So many big ints, ignore floats
                $Uri2Avrg->{$uri},
                $Uri2Hits->{$uri},
                $Uri2Max->{$uri},
                $uri,
                ($VERBOSE? $Uri2MaxLine->{ $uri } : '')
        );
}

close $OUT or LOGCONFESS "$! - $Output_Path";

INFO "Parsed $Files_Done files.";
INFO "Output at $Output_Path";

exit;

sub wanted {
        my $IN;
        return if !-f $_;                       # Ignore all but plain files
        return if !/\.log/g;            # All log file names contain .log
        return if -B $_;                        # Avoid bins/compressed

        INFO "Try $File::Find::name";
        if (not open $IN, '<', $File::Find::name ){
                ERROR "$! - $File::Find::name";
                return;
        }

        $Files_Done ++;
        return if defined $FILES_TODO and $Files_Done > $FILES_TODO;

        my $line = 0;
        while (<$IN>){
            if ($line % 50000 == 0) {
                INFO basename(${File::Find::name}) . ": ${line}...";
            }
            #last if $line > 10_000;

                chomp;
                TRACE $_;
                $line ++;
                last if defined $LINES_TODO and $line > $LINES_TODO;

                # XT::Handler::Event::StopTimer::handler - / 0.00284910202026367s
                # ... - /Fulfilment/Picking&process=sku&error_msg=The sku entered could not be found.  Please try again. 0.00234198570251465s
                # ... - /CustomerCare/OrderSearch/OrderView 1s
                my ($uri, $time) = m{
                        XT::Handler::Event::StopTimer::handler \s - \s (/.*?) \s (\d+ \. \d+ | \d+)s \s+$
                }x;

                LOGDIE "Time not defined:\n\t$_\n\t" if not defined $time;
                LOGDIE "URI not defined:\n\t$_\n\t" if not defined $uri;

                DEBUG sprintf "%50s - %-.20f", $uri, $time;

                # Normalise URIs
                $uri =~ s/\?.*$//;
                $uri =~ s/\d+$//;
                $uri =~ s{/$}{};

                if (exists $Uri2Time->{ $uri }){
                        $Uri2Time->{ $uri } += $time;
                        $Uri2Hits->{ $uri } ++;
                } 
                # Init
                else {
                        $Uri2Time->{ $uri } = $time;
                        $Uri2Hits->{ $uri } = 1;
                }

                # Record the slowest page, literal value
                if (exists $Uri2Max->{ $uri }){ 
                        if ($time > $Uri2Max->{ $uri }){
                                $Uri2Max->{ $uri } = $time;
                                $Uri2MaxLine->{ $uri } = $_;
                        }
                } 
                # Init
                else {
                        $Uri2Max->{ $uri } = $time;
                         $Uri2MaxLine->{ $uri } = $_;
                }

        }
        
        INFO "Parsed $line lines of $File::Find::name";

        close $IN;
}

