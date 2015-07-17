package XTracker::Admin::EmailTemplates;

use strict;
use warnings;

use XTracker::Handler;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $schema  = $handler->schema;
    my $data    = $schema->resultset('Public::CorrespondenceTemplate')
                         ->get_templates_by_department;


    $handler->{data}{content}               = 'shared/admin/emailtemplates.tt';
    $handler->{data}{section}               = 'Email Templates';
    $handler->{data}{subsection}            = 'Template List';
    $handler->{data}{subsubsection}         = '';
    $handler->{data}{list}                  = $data;


    return $handler->process_template;
}

1;
