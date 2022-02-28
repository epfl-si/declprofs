#!/usr/bin/perl
#
##############################################################################
#
# File Name:    AccredDB.pm
# Description:  Accès à la base de donnees D'accreditation
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Tue Jul 16 09:43:03 CEST 2002
# Revision:     
#
##############################################################################
#
package Accred::AccredDB;
#
use strict;
use utf8;
use Carp;

use lib qq(/opt/dinfo/lib/perl);
use Accred::Local::LocalDB;
use Accred::Utils;

our $errmsg;

sub new {
  my ($class, $req) = @_;
  my $def = {
        fake => 0,
       debug => 0,
     verbose => 0,
       trace => 0,
  };
  my $self = {
             req => $req || {},
    accredcadidb => undef,
          dbname => undef,
         dateref => undef,
            utf8 => 1,
          errmsg => undef,
            fake => 0,
           debug => 0,
         verbose => 0,
           trace => 0,
  };
  bless $self;
  $self->{verbose}  = $def->{verbose} if defined $def->{verbose};
  $self->{trace}    = $def->{trace}   if defined $def->{trace};
  $self->{dbname} ||= 'accred';
  $self->{accredcadidb} ||= new Accred::Local::LocalDB (
    dbname => $self->{dbname},
     trace => $self->{trace},
      utf8 => $self->{utf8},
  );
  $self->{dateref} = $self->{req}->{dateref};
  return $self;
}

sub dbsafequery {
  my ($self, $sql, @values) = @_;
  carp "dbsafequery:sql = $sql, values = @values\n" if ($self->{verbose} >= 6);
  
  unless ($self->{accredcadidb}) {
    $self->{accredcadidb} = new Accred::Local::LocalDB (
      dbname => $self->{dbname},
       trace => $self->{trace},
        utf8 => $self->{utf8},
    );
  }
  return unless $self->{accredcadidb};
  my $sth = $self->{accredcadidb}->prepare ($sql);
  unless ($sth) {
    warn scalar localtime, "Trying to reconnect..., sql = $sql";
    $sth = $self->{accredcadidb}->prepare ($sql);
    warn scalar localtime, "Reconnection failed." unless $sth;
  }
  my $rv = $sth->execute (@values);
  unless ($rv) {
    warn scalar localtime, "Trying to reconnect..., sql = $sql";
    $rv = $sth->execute (@values);
    unless ($rv) {
      warn scalar localtime, "Reconnection failed.";
      printstack ();
    }
  }
  return $sth;
}

sub setverbose {
  my $self = shift;
  $self->{verbose} = shift;
}

sub dbselect {
  my        $self = shift;
  my        $args = { @_ };
  my       $table = $args->{table};
  my        $what = $args->{what};
  my       $where = $args->{where};
  my         $key = $args->{key};
  my       $order = $args->{order}    || 'debval';
  my         $seq = $args->{sequence} || 'asc';
  my     $listold = $args->{listold};
  my       $noval = $args->{noval};
  my    $distinct = $args->{distinct};
  my       $debug = $args->{debug};
  my $checkbounds = $args->{checkbounds};
  my     $dateref = $self->{dateref} ? "'$self->{dateref}'" :  'now()';

  my ($sqlwhat,      @allwhat) = makewhatstring  ($what, $key);
  my ($sqlwhere, @wherevalues) = makewherestring ($where);

  my $select = $distinct ? "select distinct" : "select";
  my    $sql = qq{$select $sqlwhat from $table where $sqlwhere};
  $sql      .= qq{ and (debval is NULL or debval <= $dateref)}.
               qq{ and (finval is NULL or finval  > $dateref)}
    unless ($listold || $noval);
  $sql      .= qq{ and datedeb <= $dateref and}.
               qq{ (datefin is null or datefin = 0 or datefin > $dateref)}
    if $checkbounds;
  $sql .= qq{ order by $order $seq}
    unless ($noval && ($order eq 'debval'));

  my $sth = $self->dbsafequery ($sql, @wherevalues) || return;
  if ($key) {
    my %results;
    if ($sqlwhat eq '*') {
      while (my $result = $sth->fetchrow_hashref) {
        my $val = $result->{$key};
        $results {$val} = (ref $what eq 'ARRAY' || $what eq '*')
          ? $result
          : $result->{$what}
          ;
      }
    } else {
      my @whats = (ref $what eq 'ARRAY') ? @$what : ($what);
      push (@whats, $key);
      while (my (@fields) = $sth->fetchrow) {
        my $result;
        foreach my $field (@whats) {
          $result->{$field} = shift @fields;
        }
        my $val = $result->{$key};
        $results {$val} = (ref $what eq 'ARRAY' || $what eq '*')
          ? $result
          : $result->{$what}
          ;
      }
    }
    return %results;
  } else {
    my @results;
    if ($sqlwhat eq '*') {
      while (my $result = $sth->fetchrow_hashref) {
        push (@results, $result);
      }
    } else {
      my @whats = (ref $what eq 'ARRAY') ? @$what : ($what);
      while (my (@fields) = $sth->fetchrow) {
        my $result;
        foreach my $field (@whats) {
          $result->{$field} = shift @fields;
        }
        push (@results, (ref $what eq 'ARRAY') ? $result : $result->{$what});
      }
    }
    return @results;
  }
}

