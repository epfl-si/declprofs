#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Workflows.pm
# Description:  Gestion des workflows externes.
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Fri Sep 11 14:32:37 CEST 2015
# Version:      1.0
# Revision:     
#
##############################################################################
#
#
package Accred::Workflows;

use strict;
use utf8;
use LWP::UserAgent;

use Accred::Utils;

my $objecttypes = {
  Right => {
         id => 'Right',
       name => 'Right',
    labelfr => 'droit',
    labelen => 'right',
  },
  Role => {
         id => 'Role',
       name => 'Role',
    labelfr => 'rôle',
    labelen => 'role',
  },
};

my $allactions = {
  grantright => {
          name => 'grantright',
       labelfr => "Attribution d'un droit",
       labelen => 'Right attribution',
    objecttype => 'Right',
  },
  revokeright => {
          name => 'revokeright',
       labelfr => "Suppression d'un droit",
       labelen => 'Right revocation',
    objecttype => 'Right',
  },
  grantrole => {
          name => 'grantrole',
       labelfr => "Attribution d'un rôle",
       labelen => 'Role attribution',
    objecttype => 'Role',
  },
  revokerole => {
          name => 'revokerole',
       labelfr => "Suppression d'un rôle",
       labelen => 'Role revocation',
    objecttype => 'Role',
  },
};

sub new {
  my ($class, $req) = @_;
  my  $self = {
         req => $req || {},
        utf8 => 1,
      errmsg => undef,
        fake => 0,
       debug => 0,
     verbose => 0,
       trace => 0,
  };
  bless $self;
  $self->{accredconf} = $req->{accredconf};
  $self->{lang}       = $req->{lang} || 'en';
  Accred::Utils::import ();
  importmodules ($self, 'AccredDB');
  return $self;
}

sub listWorkflows {
  my ($self) = @_;
  my @workflows =  $self->{accreddb}->dbselect (
    table => 'workflows',
     what => [ '*', ],
  );
  foreach (@workflows) {
    my $actionname = $_->{action};
    my     $action = $allactions->{$actionname};
    $action->{label} = ($self->{lang} eq 'en')
      ? $action->{labelen}
      : $action->{labelfr}
      ;
    my $objtype = $_->{objtype};
    my   $objid = $_->{objid};
    $_->{action}  = $action;
    #$_->{objType} = $self->getObjectType ($objtype);
    $_->{object}  = $self->getObject ($objtype, $objid);
  }
  return @workflows;
}

sub getWorkflow {
  my ($self, $workid) = @_;
  my @workflows =  $self->{accreddb}->dbselect (
    table => 'workflows',
     what => [ '*', ],
    where => {
      id => $workid,
    },
  );
  return unless @workflows;
  my     $workflow = shift @workflows;
  my   $actionname = $workflow->{action};
  my       $action = $allactions->{$actionname};
  $action->{label} = ($self->{lang} eq 'en')
    ? $action->{labelen}
    : $action->{labelfr}
    ;
  my $objtype = $workflow->{objtype};
  my   $objid = $workflow->{objid};
  $workflow->{internal} = ($workflow->{url} eq 'Internal');
  $workflow->{action}   = $action;
  $workflow->{object}   = $self->getObject ($objtype, $objid);
  return $workflow;
}

sub addWorkflow {
  my ($self, $workflow, $author) = @_;
  importmodules ($self, 'Logs');
  my $actname = $workflow->{action};
  my  $action = $allactions->{$actname};
  unless ($action) {
    $self->{errmsg} = "Unknown action name : $actname";
    return;
  }
  $workflow->{objtype} = $action->{objecttype};

  my $workflowid = $self->{accreddb}->dbinsert (
    table => 'workflows',
      set => $workflow,
  );
  unless ($workflowid) {
    $self->{errmsg} = "DB error : $self->{accreddb}->{errmsg}";
    return;
  }
  $self->{logs}->log ($author, "addworkflow",
    $workflow->{name},
    $workflow->{action},
    $workflow->{objid},
    $workflow->{url},
  );
  return $workflowid;
}

sub modWorkflow {
  my ($self, $workflow, $author) = @_;
  importmodules ($self, 'Logs');
  my $workid = $workflow->{id};

  my $oldworkflow = $self->getWorkflow ($workid);
  return unless $oldworkflow;

  my $status = $self->{accreddb}->dbrealupdate (
    table => 'workflows',
      set => $workflow,
    where => {
      id => $workid,
    },
  );
  unless ($status) {
    $self->{errmsg} = "DB error : $self->{accreddb}->{errmsg}";
    return;
  }
  my $newworkflow = $self->getWorkflow ($workid);
  return unless $newworkflow;

  my @logargs = ();
  foreach my $attr ('name', 'action', 'objtype', 'objid', 'url') {
    push (@logargs, $attr, $oldworkflow->{$attr}, $newworkflow->{$attr})
      if ($newworkflow->{$attr} ne $oldworkflow->{$attr});
  }
  return 1 unless @logargs;
  $self->{logs}->log ($author, 'modifyworkflow', $workid, @logargs);
  return 1;
}

