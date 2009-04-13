#!/usr/bin/perl
#
# Annelidous - the flexibile cloud management framework
# Copyright (C) 2009  Eric Windisch <eric@grokthis.net>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

package Annelidous::Connector::Xen;
use base 'Annelidous::Connector';

sub new {
	my $self={
	    transport=>'Annelidous::Transport::SSH',
	    account=>undef,
	    @_
	};
	bless $self, shift;
	
	# Initialize a new transport.
	$self->{_transport}=exec "new $self->{transport} (".'$self->{account})};';
	return $self;
}

# Launch client guest OS...
# takes a client_pool as argument 
sub boot {
    my $self=shift;
    my $guest=$self->{account};
    my $bitness=$guest->{bitness};
       
    my $hostname;
    if (defined ($guest->{host})) {
        $hostname=$guest->{host};
    } elsif (defined ($guest->{cluster})) {
        $hostname=$self->parent->search->get_cluster($guest->{cluster})->get_host;
    } else {
        $hostname=$self->parent->search->get_default_cluster()->get_host;
    }
    
    #my @userinfo=getpwent($guest->{username});
    #my $homedir=$userinfo[7];

    print "Starting guest: ".$guest->{username}."\n";
    my @exec=("xm","create",
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
    $self->transport->exec(@exec);

    # Configure IPv6 router IP for vif (no proxy arp here, we give a whole subnet)
    if ($guest->{'ip6router'}) {
        my @exec2=("ssh","-l","root",$hostname,"ifconfig","inet6","add",$guest->{username},$guest->{ip6router});
        print join " ", @exec2;
        system (@exec2);
    }
}

sub reboot {
    my $self=shift;
    $self->shutdown();
    $self->boot();
}

sub shutdown {
    my $self=shift;
    $self->transport->exec("xm","shutdown",$self->{account}->{username});
}

sub console {
    my $self=shift;
    # TODO: IMPLEMENT Xen Console
    # provided is a suggested layout for this method...
    #my $cap=new Annelidous::Capabilities;
    #$cap->add("serial");
    # Get the console here.
    #$self->transport->exec("xm");
    #if () {
    #    $cap->add("tty");
    #} else {
    #    $cap->add("vnc");
    #}
}

sub transport {
    shift->{_transport};
}

1;
