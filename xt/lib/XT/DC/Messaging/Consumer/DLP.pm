package XT::DC::Messaging::Consumer::DLP;
use NAP::policy "tt", 'class';
use XTracker::Config::Local;
extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';
use XT::DC::Messaging::Spec::DLP;
use XTracker::Config::Local;

sub routes {
    return {
        destination => {
            process => {
                spec => XT::DC::Messaging::Spec::DLP::dlp(),
                code => \&process,
            },
            dlp => {
                spec => XT::DC::Messaging::Spec::DLP::dlp(),
                code => \&process,
            },
        },
    }
}

sub process {
    my ( $self, $designer_data ) = @_;

    # my $designer_data = $message->{dlp};

    my $designer_id = $designer_data->{id};

    my $designer =
        $self->model('Schema::Public::Designer')
        ->search( { id => $designer_id, } )->first;

    my $page_instance =
      $self->model('Schema::WebContent::Page')
      ->search( { name => 'Designer - ' . $designer->designer, } )
      ->first->instances->search(undef, {order_by => { -desc=>'id'}} )->first;

    my $content =
      $self->model('Schema::WebContent::Content')
      ->search( { instance_id => $page_instance->id, } );
    my @fields = $self->model('Schema::WebContent::Field')->search()->all;


    foreach my $field (@fields) {
        my $id   = $field->id;
        my $name = $field->name;
        # $self->log->info("UPTO 7: [$id, $name]");
        # my $row  = $content->search( { field_id => $id } )->first;
        if ( defined $designer_data->{$name} ) {
            $content->update_or_create( {field_id => $id, content => $designer_data->{$name} } );
        }
    }

    return;
}
