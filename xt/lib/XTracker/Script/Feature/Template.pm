package XTracker::Script::Feature::Template;

use Moose::Role;

=head1 NAME

XTracker::Script::Feature::Template

=head1 DESCRIPTION

This role provides the script a XTracker::XTemplate object

=head1 SYNOPSIS

  package MyScript;
  use Moose;
  extends 'XTracker::Script';
  with 'XTracker::Script::Feature::Template';

  sub invoke {
    # normal script stuff here - with $self->template available
  }

  1;

=cut

use XTracker::XTemplate;

has template => (
    isa => 'XTracker::XTemplate',
    is => 'rw',
    lazy_build => 1,
);

sub _build_template {
    my $self = shift;

    return $self->template(
            XTracker::XTemplate->template( {
                PRE_CHOMP  => 0,
                POST_CHOMP => 1,
                STRICT => 0,
            } )
        );


};

sub process_template {
    my ( $self, $template, $data )  = @_;

    my $out;

    # make sure it defaults to being for Emails meaning no Headers & Footers are added
    $data->{template_type}     = 'email'        if ( !exists( $data->{template_type} ) );

    $self->template->process( $template, $data, \$out );

    return $out;
}

1;
