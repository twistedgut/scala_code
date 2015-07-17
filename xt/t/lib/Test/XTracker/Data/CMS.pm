package Test::XTracker::Data::CMS;

use NAP::policy "tt", 'test';
use Test::XTracker::Data;
use XTracker::Config::Local 'config_var';

# this HASH holds the current Values of the field
# 'id_for_cms' when 'set_ifnull_cms_id_for_template'
# is called so that it can be restored when
# 'restore_cms_id_for_template' is called
my %current_id_for_cms = ();

=head1 NAME

Test::XTracker::Data::CMS - Used to create data returned from CMS


=head1 SYNOPSIS

    package Test::XTracker::Data::CMS

    __PACKAGE__->create_cms_correspodence_template_data;

=cut

=head1 METHODS

=head2 create_cms_correspodence_template_data

my $xml_string =__PACKAGE__->create_cms_correspodence_template_data( {
        cms => {
            message_entry => [ #optional
                {
                    key => 'Text'
                    value => 'Your text data',
                }
                {
                    key => 'html'
                    value => 'Your html data',
                }
              ],
            field_subject => 'Email subject you want to add', # optional
            matched_criterian => [
                {
                    key => 'brand',
                    value => 'nap',
                },
                {
                    key => 'language'
                    value => 'zh',
                },
                {
                    key => 'channel',
                    value => 'AM',
                },
            ],
        },
    });

if hash_data is passed then it fills the template with given data else it fills
with default data.

template used is t/data/cms/template/cms_api_email_content.xml.tt


=cut

sub create_cms_correspondence_template_data {
    my ( $self, $data ) = @_;


    my $path = config_var( 'SystemPaths', 'xtdc_base_dir' )."/t/data/cms/template";
    my $tt_filename = 'cms_api_email_content.xml.tt';
    my $filepath = $path.'/'.$tt_filename;

    die $filepath . "needs to exist"    unless -e $filepath;

    my $xml_data;
    my $output_string;

    eval {
        open ( my $fh, '<', $filepath) or die "Cannot open XML TT file '$filepath' for reading\n";
        local $/ = undef;
        $xml_data = <$fh>;
        close $fh;
    };
    if (my $e = $@) {
        die "Unable to read XML template: $e\n";
    }

    $data = $self->_prepare_cms_data($data);
    my $tt = Template->new({ABSOLUTE => 1});
    $tt->process(
        \$xml_data,
        $data,
        \$output_string,
    ) or die $tt->error;

    return $output_string;

}

sub _prepare_cms_data {
    my ($class, $data) = @_;
    $data ||= {};

    my $flag = exists $data->{cms} ? 1 : 0;

    my $cms = delete $data->{cms} || {};
    if ( !$flag ) {
        $cms->{message_entry} ||= [
            {
                key => 'Text',
                value => "<![CDATA[Template for Plain Text goes here \x{2603}]]>",
            },
            {
                key => 'HTML',
                value => "<![CDATA[Template for HTML Version goes here \x{2603}]]>",
            },
        ];
        $cms->{field_subject} ||= "You Order subject line";

        $cms->{matched_criteria} ||= [
            {
                key => 'brand',
                value => 'nap',
            },
            {
                key => 'language',
                value => 'zh',
            },
            {
                key => 'channel',
                value => 'AM',
            },
            {
                key => 'country',
                value => 'UK',
            },
        ];
    }

    return { %{ $data }, cms => $cms };
}


=head2 set_ifnull_cms_id_for_template

    $template_obj   = Test::XTracker::Data::CMS->set_ifnull_cms_id_for_template( $CORRESPONDENCE_TEMPLATES__ID, $value_to_set );

This will set the value of 'id_for_cms' to the supplied value or 'TEST_CMS_ID' if ommitted. It will store the current value so that
it can be restored when a call to 'Test::XTracker::Data::CMS->restore_cms_id_for_template' is made.

=cut

sub set_ifnull_cms_id_for_template {
    my ( $self, $template_id, $cms_id ) = @_;

    my $schema  = Test::XTracker::Data->get_schema;

    my $template= $schema->resultset('Public::CorrespondenceTemplate')->find( $template_id );

    my $curr_cms_id = $template->id_for_cms;

    if ( !$curr_cms_id ) {
        $current_id_for_cms{ $template_id } = $curr_cms_id;
        $template->update( { id_for_cms => $cms_id || 'TEST_CMS_ID' } );
    }

    return $template->discard_changes;
}

=head2 clear_cms_id_for_template

    $template_obj   = Test::XTracker::Data::CMS->clear_cms_id_for_template( $CORRESPONDENCE_TEMPLATES__ID );

=cut

sub clear_cms_id_for_template {
    my ( $self, $template_id )  = @_;

    my $schema  = Test::XTracker::Data->get_schema;

    my $template= $schema->resultset('Public::CorrespondenceTemplate')->find( $template_id );

    my $curr_cms_id = $template->id_for_cms;

    if ( !$curr_cms_id ) {
        $current_id_for_cms{ $template_id } = $curr_cms_id;
        $template->update( { id_for_cms => undef } );
    }

    return $template->discard_changes;
}

=head2 restore_cms_id_for_template

    $template_obj   = Test::XTracker::Data::CMS->restore_cms_id_for_template( $CORRESPONDENCE_TEMPLATES__ID );

This will restore the value of the field 'id_for_cms' on the 'correspondence_templates' table for a given Template Id that had
previously been set by a call to 'Test::XTracker::Data::CMS->set_ifnull_cms_id_for_template'.

=cut

sub restore_cms_id_for_template {
    my ( $self, $template_id )  = @_;

    my $schema  = Test::XTracker::Data->get_schema;

    my $template    = $schema->resultset('Public::CorrespondenceTemplate')->find( $template_id );

    # only restore if a value actually exists in the HASH
    if ( exists( $current_id_for_cms{ $template_id } ) ) {
        $template->update( { id_for_cms => delete $current_id_for_cms{ $template_id } } );
    }

    return $template->discard_changes;
}
