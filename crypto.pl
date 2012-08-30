#!/usr/bin/perl
#
# A Cryptogram Game
# Copyright (c) 2006 Eric Mulvaney
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use warnings;
use strict;

my @lines;
my %codes;
my %codesInv;

sub unassoc {
  (my $key) = @_;
  if(not defined $key) {
    %codes = ();
    %codesInv = ();
  } elsif(exists $codes{$key}) {
    my $value = $codes{$key};
    delete $codes{$key};
    delete $codesInv{$value};
  } else {
    print "$key is not associated.\n";
  }
}

sub assoc {
  (my $key, my $value) = @_;
  if(exists $codesInv{$value}) {
    my $k = $codesInv{$value};
    print "\a*** $k -> $value is already bound. ***\n";
  } else {
    unassoc $key if exists $codes{$key};
    print "Associating $key -> $value.\n";
    $codes{$key} = $value;
    $codesInv{$value} = $key;
  }
}

sub display {
  my $keys   = join '', keys   %codes;
  my $values = join '', values %codes;
  print "\n";
  for(my $i = 0; $i < @lines; ++$i) {
    my $line = $lines[$i];
    print "* $i $line";
    $_ = $line;
    eval "tr/${keys}A-Z/$values /";
    print "*   $_";
    print "*\n";
  }
  return 1;
}

sub manual {
  unassoc();
  @lines = ();
  print "Enter cryptogram:\n";
  my $i = 0;
  for(;; ++$i) {
    print "$i? ";
    $_ = uc <STDIN>;
    last if /^\s*$/;
    push @lines, $_;
  }
  return $i;
}

sub fortune {
  unassoc();
  my $scramble = '';
  my @letters = 'A' .. 'Z';
  while(@letters) {
    my $i = int(rand(@letters));
    my $c = $letters[$i];
    splice @letters, $i, 1;
    $scramble .= $c;
  }
  @lines = `fortune -s`;
  for(my $i = 0; $i < @lines; ++$i) {
    next if $lines[$i] !~ /^\s*$/;
    splice @lines, $i, 1;
    redo;
  }
  foreach(@lines) {
    $_ = uc $_;
    eval "tr/A-Z/$scramble/";
  }
  return scalar @lines;
}

sub ask {
  (my $msg) = @_;
  print "$msg ";
  return <STDIN> =~ /yes|y/i;
}

sub edit {
  (my $i, my $re, my $sub) = @_;
  if(defined $re && $i > $#lines) {
    print "No such line.\n";
    return 0;
  } elsif($i > @lines) {
    print "You can edit the line past the last, but no further.\n";
    return 0;
  } else {
    print "Editing line $i (case insensitive):\n" if not defined $re;
    print "* $i $lines[$i]" if $i < @lines;
    my $new;
    if(defined $re) {
      $new = $lines[$i];
      $new =~ s/$re/$sub/ig;
    } else {
      print "- $i ";
      $new = uc <STDIN>;
    }
    print "* $i $new";
    $lines[$i] = $new if ask("Commit changes?");
    return 1;
  }
}

fortune() or manual();
for(my $redraw = 1;;) {
  display() if $redraw;
  $redraw = 1;
  print "\n? ";
  my $cmd = <STDIN>;
  chomp $cmd;
  if($cmd =~ /^([a-z])([a-z])?$/i) {
    if(defined $2) { assoc(uc $1, uc $2); }
    else	   { unassoc(uc $1);	  }
  } elsif($cmd =~ /^:e\s+(\d+)\s*$/) {
    $redraw = edit($1);
  } elsif($cmd =~ /^:e\s+(\d+)\s+(\w+)\s+(\w+)\s*$/) {
    $redraw = edit($1, uc $2, uc $3);
  } elsif($cmd =~ /^:d\s+(\d+)$/) {
    if($1 > $#lines) {
      print "No such line.\n";
      $redraw = 0;
    } else {
      print "* $1 $lines[$1]";
      splice @lines, $1, 1 if ask("Delete this line?");
    }
  } elsif($cmd =~ /^:o\s+(.+\S)/) {
    if(open IN, "< $1") {
      %codes = split ' ', <IN>;
      $codesInv{$codes{$_}} = $_ foreach keys %codes;
      @lines = <IN>;
      close IN;
      print "Done.\n";
    } else {
      print "Can't open $1: $!\n";
      $redraw = 0;
    }
  } elsif($cmd =~ /^:s\s+(.+\S)/) {
    if(open OUT, "> $1") {
      print OUT join(' ', %codes), "\n";
      print OUT foreach @lines;
      close OUT;
      print "Done.\n";
    } else {
      print "Can't open $1: $!\n";
      $redraw = 0;
    }
  } elsif($cmd eq ':r') {
    unassoc() if ask("Reset game?");
  } elsif($cmd eq ':n') {
    fortune() or manual();
  } elsif($cmd eq ':n-') {
    manual();
  } elsif($cmd eq ':q') {
    last if ask("Are you sure?");
  } elsif($cmd =~ /:?\?|:h|help/i) {
    print <<EOF;
    
  Available Commands:
  
  XY	Associate X -> Y
  X	Remove the association X -> Z (for some Z)
  :r	Reset the game (clear all associations)
  :n	Generate a new game (using fortune if available)
  :n-	Manually generate a new game
  :o X	Load game from file X
  :s X	Save game to file X
  :e N	Edit line N
  :d N	Delete line N
  :q	Quit
EOF
    $redraw = 0;
  } elsif($cmd !~ /^\s*$/) {
    print "Huh?\n";
    $redraw = 0;
  }
}
