set rcsId {$Id: canlabel.tcl,v 1.6 1995/10/01 12:52:43 jfontain Exp $}

proc canvasLabel::canvasLabel {id canvas x y args} {
    global canvasLabel

    set canvasLabel($id,canvas) $canvas
    # use a dimensionless line as an origin marker
    set canvasLabel($id,origin) [$canvas create line $x $y  $x $y -fill {} -tags canvasLabel($id)]
    set canvasLabel($id,rectangle) [$canvas create rectangle 0 0 0 0 -tags canvasLabel($id)]
    set canvasLabel($id,text) [$canvas create text 0 0 -tags canvasLabel($id)]
    # set anchor default
    set canvasLabel($id,anchor) center
    eval canvasLabel::configure $id $args
    # initialize rectangle
    canvasLabel::sizeRectangle $id
}

proc canvasLabel::~canvasLabel {id} {
    global canvasLabel

    $canvasLabel($id,canvas) delete canvasLabel($id)
}

proc canvasLabel::configure {id args} {
    # emulate label widget behavior
    global canvasLabel

    set number [llength $args]
    for {set index 0} {$index<$number} {incr index} {
        set option [lindex $args $index]
        set value [lindex $args [incr index]]
        switch -- $option {
            -background {
                $canvasLabel($id,canvas) itemconfigure $canvasLabel($id,rectangle) -fill $value
            }
            -foreground {
                $canvasLabel($id,canvas) itemconfigure $canvasLabel($id,text) -fill $value
            }
            -borderwidth {
                $canvasLabel($id,canvas) itemconfigure $canvasLabel($id,rectangle) -width $value
            }
            -stipple {
                $canvasLabel($id,canvas) itemconfigure $canvasLabel($id,rectangle) $option $value
            }
            -anchor {
                set canvasLabel($id,anchor) $value
                canvasLabel::sizeRectangle $id
            }
            -font -
            -justify -
            -text -
            -width {
                $canvasLabel($id,canvas) itemconfigure $canvasLabel($id,text) $option $value
                canvasLabel::sizeRectangle $id
            }
            -bordercolor {
                $canvasLabel($id,canvas) itemconfigure $canvasLabel($id,rectangle) -outline $value
            }
        }
    }
}

proc canvasLabel::cget {id option} {
    global canvasLabel

    switch -- $option {
        -background {
            return [$canvasLabel($id,canvas) itemcget $canvasLabel($id,rectangle) -fill]
        }
        -foreground {
            return [$canvasLabel($id,canvas) itemcget $canvasLabel($id,text) -fill]
        }
        -borderwidth {
            return [$canvasLabel($id,canvas) itemcget $canvasLabel($id,rectangle) -width]
        }
        -stipple {
            return [$canvasLabel($id,canvas) itemcget $canvasLabel($id,rectangle) $option]
        }
        -anchor {
            return $canvasLabel($id,anchor)
        }
        -font -
        -justify -
        -text -
        -width {
            return [$canvasLabel($id,canvas) itemcget $canvasLabel($id,text) $option]
        }
        -bordercolor {
            return [$canvasLabel($id,canvas) itemcget $canvasLabel($id,rectangle) -outline]
        }
    }
}

proc canvasLabel::sizeRectangle {id} {
    global canvasLabel

    set padding 2
    set canvas $canvasLabel($id,canvas)
    set rectangle $canvasLabel($id,rectangle)
    set text $canvasLabel($id,text)

    set coordinates [$canvas coords $canvasLabel($id,origin)]
    set x [lindex $coordinates 0]
    set y [lindex $coordinates 1]

    set border [$canvas itemcget $rectangle -width]
    set halfBorder [expr $border/2.0]
    set box [$canvas bbox $text]

    set halfWidth [expr ([lindex $box 2]-[lindex $box 0])/2.0]
    set halfHeight [expr ([lindex $box 3]-[lindex $box 1])/2.0]

    # first position rectangle and text as if anchor was center (the default)
    $canvas coords $rectangle\
        [expr $x-$halfWidth-$padding-$halfBorder] [expr $y-$halfHeight-$padding-$halfBorder]\
        [expr $x+$halfWidth+$padding+$halfBorder] [expr $y+$halfHeight+$padding+$halfBorder]
    $canvas coords $text $x $y

    # now move rectangle and text according to anchor
    set anchor $canvasLabel($id,anchor)
    set xDelta [expr ([string match *w $anchor]-[string match *e $anchor])*($border+$padding+$halfWidth)]
    set yDelta [expr ([string match n* $anchor]-[string match s* $anchor])*($border+$padding+$halfHeight)]
    $canvas move $rectangle $xDelta $yDelta
    $canvas move $text $xDelta $yDelta
}
