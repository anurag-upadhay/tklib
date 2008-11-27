# ipentry.tcl --
#
#       An entry widget for IP addresses.
#
# Copyright (c) 2003-2008 Aaron Faupell <afaupell@users.sourceforge.net>
# Copyright (c) 2008 Pat Thoyts <patthoyts@users.sourceforge.net>
#  
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: ipentry.tcl,v 1.12 2008/11/27 10:13:59 patthoyts Exp $

package require Tk
package provide ipentry 0.3

namespace eval ::ipentry {
    namespace export ipentry
    # copy all the bindings from Entry class to our own IPEntrybindtag class
    foreach x [bind Entry] {
        bind IPEntrybindtag $x [bind Entry $x]
    }
    # then replace certain keys we are interested in with our own
    bind IPEntrybindtag <KeyPress>         {::ipentry::keypress %W %K}
    bind IPEntrybindtag <BackSpace>        {::ipentry::backspace %W}
    bind IPEntrybindtag <period>           {::ipentry::dot %W}
    bind IPEntrybindtag <Key-Right>        {::ipentry::arrow %W %K}
    bind IPEntrybindtag <Key-Left>         {::ipentry::arrow %W %K}
    bind IPEntrybindtag <FocusIn>          {::ipentry::FocusIn %W}
    bind IPEntrybindtag <FocusOut>         {::ipentry::FocusOut %W}
    bind IPEntrybindtag <<Paste>>          {::ipentry::Paste %W CLIPBOARD}
    bind IPEntrybindtag <<PasteSelection>> {::ipentry::Paste %W PRIMARY}
    bind IPEntrybindtag <Key-Tab>          {::ipentry::tab %W; break}

    if {[package vsatisfies [package provide Tk] 8.5]} {
        ttk::style layout IPEntryFrame {
            Entry.field -sticky news -border 1 -children {
                IPEntryFrame.padding -sticky news
            }
        }
        bind [winfo class .] <<ThemeChanged>> \
            [list +ttk::style layout IPEntryFrame \
                 [ttk::style layout IPEntryFrame]]
    }
}

# ipentry --
#
# main entry point - construct a new ipentry widget
#
# ARGS:
#       w       path name of widget to create
#
#               see ::ipentry::configure for args
#
# RETURNS:
#       the widget path name
#
proc ::ipentry::ipentry {w args} {
    set usettk [package vsatisfies [package provide Tk] 8.5]
    foreach {name val} $args { if {$name eq "-themed"} {set usettk $val} }
    if {$usettk} {
        ttk::frame $w -style IPEntryFrame -class IPEntry
    } else {
        frame $w -borderwidth 2 -relief sunken -class IPEntry
    }
    foreach x {0 1 2 3} y {d1 d2 d3 d4} {
        entry $w.$x -bd 0 -width 3 -highlightthickness 0 -justify center
        label $w.$y -bd 0 -font [$w.$x cget -font] -width 1 -text . -justify center \
            -cursor [$w.$x cget -cursor] -bg [$w.$x cget -background] \
            -disabledforeground [$w.$x cget -disabledforeground]
        pack $w.$x $w.$y -side left
        bindtags $w.$x [list $w.$x IPEntrybindtag . all]
        bind $w.$y <Button-1> {::ipentry::dotclick %W %x}
    }
    destroy $w.d4
    if {$usettk} {
        pack configure $w.0 -padx {1 0} -pady 1
        pack configure $w.3 -padx {0 1} -pady 1
    }
    rename ::$w ::ipentry::_$w
    # redirect the widget name command to the widgetCommand dispatcher
    interp alias {} ::$w {} ::ipentry::widgetCommand $w
    namespace eval _tvns$w {variable textvarname}
    bind $w <Destroy> [list ::ipentry::destroyWidget $w]
    #bind $w <FocusIn> [list focus $w.0]
    if {[llength $args] > 0} {
        eval [list $w configure] $args
    }
    return $w
}

# keypress --
#
# called every time a key is pressed in an ipentry widget
#
# ARGS:
#       w       window argument (%W) from the event binding
#       key     the keysym (%K) from the event
#
# RETURNS:
#       nothing
#
proc ::ipentry::keypress {w key} {
    if {![validate $w $key]} { return }
    # sel.first and sel.last throw an error if the selection isnt in $w
    catch {
        set insert [$w index insert]
        # if a key is pressed while there is a selection then delete the
        # selected chars
        if {([$w index sel.first] <= $insert) && ([$w index sel.last] >= $insert)} {
            $w delete sel.first sel.last
        }
    }
    $w insert insert $key
}

