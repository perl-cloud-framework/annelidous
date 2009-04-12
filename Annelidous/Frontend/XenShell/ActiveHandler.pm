package Annelida::Frontend::XenShell::ActiveHandler;

sub TIESCALAR {
	my $invocant=shift;
    my $self={};
    bless $self, 'Annelida::Frontend::XenShell::ActiveHandler';
    $self->{vm}=shift;
    return $self;
}

sub STORE {
    my $self=shift;
    return $self->{vm}->instance($_[1]);
}

sub FETCH {
    my $self=shift;
    return $self->{vm}->instance;
}

1;
