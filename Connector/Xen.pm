#!/usr/bin/perl

package Annelida::Connector::Xen;
use base 'Annelida::Connector';

sub new {
	my $self={};
	bless $self, shift;
	return $self;
}

# Launch client guest OS...
# takes a client_pool as argument 
sub boot {
    my $self=shift;
    my $hostname=shift;
    my $bitness=shift;

    #my @userinfo=getpwent($guest->{username});
    #my $homedir=$userinfo[7];

    # replace any C/v/Vs with c'
    $guest->{username} =~ s/^(c|v)?/c/i;

    print "Starting guest: ".$guest->{username}."\n";
    my @exec=("ssh","-l","root",$hostname,"xm","create",
    "/dev/null",
    "name='".$guest->{username}."'",
    "kernel='/boot/xen/vmlinuz-".$bitness."'",
    "memory=".$guest->{'memory'},
    "vif='vifname=".$guest->{username}.",ip=".$guest->{ip}."'",
    #"disk='phy:mapper/SanXenDomains-".$guest->{username}.",sda1,w'",
    "disk='phy:mapper/XenDomains-".$guest->{username}.",sda1,w'",
    #"disk='phy:mapper/XenSwap-".$guest->{username}."swap,sda2,w'",
    "disk='phy:mapper/XenDomains-".$guest->{username}."swap,sda2,w'",
    "root='/dev/sda1 ro'",
    "extra='3 console=xvc0'",
    "vcpus=1");
    print join " ", @exec;
    system (@exec);

    # Configure IPv6 router IP for vif (no proxy arp here, we give a whole subnet)
    if ($guest->{'ip6router'}) {
        my @exec2=("ssh","-l","root",$hostname,"ifconfig","inet6","add",$guest->{username},$guest->{ip6router});
        print join " ", @exec2;
        system (@exec2);
    }
}

1;
