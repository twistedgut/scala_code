package XTracker::Printers::Zebra::PNG;
use Moose;
use GD;
use autodie;
use IO::Socket;
use GD::Text::Align;
use Bit::Vector;
use Math::Round qw(nearest_ceil);
use Moose::Util::TypeConstraints;

subtype 'ValidWidth'
    => as 'Int'
    => where { $_ % 8 == 0 }
    => message { 'widths must be divisible by eight(pixels) for correct hex encoding' };

has 'label_width'   =>  (    is  =>  'rw',    isa =>  'ValidWidth',     default => 1008,);
has 'width'         =>  (    is  =>  'rw',    isa =>  'ValidWidth',);
has 'label_height'  =>  (    is  =>  'rw',    isa =>  'Int',            default => 650,);
has 'height'        =>  (    is  =>  'rw',    isa =>  'Int',);
has 'img'           =>  (    is  =>  'rw',    isa =>  'GD::Image',);
has 'white'         =>  (    is  =>  'rw',    isa =>  'Int',            default => 0,);
has 'black'         =>  (    is  =>  'rw',    isa =>  'Int',            default => 1,);
has 'font'          =>  (    is  =>  'rw',    isa =>  'Str',);
has 'font_size'     =>  (    is  =>  'rw',    isa =>  'Num',            default => 180,);
has 'text_obj'      =>  (    is  =>  'rw',    isa =>  'GD::Text::Align',);
has 'text'          =>  (    is  =>  'rw',    isa =>  'Str',);
has 'valign'        =>  (    is  =>  'rw',    isa =>  'Str',            default =>  'center',);
has 'halign'        =>  (    is  =>  'rw',    isa =>  'Str',            default =>  'center',);
has 'command'       =>  (    is  =>  'rw',    isa =>  'Str',);
has 'sensitivity'   =>  (    is  =>  'rw',    isa =>  'Int',            default =>  200,);
has 'hex_image'     =>  (    is  =>  'rw',    isa =>  'Str',);
has 'filename'      =>  (    is  =>  'rw',    isa =>  'Str',            default =>  'TEST',);
has 'begin_format'  =>  (    is  =>  'rw',    isa =>  'Str',            default =>  "^XA\n",);
has 'end_format'    =>  (    is  =>  'rw',    isa =>  'Str',            default =>  "^XZ\n",);
has 'pre'           =>  (    is  =>  'rw',    isa =>  'Str',);
has 'post'          =>  (    is  =>  'rw',    isa =>  'Str',);
has 'image_to_mem'  =>  (    is  =>  'rw',    isa =>  'Str',);
has 'to_mem_only'   =>  (    is  =>  'rw',    isa =>  'Bool',           default =>  0,);
has 'source_png'    =>  (    is  =>  'rw',    isa =>  'Str',);
has 'x_origin'      =>  (    is  =>  'rw',    isa =>  'Int',            default =>  0,);
has 'y_origin'      =>  (    is  =>  'rw',    isa =>  'Int',            default =>  0,);
has 'bounds'        =>  (    is  =>  'rw',    isa =>  'ArrayRef',);

=head

This object provides the image and text generation for the printing to be sent to the printer

=cut

=head

BUILD: This creates the image required dependant on given construction parameters

=cut

sub BUILD {
    my $self = shift;

    # default size = label size from defaults above
    $self->width($self->label_width);
    $self->height($self->label_height);

    if($self->text){
        ################################################################
        # If text supplied create a new image
        ################################################################
        $self->calc_font_size;
        $self->render_text;
        # Trim image to rendered height and re-render (with 40px buffer)
        my $height = ${$self->bounds}[1]-${$self->bounds}[7];
        $self->height($height+40);
        $self->render_text;
    }elsif($self->source_png){
        ################################################################
        # If png supplied render from that image
        ################################################################
        my $file;
        open($file,'<',$self->source_png);
        $self->img(GD::Image->newFromPng($file));
        close $file;
        my ($width,$height) = $self->img->getBounds();
        $self->height($height);
        $self->width($width);
    }else{
        ################################################################
        # If neither supplied render dummy label image
        ################################################################
        $self->text("No text");
        $self->render_text;
    }
    $self->png2hex;
}