# tab --
#
# called when the Tab key is pressed in an ipentry widget
#
# ARGS:
#       w       window argument (%W) from the event binding
#
# RETURNS:
#       nothing
#
proc ::ipentry::tab {w} {
    # redirect to the standard tk handler but use the parent frame instead
    # of the entry widget
    tk::TabToWindow [tk_focusNext [winfo parent $w].3]
}

# backspace --
#
# called when the Backspace key is pressed in an ipentry widget
#
# try to act like a normal backspace except if the cursor is at index 0
# of one entry we need to move to the end of the preceding entry
#
# ARGS:
#       w       window argument (%W) from the event binding
#
# RETURNS:
#       nothing
#
proc ::ipentry::backspace {w} {
    if {[$w selection present]} {
        $w delete sel.first sel.last
    } else {
        if {[$w index insert] == 0} {
            skip $w prev
        } else {
            $w delete [expr {[$w index insert] - 1}]
        }
    }
}

# dot --
#
# called when the dot (Period) key is pressed in an ipentry widget
#
# treat the current entry as done and move to the next entry widget
#
# ARGS:
#       w       window argument (%W) from the event binding
#
# RETURNS:
#       nothing
#
proc ::ipentry::dot {w} {
    if {[string length [$w get]] > 0} {
        skip $w next 1
    }
}

# FocusIn --
#
# called when the focus enters any of the child widgets of an ipentry
#
# clear the selection of all child widgets other than the one with focus
#
# ARGS:
#       w       window argument (%W) from the event binding
#
# RETURNS:
#       nothing
#
proc ::ipentry::FocusIn {w} {
    set p [winfo parent $w]
    foreach x {0 1 2 3} {
        if {"$p.$x" != $w} {
            $p.$x selection clear
        }
    }
}

# FocusOut --
#
# called when the focus leaves any of the child widgets of an ipentry
#
# 
#
# ARGS:
#       w       window argument (%W) from the event binding
#
# RETURNS:
#       nothing
#
proc ::ipentry::FocusOut {w} {
    set s [$w get]
    if {[string match {*.0} $w] && $s != "" && $s < 1} {
        $w delete 0 end
        $w insert end 1
    }
}

# Paste --
#
# called from the <<Paste>> virtual event
#
# clear the selection of all child widgets other than the one with focus
#
# ARGS:
#       w       window argument (%W) from the event binding
#       sel     one of CLIPBOARD or PRIMARY
#
# RETURNS:
#       nothing
#
proc ::ipentry::Paste {w sel} {
    if {[catch {::tk::GetSelection $w $sel} paste]} { return }
    $w delete 0 end
    foreach char [split $paste {}] {
        # ignore everything except dots and digits
        if {![string match {[0123456789.]} $char]} { continue }
        if {$char != "."} {
            $w insert end $char
        }
        # if value is over 255 truncate it
        if {[$w get] > 255} {
            $w delete 0 end
            $w insert 0 255
        }
        # if char is a . then get the index of the current entry
        # and update $w to point to the next entry
        if {$char == "."} {
            set n [string index $w end]
            if { $n >= 3 } { return }
            set w [string trimright $w "0123"][expr {$n + 1}]
            $w delete 0 end
            continue
        }
    }
}

# dotclick --
#
# called when mouse button 1 is clicked on any of the label widgets
#
# decide which side of the dot was clicked and put the focus and cursor
# in the correct entry
#
# ARGS:
#       w       window argument (%W) from the event binding
#
# RETURNS:
#       nothing
#
proc ::ipentry::dotclick {w x} {
    if {$x > ([winfo width $w] / 2)} {
        set w [winfo parent $w].[string index $w end]
        focus $w
        $w icursor 0
    } else {
        set w [winfo parent $w].[expr {[string index $w end] - 1}]
        focus $w
        $w icursor end
    }
}

# arrow --
#
# called when the left or right arrow keys are pressed in an ipentry
#
# ARGS:
#       w       window argument (%W) from the event binding
#       key     one of Left or Right
#
# RETURNS:
#       nothing
#
proc ::ipentry::arrow {w key} {
    set i [$w index insert]
    set l [string length [$w get]]
    # move the icursor +1 or -1 position
    $w icursor [expr $i [string map {Right + Left -} $key] 1]
    $w selection clear
    # if we are moving right and the cursor is at the end, or the entry is empty
    if {$key == "Right" && ($i == $l || $l == 0)} {
        skip $w next
    } elseif {$key == "Left" && $i == 0} {
        skip $w prev
    }
}

