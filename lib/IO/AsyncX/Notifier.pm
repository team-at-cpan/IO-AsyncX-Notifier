package IO::AsyncX::Notifier;

use Object::Pad;

class IO::AsyncX::Notifier extends IO::Async::Notifier;

our $VERSION = '0.001';

use Syntax::Keyword::Try;
use Scalar::Util ();

method configure (%args) {
    my $class = Object::Pad::MOP::Class->for_class(ref $self);
    SLOT:
    for my $k (sort keys %args) {
        try {
            my $slot = $class->get_slot('$' . $k);
            my $v = delete $args{$k};
            if(Scalar::Util::blessed(my $current = $slot->value($self))) {
                if($current->isa('Ryu::Observable')) {
                    $current->set_string($v);
                    next SLOT;
                }
            }
            $slot->value($self) = $v;
        } catch($e) {
            die $e unless $e =~ /does not have a slot/;
        }
    }
    $self->next::method(%args);
}

1;
