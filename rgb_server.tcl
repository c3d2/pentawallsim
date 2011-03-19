set listenport 1338
set listenip 0.0.0.0
set xdim 16
set ydim 15
set scale 25
set minscale 1
set maxscale 60

# ###################################################################

set rgb_version "carwesimu rev 0"
package require Tcl 8.5
package require Tk

bind . + {changescale +5}
bind . - {changescale -1}

wm resizable . 0 0

proc incomingconnection {rgbsocket clientaddr clientport} {
	puts "$rgbsocket OPENED from ip $clientaddr port $clientport"
	fconfigure $rgbsocket -blocking 0 -translation {crlf crlf}
	fileevent $rgbsocket readable "readrgbsocket $rgbsocket"
	return
}

proc readrgbsocket {rgbsocket} {
	set len [gets $rgbsocket line]
	if {$len <= 0} {
		if { [eof $rgbsocket] } {
			puts "$rgbsocket CLOSED"
			close $rgbsocket;
		}
	} else {
		if {! [decodergbsocketline $rgbsocket $line] } {
			puts "bad line in $rgbsocket: $line"
			puts $rgbsocket "bad paket"
		}
	}
	return
}

proc decodergbsocketline {rgbsocket line} {
	set type [string range $line 0 1]
	set paket [string range $line 2 end]
	#puts "recieved: $type $paket"
	switch $type {
		01 {
			# puts $rgbsocket "01$::rgb_version"
			return 0
		}
		02 { # single pixel
			scan $paket "%02x%02x%02x%02x%02x" x y r g b
			set color [format "#%02x%02x%02x" $r $g $b]

			if { $x==0 && $y==0 } {
				fillscreen $color
			} elseif { $x==0 } {
				fillrow $y $color
			} elseif { $y==0 } {
				fillcolumn $x $color
			} else {
				paintpixel $x $y $color
			}
			updatesurface
		}
		03 { # full frame
			if { [string length $paket] != [expr {$::xdim*$::ydim*3*2}] } {
				puts $rgbsocket "bad type-03-paket recieved, expected [expr {$::xdim*$::ydim*3*2}] bytes (for $::xdim * $::ydim pixels), got [string length $paket] bytes"
				puts  "bad type-03-paket recieved, expected [expr {$::xdim*$::ydim*3*2}] bytes (for $::xdim * $::ydim pixels), got [string length $paket] bytes"
				return 0
			}
			#puts "type-03-paket recieved"
			for {set j 1} {$j <= $::ydim} {incr j} {
				set row [string range $paket [expr {($j-1) * $::xdim * 3 * 2}] [expr {(($j) * $::xdim * 3 * 2)-1}]]
				for {set i 1} {$i <= $::xdim} {incr i} {
					set pixel [string range $row [expr {($i-1) * 3 * 2}] [expr {(($i) * 3 * 2)-1}]]
					scan $pixel "%02x%02x%02x" r g b
					paintpixel $i $j [format "#%02x%02x%02x" $r $g $b]
				}
			}
			updatesurface
		}
		default {
			return 0
		}
	}
	return 1
}

proc paintpixel {x y color} {
	$::hiddensurface put $color -to [expr { $x+1 }] [expr { $y+1 }] [expr { $x+2 }] [expr { $y+2 }]
	return
}

proc fillscreen {color} {
	$::hiddensurface put $color -to 2 2 [expr { $::xdim +2 }] [expr { $::ydim +2 }]
	return
}

proc fillrow {row color} {
	$::hiddensurface put $color -to 2 [expr { $row+1 }] [expr { $::xdim�+2 }] [expr { $row +2 }]
	return
}

proc fillcolumn {column color} {
	$::hiddensurface put $color -to [expr { $column +1 }] 2 [expr { $column +2 }] [expr { $::ydim +2 }]
	return
}

proc changescale {amount} {
	set oldscale $::scale
	set ::scale [expr { min($::maxscale,max($minscale,($::scale + $amount))) }]
	if { $oldscale != $::scale} {
		updatewindow
	}
	return
}

proc updatewindow {} {
	deletewindow
	createwindow
}

proc createwindow {} {
	set width [expr {$::xdim * $::scale}]
	set height [expr {$::ydim * $::scale}]
	pack [canvas .screen -bg black -width $width -height $height] -fill both -expand 1
	# Zeichenbereich erstellen
	set ::displaysurface [image create photo -width [expr {$width+2}] -height [expr {$height+2}] -palette 256/256/256]
	# Zeichenbereich auf Bildschirm bringen
	.screen create image 0 0 -anchor nw -image $::displaysurface
	wm title . "rgbwall scale $::scale"
	return
}

proc deletewindow {} {
	.screen delete ::displaysurface
	destroy .screen
	return
}

proc updatesurface {} {
	$::displaysurface copy $::hiddensurface -zoom $::scale $::scale -from 2 2 [expr {$::xdim + 2}] [expr {$::ydim + 2}] -to 2 2
	update idletasks
	return
}

proc every {ms body} {
	eval $body
	after $ms [info level 0]
	return
}

proc init {} {
	set ::hiddensurface [image create photo -width [expr {$::xdim+2}] -height [expr {$::ydim+2}] -palette 256/256/256]
	createwindow
	socket -server incomingconnection -myaddr $::listenip $::listenport
	
	return
}


init