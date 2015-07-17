package XTracker::Admin::JobQueue;

use strict;
use warnings;

use XTracker::Handler;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $schema      = $handler->{schema};

    $handler->{data}{content}       = 'shared/admin/jobqueue.tt';
    $handler->{data}{section}       = 'Job Queue';
    $handler->{data}{subsection}    = 'Lists';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{sidenav}       = [
                                        {'None' => [
                                                { title => 'Job List', url      => "javascript:refresh_list('JOB');" },
                                                { title => 'Failed Jobs', url   => "javascript:refresh_list('FAILED');" },
                                                { title => 'Last 50 Jobs', url  => "javascript:refresh_list('LAST50');" },
                                                { title => 'Job Error Messages', url=> "javascript:refresh_list('ERROR');" },
                                            ]
                                        },
                                        {'Function Map' => [
                                                { title => 'All', url   => "javascript:refresh_list('FUNCMAP_ALL');" },
                                                { title => 'Send', url  => "javascript:refresh_list('FUNCMAP_SEND');" },
                                                { title => 'Receive', url   => "javascript:refresh_list('FUNCMAP_RECEIVE');" },
                                                { title => 'Other', url => "javascript:refresh_list('FUNCMAP_OTHER');" }
                                            ]
                                        }
                                    ];

    $handler->{data}{js}            = [ "/yui/yahoo-dom-event/yahoo-dom-event.js", "/yui/connection/connection-min.js" ];

    return $handler->process_template( undef );
}

1;
