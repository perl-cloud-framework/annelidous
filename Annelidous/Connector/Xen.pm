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
