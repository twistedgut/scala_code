package Test::XT::Data::CorrespondenceTemplate;

use NAP::policy "tt",     qw( role test );
requires 'schema';

has template_name   => (
    is          => 'rw',
    isa         => 'Str',
    default     => "Test Correspondence Template - " . $$,
);

has subject => (
    is          => 'rw',
    isa         => 'Str',
    default     => "Your order - [% order_number %]",       # a popular email subject
);

has content => (
    is          => 'rw',
    isa         => 'Str',
    default     =><<CONTENT
Dear [% salutation %],

Here is your order [% order_number %], we hope you enjoy it.

[% signoff %]
CONTENT
,
);

has content_type    => (
    is          => 'rw',
    isa         => 'Str',
    default     => 'text',
);

has id_for_cms  => (
    is          => 'rw',
    isa         => 'Str',
    default     => 'TEST_CMS_' . $$,
);

has department_id => (
    is          => 'rw',
    isa         => 'Int',
);

has template => (
    is          => 'rw',
    lazy        => 1,
    builder     => '_set_template',
);


# Get a Correspondence Template
sub _set_template{
    my $self    = shift;

    my $template    = $self->schema
                            ->resultset('Public::CorrespondenceTemplate')
                                ->create( {
                                        name            => $self->template_name,
                                        access          => 0,
                                        content         => $self->content,
                                        department_id   => $self->department_id,
                                        subject         => $self->subject,
                                        content_type    => $self->content_type,
                                        id_for_cms      => $self->id_for_cms,
                                    } );

    return $template->discard_changes;
}

1;
