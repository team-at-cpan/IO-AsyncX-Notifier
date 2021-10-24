package IO::AsyncX::Notifier;
# ABSTRACT: Combining IO::Async::Notifier with Object::Pad

use Object::Pad;

class IO::AsyncX::Notifier extends IO::Async::Notifier;

our $VERSION = '0.001';

=head1 NAME

=head1 SYNOPSIS

 use Object::Pad;
 class Example isa IO::AsyncX::Notifier {
  use Ryu::Observable;
  # This will be populated by ->configure(example_slot => ...)
  # or ->new(example_slot => ...)
  has $example_slot;
  # This will be updated by ->configure (or ->new) in a similar fashion
  has $observable_slot { Ryu::Observable->new };
  # You can have as many other slots as you want, main limitation
  # at the moment is that they have to be scalars.

  method current_values () {
   'Example slot: ' . $example_slot,
   ' and observable set to ' . $observable_slot->as_string
  }
 }
 my $obj = Example->new(
  example_slot    => 'xyz',
  observable_slot => 'starting value'
 );
 print join "\n", $obj->current_values;

=head1 DESCRIPTION

Provides some helper logic to simplify L<Object::Pad>-based
L<IO::Async::Notifier> subclasses.

=cut

use mro qw(c3);
use Syntax::Keyword::Try;
use Scalar::Util ();

# This is a hack to defer ->configure until we have an object
has $prepared;

ADJUSTPARAMS ($args) {
    # We set this once after instantiation and never touch it again
    $prepared = 1;

    # Here we defer the initial ->configure call
    $self->configure(%$args);

    # Since ->configure did the hard work, we can throw away the parameters again
    %$args = ();
}

method configure (%args) {
    # This does nothing until we have finished Object::Pad instantiation
    return unless $prepared;

    # We only care about slots in the lowest-level subclass: there
    # is no support for IaNotifier -> first sub level -> second sub level
    # yet, since it's usually preferable to inherit directly from IaNotifier
    my $class = Object::Pad::MOP::Class->for_class(ref $self);

    # Ordering is enforced to make behaviour more predictable
    SLOT:
    for my $k (sort keys %args) {
        try {
            # Only scalar slots are supported currently
            my $slot = $class->get_slot('$' . $k);

            my $v = delete $args{$k};
            # There isn't a standard protocol for "observable types", so
            # we only support Ryu::Observable currently.
            if(Scalar::Util::blessed(my $current = $slot->value($self))) {
                if($current->isa('Ryu::Observable')) {
                    $current->set_string($v);
                    next SLOT;
                }
            }

            $slot->value($self) = $v;
        } catch($e) {
            # We really don't want to hide errors, but this might be good enough for now.
            die $e unless $e =~ /does not have a slot/;
        }
    }

    # Anything left over will cause IO::Async::Notifier's implementation to complain
    # appropriately - note that this means we don't need (or want) the `:strict`
    # definition on the class itself.
    $self->next::method(%args);
}

1;