# validate --
#
# called by keypress to validate the input
#
# ARGS:
#       w       window argument (%W) from the event binding
#       key     the key pressed
#
# RETURNS:
#       a boolean indicating if the key is valid or not
#
proc ::ipentry::validate {w key} {
    if {![string match {[0123456789]} $key]} { return 0 }
    set curval [$w get]
    set insert [$w index insert]
    # dont allow more than a single 0 to be entered
    if {$curval == "0" && $key == "0"} { return 0 }
    if {[string length $curval] == 2} {
        set curval [join [linsert [split $curval {}] $insert $key] {}]
        if {$curval > 255} {
            $w delete 0 end
            $w insert 0 255
            $w selection range 0 end
            return 0
        } elseif {$insert == 2} {
            skip $w next 1
        }
        return 1
    }
    if {[string length $curval] >= 3 && ![$w selection present]} {
        if {$insert == 3} { skip $w next 1 }
        return 0
    }
    return 1
}

# skip --
#
# move the cursor to the previous or next entry widget
#
# ARGS:
#       w       name of the current entry widget 
#       dir     direction to move, one of next or prev
#       sel     boolean indicating whether to select the digits in the next entry
#
# RETURNS:
#       nothing
#
proc ::ipentry::skip {w dir {sel 0}} {
    set n [string index $w end]
    if {$dir == "next"} {
        if { $n >= 3 } { return }
        set next [string trimright $w "0123"][expr {$n + 1}]
        focus $next
        if {$sel} {
            $next icursor 0
            $next selection range 0 end
        }
    } else {
        if { $n <= 0 } { return }
        set prev [string trimright $w "0123"][expr {$n - 1}]
        focus $prev
        $prev icursor end
    }
}

# _foreach --
#
# perform a command on every subwidget of an ipentry frame
#
# ARGS:
#       w       name of the ipentry frame 
#       cmd     command to perform
#
# RETURNS:
#       nothing
#
proc ::ipentry::_foreach {w cmd} {
    foreach x {0 d1 1 d2 2 d3 3} {
        eval [list $w.$x] $cmd
    }
}

# cget --
#
# handle the widgetName cget subcommand
#
# ARGS:
#       w       name of the ipentry widget 
#       cmd     name of a configuration option
#
# RETURNS:
#       the value of the requested option
#
proc ::ipentry::cget {w cmd} {
    switch -exact -- $cmd {
        -bd -
        -borderwidth -
        -relief {
            # for bd and relief return the value from the container frame
            return [::ipentry::_$w cget $cmd]
        }
        -textvariable {
            namespace eval _tvns$w {
                if { [info exists textvarname] } {
                    return $textvarname
                } else {
                    return {}
                }
            }
        }
        default {
            # for all other commands return the value from the first entry
            return [$w.0 cget $cmd]
        }
    }
    return
}

# configure --
#
# handle the widgetName configure subcommand
#
# ARGS:
#       w       name of the ipentry widget 
#       args    name/value pairs of configuration options
#
# RETURNS:
#       nothing
#
proc ::ipentry::configure {w args} {
    while {[set cmd [lindex $args 0]] != ""} {
        switch -exact -- $cmd {
            -state {
                set state [lindex $args 1]
                if {$state == "disabled"} {
                    _foreach $w [list configure -state disabled]
                    if {[set dbg [$w.0 cget -disabledbackground]] == ""} {
                        set dbg [$w.0 cget -bg]
                    }
                    foreach x {d1 d2 d3} { $w.$x configure -bg $dbg }
                    ::ipentry::_$w configure -bg $dbg
                } elseif {$state == "normal"} {
                    _foreach $w [list configure -state normal]
                    foreach x {d1 d2 d3} { $w.$x configure -bg [$w.0 cget -bg] }
                    ::ipentry::_$w configure -background [$w.0 cget -bg]
                } elseif {$state == "readonly"} {
                    foreach x {0 1 2 3} { $w.$x configure -state readonly }
                    if {[set robg [$w.0 cget -readonlybackground]] == ""} {
                        set robg [$w.0 cget -bg]
                    }
                    foreach x {d1 d2 d3} { $w.$x configure -bg $robg }
                    ::ipentry::_$w configure -bg $robg
                }
                set args [lrange $args 2 end]
            }
            -bg {
                _foreach $w [list configure -bg [lindex $args 1]]
                ::ipentry::_$w configure -bg [lindex $args 1]
                set args [lrange $args 2 end]
            }
            -disabledforeground {
                _foreach $w [list configure -disabledforeground [lindex $args 1]]
                set args [lrange $args 2 end]
            }
            -font -
            -fg   {
                _foreach $w [list configure $cmd [lindex $args 1]]
                set args [lrange $args 2 end]
            }
            -bd                  -
            -relief              -
            -highlightcolor      -
            -highlightbackground -
            -highlightthickness  {
                _$w configure $cmd [lindex $args 1]
                set args [lrange $args 2 end]
            }
            -readonlybackground -
            -disabledbackground -
            -selectforeground   -
            -selectbackground   -
            -selectborderwidth  -
            -insertbackground   {
                foreach x {0 1 2 3} { $w.$x configure $cmd [lindex $args 1] }
                set args [lrange $args 2 end]
            }
            -textvariable {
                namespace eval _tvns$w {
                    if { [info exists textvarname] } {
                        set _w [join [lrange [split [namespace current] .] 1 end] .]
                        trace remove variable $textvarname \
                            [list array read write unset] \
                            [list ::ipentry::traceVar .$_w]
                    }
                }
                set _tvns[set w]::textvarname [lindex $args 1]
                upvar #0 [lindex $args 1] var
                if { [info exists var] && [isValid $var] } {
                    $w insert [split $var .]
                } else {
                    set var {}
                }
                trace add variable var [list array read write unset] \
                    [list ::ipentry::traceVar $w]
                set args [lrange $args 2 end]
            }
            -themed {
                # ignored - only used in widget creation
                set args [lrange $args 2 end]
            }
            default {
                error "unknown option \"[lindex $args 0]\""
            }
        }
    }
}