sub dbupdate {
  my    $self = shift;
  my    $args = { @_ };
  my   $table = $args->{table};
  my     $set = $args->{set};
  my   $where = $args->{where};
  my  $nohist = $args->{nohist};
  my   $noval = $args->{noval};
  my $updonly = $args->{updonly};
  
  return if $self->{dateref};
  my ($sqlwhere, @wherevalues) = makewherestring ($where);

  if ($nohist) {
    my ($sqlset, @setvalues) = makesetstring ($set);
    my $sql;
    if ($sqlwhere) {
      $sql = qq{update $table set $sqlset where $sqlwhere};
      $sql .= qq{
           and (debval is NULL or debval <= now())
           and (finval is NULL or finval  > now())
      } unless $noval;
      $self->dbsafequery ($sql, @setvalues, @wherevalues) || return;
    } else {
      $sql = qq{insert into $table set $sqlset};
      $self->dbsafequery ($sql, @setvalues) || return;
    }
    return;
  }

  $sqlwhere = 1 unless $sqlwhere;
  my @olds = $self->dbselect (
    table => $table,
     what => '*',
    where => $where,
  );
  foreach my $old (@olds) {
    my $newset = { %$set };
    my $something = 0;
    foreach my $key (keys %$old) {
      if (exists $newset->{$key} && $newset->{$key} ne $old->{$key}) {
        $something = 1;
        last;
      }
    }
    next unless $something;
    my $sql = qq{
      update $table
         set finval = now()
       where $sqlwhere
         and (debval is NULL or debval <= now())
         and (finval is NULL or finval  > now())
    };
    $self->dbsafequery ($sql, @wherevalues) || return;

    foreach my $key (keys %$old) {
      next if ($key =~ /^(deb|fin)val$/);
      unless (exists $newset->{$key}) {
        $newset->{$key} = $old->{$key};
      }
    }
    my ($sqlset, @setvalues) = makesetstring ($newset);
    my $sql = qq{insert into $table set $sqlset, debval = now()};
    $self->dbsafequery ($sql, @setvalues) || return;
  }
  unless (@olds || $updonly) {
    foreach my $key (keys %$where) {
      $set->{$key} = $where->{$key} unless exists $set->{$key};
    }
    $set->{author} = $args->{author} if $args->{author};
    my  ($sqlset, @setvalues) = makesetstring ($set);
    my $sql = qq{insert into $table set $sqlset, debval = now()};
    $self->dbsafequery ($sql, @setvalues) || return;
  }
  return 1;
}

sub dbrealupdate {
  my    $self = shift;
  my    $args = { @_ };
  my   $table = $args->{table};
  my     $set = $args->{set};
  my   $where = $args->{where};

  return if $self->{dateref};
  my ($sqlwhere, @wherevalues) = makewherestring ($where);
  my   ($sqlset, @setvalues)   = makesetstring   ($set);

  my $sql = qq{
    update $table
       set $sqlset
     where $sqlwhere
       and (debval is NULL or debval <= now())
       and (finval is NULL or finval  > now())
  };
  $self->dbsafequery ($sql, @setvalues, @wherevalues) || return;
  return 1;
}

sub dbinsert {
  my  $self = shift;
  my  $args = { @_ };
  my $table = $args->{table};
  my   $set = $args->{set};
  my $noval = $args->{noval};

  my ($sqlset, @setvalues) = makesetstring ($set);
  my $sql = qq{insert into $table set $sqlset};
  $sql   .= qq{, debval = now()} unless $noval;
  my $sth = $self->dbsafequery ($sql, @setvalues) || return;
  my  $id = $sth->{mysql_insertid};
  $sth->finish;
  return $id || 1;
}

sub dbdelete {
  my    $self = shift;
  my    $args = { @_ };
  my   $table = $args->{table};
  my   $where = $args->{where};
  my  $author = $args->{author};

  return if $self->{dateref};
  my   $sqlset = "finval = now()";
  $sqlset .= ", author = '$author'" if $author;
  my ($sqlwhere, @wherevalues) = makewherestring ($where);
  my $sql = qq{
    update $table
       set $sqlset
     where $sqlwhere
       and (debval is NULL or debval <= now())
       and (finval is NULL or finval  > now())
  };
  my $sth = $self->dbsafequery ($sql, @wherevalues) || return;
  $sth->finish;
  return 1;
}

