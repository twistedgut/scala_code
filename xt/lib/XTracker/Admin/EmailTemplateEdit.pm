package XTracker::Admin::EmailTemplateEdit;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::EmailFunctions    qw( get_email_template_info );
use XTracker::Error;
use Template::Parser;
use Template;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $template_id = "";
    my @levels      = split /\//, $handler->{data}{uri};
    $template_id    = $levels[4];

    $handler->{data}{content}       = 'shared/admin/emailtemplateedit.tt';
    $handler->{data}{section}       = 'Email Templates';
    $handler->{data}{subsection}    = 'Edit Template';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{sidenav}       = [{ "None" => [ { 'title' => 'Back to List', 'url' => "/Admin/EmailTemplates" } ] }];
    $handler->{data}{css}           = [ '/css/admin/emailtemplate.css' ];
    $handler->{data}{js}            = [ '/javascript/admin/emailtemplate.js' ];

    my $schema                      = $handler->schema;

    if ($template_id) {
        $handler->{data}{form_submit}   = "/Admin/EmailTemplates/Edit/$template_id";
    }
    else {
        $handler->{data}{form_submit}   = "/Admin/EmailTemplates/Edit";
    }


    ### profile form submitted
    if ( (exists $handler->{param_of}{submit}) && ($template_id) && ($handler->{data}{is_operator}) ) {

        eval {
            if ($template_id) {
                my $data    = $handler->{param_of}{content};

                # Validate content before storing
                my $output = _validate( $data );

                # Parsed  successfully
                if( $output eq "" ) {
                    my $guard = $schema->txn_scope_guard;

                    my $template = $schema->resultset('Public::CorrespondenceTemplate')->find($template_id);
                    die "Error: You are trying to save non existing template" unless $template;
                    $handler->{data}{template}  =  $template;
                    $template->update_email_template( $data, $handler->operator_id );
                    $guard->commit;
                    $handler->{data}{display_msg}   = "Template Updated";

                } else {
                    # Failed parser validation
                    $handler->{data}{error_data} = $data;
                    $handler->{data}{error_msg} = "Error saving the template: $output";

                }
            }
        };

        if (my $e = $@) {
            $handler->{data}{error_msg}     = $e;
        }
    }

    if ($template_id) {
        my $template;
        if( exists  $handler->{data}{template}  ) {
            $template = $handler->{data}{template};
        } else {
            $template = $schema->resultset('Public::CorrespondenceTemplate')->find($template_id);
        }

        if( $template ) {
            $handler->{data}{template_info}= { $template->get_columns };
            $handler->{data}{change_log}= [
                $handler->schema->resultset('Public::CorrespondenceTemplatesLog')
                                ->in_display_order
                                ->all
            ];
       }

    }


    if( exists $handler->{data}{error_data} ) {
        $handler->{data}{template_info}{content} = $handler->{data}{error_data};
        delete( $handler->{data}{error_data});
    }

    return $handler->process_template;
}

sub _validate {
    my $content = shift;

    my $parser = Template::Parser->new();
    $parser->parse($content);

    # store parser error
    # if success it's empty string
    my $output = $parser->error();

    # return parser error
    return $output;
}

1;
