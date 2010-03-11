package Annelidous::Storage::LVM;
use base 'Annelidous::Storage';

sub new {
    my $invocant = shift;
    my $class   = ref($invocant) || $invocant;
    my $self={
		-class=>undef,
		-description=>undef,
		-path=>undef,
        @_
    };
    bless $self, $class;
    return $self;
}