# configure --
#
# handle the widgetName configure subcommand
#
# ARGS:
#       w       name of the ipentry widget 
#       args    name/value pairs of configuration options
#
# RETURNS:
#       nothing
#
proc ::ipentry::destroyWidget {w} {
    upvar #0 [$w cget -textvariable] var
    trace remove variable var [list array read write unset] \
        [list ::ipentry::traceVar $w]
    namespace forget _tvns$w
    rename $w {}
}

# traceVar --
#
# called by the variable trace for the ipentry textvariable
#
# ARGS:
#       w       name of the ipentry widget 
#       varname name of the variable being traced
#       key     array index of the variable
#       op      operation performed on the variable, read/write/unset
#
# RETURNS:
#       nothing
#
proc ::ipentry::traceVar {w varname key op} {
    upvar #0 $varname var

    if { $op == "write" } {
        if { $key != "" } {
            $w insert [split $var($key) .]
        } else {
            $w insert [split $var .]
        }
    }

    if { $op == "unset" } {
        if { $key != "" } {
            trace add variable var($key) [list array read write unset] \
                [list ::ipentry::traceVar $w]
        } else {
            trace add variable var [list array read write unset] \
                [list ::ipentry::traceVar $w]
        }
    }

    set val [join [$w get] .]
    if { ![isValid $val] } {
        set val {}
    }
    if { $key != "" } {
        set var($key) $val
    } else {
        set var $val
    }

}

# isValid --
#
# determine if val is a valid ip address
# used by the textvariable routines
#
# ARGS:
#       val     value to test
#
# RETURNS:
#       boolean indicating if val is a valid ip address
#
proc ::ipentry::isValid {val} {
    set lval [split [join $val] {. }]
    set valid 1
    if { [llength $lval] != 4 } {
        set valid 0
    } else {
        foreach n $lval {
            if { $n == ""
                 || ![string is integer -strict $n]
                 || $n > 255
                 || $n < 0
             } then {
                set valid 0
                break
            }
        }
        return $valid
    }
}

# widgetCommand --
#
# handle the widgetName command
#
# ARGS:
#       w       name of the ipentry widget 
#       cmd     the subcommand
#       args    arguments to the subcommand
#
# RETURNS:
#       the results of the invoked subcommand
#
proc ::ipentry::widgetCommand {w cmd args} {
    switch -exact -- $cmd {
        get {
            # return the 4 entry values as a list
            foreach x {0 1 2 3} {
                set s [$w.$x get]
                if {[string length $s] > 1} { set s [string trimleft $s 0] }
                lappend r $s
            }
            return $r
        }
        insert {
            foreach x {0 1 2 3} {
                set n [lindex $args 0 $x]
                if {$n != ""} {
                    if {![string is integer -strict $n]} {
                        error "cannot insert non-numeric arguments"
                    }
                    if {$n > 255} { set n 255 }
                    if {$n <= 0}  { set n 0 }
                    if {$x == 0 && $n < 1} { set n 1 }
                }
                $w.$x delete 0 end
                $w.$x insert 0 $n
            }
        }
        icursor {
            if {![string match $w.* [focus]]} {return}
            set i [lindex $args 0]
            if {![string is integer -strict $i]} {error "argument must be an integer"}
            set s [expr {$i / 4}]
            focus $w.$s
            $w.$s icursor [expr {$i % 4}]
        }
        complete {
            foreach x {0 1 2 3} {
                if {[$w.$x get] == ""} { return 0 }
            }
            return 1
        }
        configure {
            eval [list ::ipentry::configure $w] $args
        }
        cget {
            return [::ipentry::cget $w [lindex $args 0]]
        }
        default {
            error "bad option \"$cmd\": must be get, insert, complete, cget, or configure"
        }
    }
}
