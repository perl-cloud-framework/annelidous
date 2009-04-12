#!/usr/bin/perl

package Annelidous::Connector;

sub new {
	my $self={};
	bless $self, shift;
	return $self;
}

sub instance {
	my $self=shift;
	$self->{instance}=shift;
	return $self->{instance};
}

1;