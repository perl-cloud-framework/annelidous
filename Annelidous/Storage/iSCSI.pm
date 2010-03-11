package Annelidous::Storage::iSCSI;
use base 'Annelidous::Storage';

sub new {
    my $invocant = shift;
    my $class   = ref($invocant) || $invocant;
    my $self={
		device_name=>$dev,
		description=>$desc,
		path=>"$path",
        @_
    };
    bless $self, $class;
    return $self;
}