sub deleteWorkflow {
  my ($self, $workflowid, $author) = @_;
  importmodules ($self, 'Logs');
  my @tables = (
    'workflows_pending',
  );
  foreach my $table (@tables) {
    my $status = $self->{accreddb}->dbdelete (
      table => $table,
      where => {
        workid => $workflowid,
      },
    );
    return unless $status;
  }
  my $status = $self->{accreddb}->dbdelete (
    table => 'workflows',
    where => {
      id => $workflowid,
    },
  );
  unless ($status) {
    $self->{errmsg} = "DB error : $self->{accreddb}->{errmsg}";
    return;
  }
  $self->{logs}->log ($author, "deleteworkflow", $workflowid);
  return 1;
}

sub searchWorkflow {
  my ($self, $actionname, $objid) = @_;
  my $action = $allactions->{$actionname};
  return unless $action;
  my $objtype = $action->{objecttype};
  return unless $objtype;
  
  my @workflows =  $self->{accreddb}->dbselect (
    table => 'workflows',
     what => [ '*', ],
    where => {
        action => $actionname,
       objtype => $objtype,
         objid => $objid,
    },
  );
  return unless @workflows;
  my $workflow = shift @workflows;
  my       $action = $allactions->{$actionname};
  $action->{label} = ($self->{lang} eq 'en')
    ? $action->{labelen}
    : $action->{labelfr}
    ;
  $workflow->{internal} = ($workflow->{url} eq 'Internal');
  $workflow->{action}   = $action;
  $workflow->{object}   = $self->getObject ($objtype, $objid);
  return $workflow;
}

sub startWorkflow {
  my ($self, $workflow, $userid, $unitid, $persid) = @_;
  importmodules ($self, 'InternalWorkflow');
  if ($workflow->{internal}) {
    my $status = $self->{internalworkflow}->startWorkflow (
      $workflow, $userid, $unitid, $persid,
    );
    return unless $status;
  } else {
    my  $action = $workflow->{action}->{name};
    my $objtype = $workflow->{objtype};
    my   $objid = $workflow->{objid};
    my  $pendid = $self->{accreddb}->dbinsert (
      table => 'workflows_pending',
        set => {
          workid => $workflow->{id},
          userid => $userid,
          unitid => $unitid,
          persid => $persid,
        }
    );
    unless ($pendid) {
      $self->{errmsg} = $self->{accreddb}->{errmsg};
      return;
    }
    #
    # Call external URL.
    #
    my $url = $workflow->{url};
    my $sep = ($url =~ /\?/) ? '&' : '?';
    my $object = $self->getObject ($objtype, $objid);
    return unless $object;
    my $objname = $object->{name};
    $url .= $sep
         . "wflid=$pendid"      # wflid=43
         . "&action=$action"    # action=grantright
         . "&objid=$objname"    # objid=sig5000
         . "&userid=$userid"    # userid=123456
         . "&unitid=$unitid"    # unitid=FF0037
         . "&destid=$persid"    # persid=172687
    ;
    #my $realm = 'XI REST Servlet';
    my  $realm = 'PI REST Adapter';
    my    $lwp = new LWP::UserAgent;
    my $netloc = $workflow->{url};
    $netloc =~ s/^.*:\/\/([^\/]+)\/.*$/$1/;
    unless ($netloc =~ /:/) { # no port
      $netloc .= ':443' if ($url =~ /^https:/);
      $netloc .=  ':80' if ($url =~ /^http:/);
    }
    warn scalar localtime, " Accred::startWorkflow: url = $url, netloc = $netloc\n";
    my $httpreq = new HTTP::Request ('GET', $url);
    unless ($httpreq) {
      $self->{errmsg} = 'Unable to send request to Workflow server.';
      warn scalar localtime, " Accred::startWorkflow:errmsg = $self->{errmsg}\n";
      return;
    }
    my $user = $self->{accredconf}->{sapworkflowsuser};
    my $pass = $self->{accredconf}->{sapworkflowspass};
    $lwp->credentials ($netloc, $realm, $user, $pass);
    my $res = $lwp->request ($httpreq);
    if ($res->code != 200) {
      $self->{errmsg} = 'Workflow server returns ' . $res->status_line;
      warn scalar localtime, " Accred::startWorkflow:errmsg = $self->{errmsg}\n";
      return;
    }
  }
  return 1;
}

