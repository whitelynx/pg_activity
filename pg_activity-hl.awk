BEGIN {
	FS = "[[:space:]]*:[[:space:]]*"  # Remove leading and trailing space.
	PROCINFO["sorted_in"] = "@ind_num_asc" # Always order array traversal by index, treating it as a number.

	totalTime = 0

	# Make sure awk can tell this is supposed to be an array!
	columnSplitIndices[1] = ""
	delete columnSplitIndices[1]

	show["WARNING"] = 1
	show["ERROR"] = 1
	if(enabled(VERBOSE)) {
		show["time"] = 1

		show["LOG"] = 1

		show["LOG-DETAIL"] = 1
	}
	if(enabled(QUIET)) {
		show["status"] = 1

		show["NOTICE"] = 1

		show["NOTICE-DETAIL"] = 1
		show["WARNING-DETAIL"] = 1
		show["ERROR-DETAIL"] = 1
	}

	colors["time"] = "1;90"
	colors["time-secondary"] = "0;90"
	colors["time-unmatched"] = "1;91"
	colors["status"] = "32"
	colors["total-time"] = "1;34"
	colors["total-time-secondary"] = "0;34"

	colors["results-header"] = "38;5;130"
	colors["results-cell"] = "38;5;118"
	colors["results-cell-null"] = "38;5;65"
	colors["results-border"] = "38;5;238"

	colors["LOG"] = "37"
	colors["NOTICE"] = "96"
	colors["WARNING"] = "93"
	colors["ERROR"] = "91"

	colors["LOG-DETAIL"] = "90"
	colors["NOTICE-DETAIL"] = "36"
	colors["WARNING-DETAIL"] = "33"
	colors["ERROR-DETAIL"] = "31"

	colors["RESET"] = ""

	indent["LOG-DETAIL"] = "    "
	indent["NOTICE-DETAIL"] = "    "
	indent["WARNING-DETAIL"] = "    "
	indent["ERROR-DETAIL"] = "    "

	for(key in colors) {
		colors[key] = color(colors[key])
	}

	resultsVerticalBorder = colors["results-border"] "|" colors["RESET"]
}

function enabled(option) {
	return option && tolower(option) !~ /^([fn0]|false|no|off)$/
}

function color(c) {
	return "\x1b[" c "m"
}

function renderTime(time, primaryColor, secondaryColor) {
	time = 0 + time
	rendered = sprintf((secondaryColor "Total: " primaryColor "%.3f sec " secondaryColor), time / 1000)
	if(time > 1000) {
		return sprintf((rendered "(%.3f min)\n"), time / 1000 / 60)
	} else {
		return sprintf((rendered "(%.3f ms)\n"), time)
	}
}

{
	lineToLog = $0
}

/^\s+\w+\s+(\|\s+\w+\s+)+$/ {
	FS = "|"
	split($0, columns)
	line = ""
	nextColSplitIdx = 1
	for(i in columns) {
		columnSplitIndices[i]["start"] = nextColSplitIdx
		columnSplitIndices[i]["length"] = length(columns[i])
		nextColSplitIdx = nextColSplitIdx + length(columns[i]) + 1
		if(line != "") { line = line resultsVerticalBorder }
		line = line colors["results-header"] columns[i] colors["RESET"]
	}
	print line
	next
}

length(columnSplitIndices) {
	if($0 ~ /^$/) {
		FS = "[[:space:]]*:[[:space:]]*"  # Reset to original FS value.
		delete columnSplitIndices
		delete columns
		print
		next
	}

	if($0 ~ /^\([0-9]* rows?\)$/ || $0 ~ /^--+(\+--+)*$/) {
		print colors["results-border"] $0 colors["RESET"]
		next
	}

	line = ""
	for(i in columnSplitIndices) {
		if(line != "") { line = line resultsVerticalBorder }

		value = substr($0, columnSplitIndices[i]["start"], columnSplitIndices[i]["length"])

		if(value ~ /\s*<NULL>\s*/) {
			line = line colors["results-cell-null"] value colors["RESET"]
		} else {
			line = line colors["results-cell"] value colors["RESET"]
		}
	}
	print line
	next
}

$1 == "psql" {
	curLevel = $4
	curColor = colors[curLevel]
	resetAfterThisLine = 0

	if($5 != "statement") {
		resetAfterThisLine = 1
	}
}

/^DETAIL: / {
	# Treat 'DETAIL' messages as their own log levels, based on the latest other log level.
	curLevel = latestLevel "-DETAIL"
	curColor = colors[curLevel]
	resetAfterThisLine = 0
}

/^(DELETE [0-9]+|(INSERT|UPDATE) [0-9]+ [0-9]+|(CREATE|ALTER|DROP) (TABLE|FUNCTION|VIEW|TYPE|INDEX|TRIGGER|RULE|SEQUENCE|CONSTRAINT|EXTENSION|SCHEMA|TABLESPACE)|COMMENT|GRANT)$/ {
	# Treat status messages as their own log level.
	curLevel = "status"
	curColor = colors[curLevel]
	resetAfterThisLine = 1
}

/^Time: / {
	# Treat 'Time' messages as their own log level.
	curLevel = "time"
	curColor = colors["time-unmatched"]
	resetAfterThisLine = 1
}
/^Time: [0-9.]* ms[[:space:]]*$/ {
	curColor = colors["time"]
	lineToLog = renderTime($2, colors["time"], colors["time-secondary"])
	totalTime += $2
}

{
	if(!curLevel || show[curLevel]) {
		if(curColor) {
			print indent[curLevel] curColor lineToLog colors["RESET"]
		} else {
			print indent[curLevel] lineToLog
		}
	}

	if(curLevel) {
		latestLevel = curLevel
	}

	if(resetAfterThisLine) {
		curLevel = 0
		curColor = 0
	}
	resetAfterThisLine = 0
}

END {
	print renderTime(totalTime, colors["total-time"], colors["total-time-secondary"])
}