=head

render_text: This creates an image of centrally aligned text
and limits image size to size of the resulting image

=cut

sub render_text {
    my $self = shift;
    $self->img(GD::Image->new(
        $self->width,
        $self->height
    ));
    $self->white($self->img->colorAllocate(255,255,255));  #background colour(white)
    $self->black($self->img->colorAllocate(0,0,0));        #foreground colour(black)
    $self->text_obj(GD::Text::Align->new($self->img,
        valign => $self->valign,
        halign => $self->halign,
        text => $self->text,
        ptsize => $self->font_size,
        color => $self->black,
    ));
    $self->text_obj->set_font($self->font) if $self->font;
    my @bounds = $self->text_obj->draw(($self->width/2.1),($self->height/2),0);
    $self->bounds(\@bounds);
}

=head

png2hex: This converts a black and white png to a hex string to be sent to printer memory

=cut

sub png2hex {
    my ($self)  =   @_;
    my $img = $self->img;
    for my $y (0..$self->height-1){
        my $binary;
        for my $x (0..$self->width-1){
            my @rgb = $img->rgb( $img->getPixel($x, $y) );
            if ( grep{$_<$self->sensitivity} @rgb ) { # is "black" or "white"
                $binary.='1';
            }else{
                $binary.='0';
            }
            if($x % 8 ==0){
                my $bin  =  Bit::Vector->new_Bin(8, $binary);
                if($self->hex_image){
                    $self->hex_image($self->hex_image().$bin->to_Hex());
                }else{
                    $self->hex_image($bin->to_Hex());
                }
                $binary="";
            }
        }
    }
    my $name    =   $self->filename;
    my $total_bytes=sprintf("%05d",(($self->height*$self->width)/8));
    my $bytes_per_row=sprintf("%03d",($self->width/8));
    $self->image_to_mem("~DGR:$name.GRF,$total_bytes,$bytes_per_row,".$self->hex_image."\n");
}

=head

final: This compiles a final label including headers, pre and post commands

=cut

sub final {
    my ($self)  =   @_;
    $self->command($self->image_to_mem) if $self->image_to_mem;
    unless($self->to_mem_only){
        # ^XA
        $self->command($self->command.$self->begin_format);
        # header
        $self->command($self->command.$self->pre) if $self->pre;
        # main image field
        $self->y_origin(int(($self->label_height  - $self->height)/2));
        $self->command($self->command."^FO".$self->x_origin.",".$self->y_origin."^XGR:".$self->filename.".GRF,1,1^FS\n");
        # footer
        $self->command($self->command.$self->post) if $self->post;
        # ^XZ
        $self->command($self->command.$self->end_format);
    }
    return $self->command;
}

=head

nearest_8: This rounds a number up to the nearest multiple of 8 (don't ask)

=cut

sub nearest_8 {
    my ($self,$try)  =   @_;
    my $rounded = nearest_ceil(8,$try);
    return $rounded;
}

=head

calc_font_size: This sets the size of the font dependant on the length of the text

=cut

sub calc_font_size {
    my ($self)  =   @_;
    my $length  =  length($self->text);
    my $initial_size;
    my $ratio;
    if($self->text =~ m/[A-Z][A-Z]/){
        my $titlecase = $self->text;
        $titlecase =~ s/(\w+)/\u\L$1/g;
        $self->text($titlecase);
    }
    if($length<10){
        $initial_size=$self->font_size;
        $ratio=0;
    }elsif($length<15){
        $initial_size=160;
        $ratio=1.5;
    }else{
        $initial_size=120;
        $ratio=1.5;
    }
    $self->font_size($initial_size-($length*$ratio));
}

1;