sub endWorkflow {
  my ($self, $pendapp, $decision) = @_;
  importmodules ($self, 'Rights', 'Roles', 'InternalWorkflow');
  return 0 unless ($decision =~ /^(Accept|Deny)$/);

  my $workflow = $pendapp->{workflow};
  if ($workflow->{internal}) {
    $self->{internalworkflow}->endWorkflow (
      $pendapp, $decision,
    );
    return;
  }
  return 1 if ($decision eq 'Deny'); # Action refused, do nothing.
  
  my  $action = $workflow->{action}->{name};
  my $objtype = $workflow->{objtype};
  my   $objid = $workflow->{objid};

  if ($action =~ /^(grant|revoke)right$/) {
    my $newvalue = ($1 eq 'grant') ? 'y' : 'd';
    $self->{rights}->setPersonRight (
      $pendapp->{persid},
      $pendapp->{unitid},
      $workflow->{objid},
      $newvalue,
      $pendapp->{userid},
    );
  }
  elsif ($action =~ /^(grant|revoke)role$/) {
    my $newvalue = ($1 eq 'grant') ? 'y' : 'd';
    $self->{roles}->setPersonRole (
      $pendapp->{persid},
      $pendapp->{unitid},
      $workflow->{objid},
      $newvalue,
      $pendapp->{userid},
    );
  }
  return 1;
}

sub approveAction {
  my ($self, $pendid, $signerid, $decision) = @_;
  importmodules ($self, 'Logs');
  unless ($decision =~ /^(Accept|Deny)$/) {
    $self->{errmsg} = "approveAction : invalid decision : $decision";
    return;
  }
  my $pendapp = $self->getPendingApproval ($pendid);
  unless ($pendapp) {
    $self->{errmsg} = "approveAction : unknown wflid : $pendid";
    return;
  }
  $self->{accreddb}->dbinsert (
    table => 'workflows_approved',
      set => {
          pendid => $pendid,
         objtype => 'External',
           objid => 0,
        signerid => 0,
        decision => $decision,
            date => 'now',
     },
     noval => 1,
  );
  #
  # Logs
  #
  $signerid ||= '000000';
  my   $unitid = $pendapp->{unitid};
  my  $recipid = $pendapp->{persid};
  my $workflow = $pendapp->{workflow};
  my $wobjtype = $workflow->{objtype};
  my   $wobjid = $workflow->{objid};
  my   $opcode = ($decision eq 'Accept') ? 'approveaction' : 'refuseaction';
    
  $self->deletePendingApproval ($pendid);

  $self->{logs}->log ($signerid, $opcode, $wobjtype, $wobjid, $unitid, $recipid);
  #
  # End workflow.
  #
  my $status = $self->endWorkflow ($pendapp, $decision);
  unless ($status) {
    $self->{errmsg} = "Unable to end workflow $pendid,";
    return;
  }
  return 1;
}

sub actionPending {
  my ($self, $workflow, $unitid, $persid) = @_;

  my @actions =  $self->{accreddb}->dbselect (
    table => 'workflows_pending',
     what => [ '*' ],
    where => {
      workid => $workflow->{id},
      unitid => $unitid,
      persid => $persid,
    },
  );
  return shift @actions if @actions;
  return;
}

sub userActionsPending {
  my ($self, $userid) = @_;
  my @pendingactions =  $self->{accreddb}->dbselect (
    table => 'workflows_pending',
     what => [ '*' ],
    where => {
      userid => $userid,
    },
  );
  foreach my $pendingaction (@pendingactions) {
    my   $workid = $pendingaction->{workid};
    my $workflow = $self->getWorkflow ($workid);
    if ($workflow->{internal}) {
      # Maybe something.
    }
    $pendingaction->{workflow} = $workflow;
  }
  return @pendingactions;
}

sub checkPending {
  my ($self, $pendid, $actionname, $userid, $objid, $unitid, $persid, $decision) = @_;
  my $pendapp = $self->getPendingApproval ($pendid);
  unless ($pendapp) {
    $self->{errmsg} = "checkPending : unknown wflid : $pendid";
    return;
  }
  my  $workflow = $pendapp->{workflow};
  if ($actionname && ($actionname ne $workflow->{action})) {
    $self->{errmsg} = "checkPending : wflid and actionname doesn't match";
    return;
  }
  if ($userid && ($userid ne $pendapp->{userid})) {
    $self->{errmsg} = "checkPending : wflid and userid doesn't match";
    return;
  }
  if ($objid && ($objid ne $workflow->{objid})) {
    $self->{errmsg} = "checkPending : wflid and objid doesn't match";
    return;
  }
  if ($unitid && ($unitid ne $pendapp->{unitid})) {
    $self->{errmsg} = "checkPending : wflid and unitid doesn't match";
    return;
  }
  if ($persid && ($persid ne $pendapp->{persid})) {
    $self->{errmsg} = "checkPending : wflid and $persid doesn't match";
    return;
  }
}

