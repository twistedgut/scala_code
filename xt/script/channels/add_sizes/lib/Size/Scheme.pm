package Size::Scheme;

use Moose;
use MooseX::Types::Moose qw(Str);

has name => (
    is  => 'ro',
    isa => Str,
    required => 1,
);

has sizes => (
    is  => 'rw',
    isa => 'ArrayRef',
    default => sub { return [] },
);

sub add {
    my($self,$item) = @_;
    # strip whitespace at front/end
    $item =~ s/^\s+//; $item =~ s/\s+$//;
    return if $item eq '';
    push @{$self->sizes}, $item;
}

sub add_to_db {
    my ($self,$size_scheme)=@_;
    my $scheme_row=$size_scheme->search({name=>$self->name})->single;
    if($scheme_row){
        print $self->name." already exists\n";
    }else{
        $scheme_row=$size_scheme->create({name=>$self->name,short_name=>''});
        print $scheme_row->name."\n";    
    }
    my $i=1;
    foreach my $size (@{$self->sizes}){
        # deliberately creating a fresh one to guarantee the order - jt
        my $size_row = undef;
        #$size_scheme->result_source->schema->resultset('Public::Size')->search({size=>$size,sequence=>0})->first;
        if($size_row){
            print $size_row->size." already exists\n";
        }else{
            $size_row        =   $size_scheme->result_source->schema->resultset('Public::Size')->create({size=>$size,sequence=>0});
            print $size_row->size."\n";
        }
        my $size_map_row    =   $size_scheme->result_source->schema->resultset('Public::SizeSchemeVariantSize')->find_or_create({
            size_scheme_id  =>  $scheme_row->id,
            size_id         =>  $size_row->id,
            designer_size_id=>  $size_row->id,
            position        =>  $i++,
        });
    }
    print "*******************************************************\n";
 
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