sub dbrealdelete {
  my  $self = shift;
  my  $args = { @_ };
  my $table = $args->{table};
  my $where = $args->{where};

  my ($sqlwhere, @wherevalues) = makewherestring ($where);
  my $sql = qq{delete from $table where $sqlwhere};
  my $sth = $self->dbsafequery ($sql, @wherevalues) || return;
  $sth->finish;
  return 1;
}

sub makewhatstring {
  my ($what, $key) = @_;
  my @whats = (ref $what eq 'ARRAY') ? @$what : ($what);
  push (@whats, $key) if ($key && ($what ne '*'));

  my @dbwhats;
  foreach my $field (@whats) {
    push (@dbwhats, $field);
  }
  my $sqlwhat = join (', ', @dbwhats);
  return ($sqlwhat, @whats);
}

sub makewherestring {
  my $where = shift;
  my (@wheres, @values);
  foreach my $field (keys %$where) {
    if ($where->{$field} =~ /^now$/i) {
      push (@wheres, "$field = now()");
    }
    elsif ($where->{$field} =~ /^null$/i) {
      push (@wheres, "$field is null");
    }
    elsif (ref $where->{$field} eq 'ARRAY') {
      my $in = join (', ', map { '?' } @{$where->{$field}});
      push (@wheres, "$field in ($in)");
      push (@values, @{$where->{$field}});
    } else {
      push (@wheres, "$field = ?");
      push (@values, $where->{$field});
    }
  }
  my $wherestr = join (" and ", @wheres);
  $wherestr ||= 1;
  return ($wherestr, @values);
}

sub makesetstring {
  my $set = shift;
  my (@sets, @values);
  foreach my $field (keys %$set) {
    if ($set->{$field} =~ /^now$/i) {
      push (@sets, "$field = now()");
    }
    elsif ($set->{$field} =~ /^UUID_SHORT$/i) {
      push (@sets, "$field = UUID_SHORT()");
    }
    elsif ($set->{$field} =~ /^null$/i) {
      push (@sets, "$field = null");
    } else {
      push (@sets,   "$field = ?");
      push (@values, $set->{$field});
    }
  }
  my $setstr = join (", ", @sets);
  return ($setstr, @values);
}

sub getObject {
  my ($self, %args) = @_;
  my $args = \%args;
  
  my   $table = $args->{type};
  my $dateref = $self->{dateref} || 'now()';
  my ($field, $value);
  foreach my $fname (qw(id name labelfr)) {
    if ($args->{$fname}) {
      $field = $fname;
      $value = $args->{$fname};
      last;
    }
  }
  return unless $field;
  my $sql = qq{select * from $table where $field = ?};
  $sql   .= qq{ and (debval is NULL or debval <= ?)}.
            qq{ and (finval is NULL or finval  > ?)} unless $args->{noval};
  my @values = ($value);
  push (@values, $dateref, $dateref) unless $args->{noval};
  my $sth = $self->dbsafequery ($sql, @values) || return;
  my $result = $sth->fetchrow_hashref;
  $sth->finish;
  return unless $result;
  $result->{labelen} ||= $result->{labelfr};
  $result->{label} = ($self->{lang} eq 'en')
    ? $result->{labelen}
    : $result->{labelfr}
    ;
  return $result;
}

sub listAllObjects {
  my ($self, $table, %optargs) = @_;
  my $listold = $optargs {listold};
  my $dateref = $self->{dateref} || 'now()';

  my @values = ();
  my $sql = qq{select * from $table};
  unless ($listold) {
    $sql .= qq{ where (debval is NULL or debval <= ?)}.
            qq{   and (finval is NULL or finval  > ?)};
    @values = ($dateref, $dateref);
  }
  my $sth = $self->dbsafequery ($sql, @values) || return;
  my @results;
  while (my $result = $sth->fetchrow_hashref) {
    push (@results, $result);
  }
  $sth->finish;
  return @results;
}

sub error {
  my $self = shift;
  my $i = 0;
  my $client = $ENV {REMOTE_ADDR};
  my $stack = "@_ from $client, stack = \n";
  while (my ($pack, $file, $line, $subname, $hasargs, $wanrarray) = caller ($i++)) {
    $stack .= "$file:$line\n";
  }
  my $now = scalar localtime;
  die "[$now] [Accred warning] : $stack\n";
}

sub printstack {
  my $depth = 0;
  while (my ($package, $filename, $line) = caller ($depth++)) {
    warn "$filename : $package line $line.\n";
  }
}


1;