sub getPendingApproval {
  my ($self, $pendid) = @_;
  importmodules ($self, 'InternalWorkflow');
  my @pendapps = $self->{accreddb}->dbselect (
    table => 'workflows_pending',
     what => [ '*' ],
    where => {
       id => $pendid,
    },
  );
  return unless @pendapps;
  my $pendapp = shift @pendapps;
  #
  # Workflow.
  #
  my $workid = $pendapp->{workid};
  $pendapp->{workflow} = $self->getWorkflow ($workid);
  #
  # Already approved
  #
  my @approved = $self->getApprovalSignatures ($pendapp);
  $pendapp->{approved} = \@approved;

  if ($pendapp->{workflow}->{internal}) {
    my $workid = $pendapp->{workid};
    #
    # Needed approvals.
    #
    my @needed = $self->{internalworkflow}->neededApprovals ($workid);
    $pendapp->{needed} = \@needed;
    #
    # Missing approvals
    #
    $pendapp->{missings} = $self->{internalworkflow}->missingApprovals ($pendapp);
  }
  return $pendapp;
}

sub getApprovalSignatures {
  my ($self, $pendapp) = @_;
  my @approved = $self->{accreddb}->dbselect (
    table => 'workflows_approved',
     what => [ '*' ],
    where => {
      pendid => $pendapp->{id},
    },
    noval => 1,
  );
  return unless @approved;
  my @apprs;
  foreach my $appr (@approved) {
    my $objtype = $appr->{objtype};
    my   $objid = $appr->{objid};
    $appr->{object} = $self->getObject ($objtype, $objid);
    push (@apprs, $appr);
  }
  return @apprs;
}

sub searchPendingApproval {
  my ($self, %args) = @_;
  my $where = \%args;
  my @pendids = $self->{accreddb}->dbselect (
    table => 'workflows_pending',
     what => [ '*' ],
    where => $where,
  );
  return @pendids;
}

sub addPendingApproval {
  my ($self, $workid, $userid, $unitid, $persid) = @_;
  
  my $pendid = $self->{accreddb}->dbinsert (
    table => 'workflows_pending',
      set => {
         workid => $workid,
         userid => $userid,
         unitid => $unitid,
         persid => $persid,
      },
  );
  return $pendid;
}

sub deletePendingApproval {
  my ($self, $pendid) = @_;
  $self->{accreddb}->dbdelete (
    table => 'workflows_pending',
    where => {
      id => $pendid,
    },
  );
  return 1;
}

sub pendingApprovalSetStep {
  my ($self, $pendid, $step) = @_;
  $self->{accreddb}->dbupdate (
    table => 'workflows_pending',
      set => {
        step => $step,
      },
    where => {
      id => $pendid,
    },
    nohist => 1,
  );
  return 1;
}

#
# Objects
#
sub listObjects {
  my ($self,$objtype) = @_;
  importmodules ($self, 'RightsAdmin', 'RolesAdmin');
  if ($objtype eq 'Right') {
    my @rights = $self->{rightsadmin}->listRights ();
    return @rights;
  }
  if ($objtype eq 'Role') {
    my @roles = $self->{rolesadmin}->listRoles ();
    return @roles;
  }
  return;
}

sub getObject {
  my ($self, $objtype, $objid) = @_;
  importmodules ($self, 'RightsAdmin', 'RolesAdmin');
  if ($objtype eq 'Right') {
    my $right = $self->{rightsadmin}->getRight ($objid);
    $right->{label} = ($self->{lang} eq 'en')
      ? 'Right ' . $right->{labelen}
      : 'Droit ' . $right->{labelfr}
      ;
    return $right;
  }
  if ($objtype eq 'Role') {
    my $role = $self->{rolesadmin}->getRole ($objid);
    $role->{label} = ($self->{lang} eq 'en')
      ? 'Role ' . $role->{labelen}
      : 'Rôle ' . $role->{labelfr}
      ;
    return $role;
  }
  return;
}

sub listObjectTypes {
  my ($self) = @_;
  return $objecttypes;
}

sub getObjectType {
  my ($self, $objtype) = @_;
  my $objType = $objecttypes->{$objtype};
  $objType->{label} = ($self->{lang} eq 'en')
    ? $objType->{labelen}
    : $objType->{labelfr}
    ;
  return $objType;
}
#
# Actions
#
sub listActions {
  my ($self) = @_;
  return $allactions;
}

sub getAction {
  my ($self, $name) = @_;
  my $action = $allactions->{$name};
  return unless $action;
  $action->{label} = ($self->{lang} eq 'en')
    ? $action->{labelen}
    : $action->{labelfr}
    ;
  return $action;
}

sub actionManaged {
  my ($self, $actionname, $objid) = @_;
  my $workflow = $self->searchWorkflow ($actionname, $objid);
  return $workflow;
}


1;


