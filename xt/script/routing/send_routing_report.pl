#!/opt/xt/xt-perl/bin/perl
#
# send a report based on the most-recently imported routing files 
#
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use File::Spec::Functions qw( catdir );
use Carp qw( croak );

use Text::CSV_XS;

use Date::Format;

use XTracker::Config::Local qw( config_var );
use XTracker::Utilities qw ( strip );
use XTracker::Database::Variant qw ( :validation );
use XTracker::EmailFunctions qw( send_email );

use Sys::Hostname;

use Template;

my $report_dir = $ARGV[0] || '';

die "Report directory must be provided\n"
    unless $report_dir && -d $report_dir;

my $routing_dir      = catdir(config_var('SystemPaths','script_dir'),
                              config_var('Routing','script_dir'));

my $routing_email    = config_var('Routing','report_email');
my $routing_template = config_var('Routing','report_email_template');

$routing_template .= q{.tt} unless $routing_template =~ m{\.tt$};

chdir $routing_dir
    or die "Cannot change directory to '$routing_dir': $!\n";

die "Unable to read template $routing_template\n"
    unless -f $routing_template && -r $routing_template;

# template is in routing_dir, results are in report_dir
my $tt = Template->new({ INCLUDE_PATH => "$routing_dir:$report_dir" }) or die $Template::ERROR, "\n";

my $reports = {
    summary_report => { name => config_var('Routing','summary_report_file'),
                        desc => 'Routing summary report'
                      },
    error_report   => { name => config_var('Routing','error_report_file'),
                        desc => 'Routing error report',
                        missing_okay => 1
                      },
};

my $attachments = {
};

my $data = {};

$data->{report_path} = $report_dir;
$data->{report_host} = hostname;

foreach my $report (keys %$reports) {
    my $name = $reports->{$report}{name};
    my $path = "$report_dir/$name";

    $data->{$report.q{_file}} = $name;
    $data->{$report.q{_path}} = $path;

    unless (-s $path) {
        $data->{$report.q{_missing}} = 1;
        $data->{errors_reported}++ unless $reports->{$report}{missing_okay};
    }
}

my @attachments_found=();

foreach my $attachment (keys %$attachments) {
    my $name = $attachments->{$attachment}{name};
    my $path = "$report_dir/$name";

    if (-s $path) {
        $data->{$attachment.q{_file}} = $name;
        $data->{$attachment.q{_path}} = $path;
        push @attachments_found,$attachment;
    }
    else {
        $data->{errors_reported}++ unless $attachments->{$attachment}{missing_okay};
    }
}

my @attachment_paths = undef;

if (@attachments_found) {
    @attachments_found = sort @attachments_found;

    $data->{attachment_names} = join(', ', map { $attachments->{$_}{desc} } @attachments_found);

    @attachment_paths = map {
                              { type     => 'text/plain',
                                filename => "$report_dir/$attachments->{$_}{name}"
                              }
                        } @attachments_found;
}
else {
    $data->{attachment_errors} = "No expected output files found -- THIS SHOULD BE INVESTIGATED.";
}

my $now = time;

$data->{human_date} = time2str('%e %B %Y',$now);
$data->{human_time} = time2str('%H:%M:%S',$now);

my $message_body = '';

$tt->process($routing_template, $data, \$message_body) or die $tt->error(), "\n";

die "Unable to create e-mail message\n"
    unless $message_body;

my $routing_sender = config_var('Email','xtracker_email');

my $subject = "Premier Routing data import: $data->{human_date} $data->{human_time}";

$subject .= " - ERRORS REPORTED" if $data->{errors_reported};

eval {
    send_email( $routing_sender,
                $routing_sender,
                $routing_email,
                $subject,
                $message_body,
                'text',
                \@attachment_paths );
};

if ($@) {
    die "Trouble sending e-mail: $@\n";
}
else {
    exit 0;
}
