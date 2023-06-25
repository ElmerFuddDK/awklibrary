# File : csv.awk
# --------------------
#
# Functions:
#
#  csv_cellidtocoordinate(cell,coordArray)
#    Takes spreadsheet cell ID (Eg "B2") and fills coordinate into coordArray with coordArray[1] = col, coordArray[2] = row
#
#  csv_colindextocellid(idx)
#    Converts a column index to spreadsheet cell ID, eg. 5 -> "E"
#
#  csv_cellidtocolindex(id)
#    Converts a spreadsheet cell ID to column index - eg. "E" -> 5
#
#  escape_tocsv(str)
#    Escape str value to csv for use with output
#
#  csv_parse(string,csv,sep,quote,escape,newline,trim)
#    Parses csv string data into a csv array
#
# References:
#   csv_parse, csv_create, csv_err and csv_parse functions copied and improved from here:
#    http://lorance.freeshell.org/csv/
#

function csv_cellidtocoordinate(cell,coordArray,  _row, _rowArr, _col, i, _chars) {
	_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	split("",coordArray,"")
	_row = _col = toupper(cell)
	sub(/[0-9]+$/,"",_row)
	sub(/^[A-Z]+/,"",_col)
	split(_row,_rowArr,null)
	coordArray[1] = 0
	for (i=1; i<=length(_rowArr); i++) {
		coordArray[1] = coordArray[1]*length(_chars) + index(_chars,_rowArr[i])
	}
	coordArray[2] = _col+0
}

function csv_colindextocellid(idx,  _cellID, _chars) {
	_cellID = ""
	_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	while(idx > 0) {
		_cellID = substr(_chars,((idx-1)%length(_chars))+1,1) _cellID
		idx = int((idx-1) / length(_chars))
	}
	return _cellID
}

function csv_cellidtocolindex(id,  _idx, _chars, _row, _rowArr, i) {
	_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	_row = toupper(id)
	sub(/[0-9]+$/,"",_row)
	split(_row,_rowArr,null)
	_idx = 0
	for (i=1; i<=length(_rowArr); i++) {
		_idx = _idx*length(_chars) + index(_chars,_rowArr[i])
	}
	return _idx
}

function escape_tocsv(str) {
	if (length(str)) {
		gsub(/"/,"\"\"",str)
		return "\"" str "\""
	}
	return str
}


# --- CSV parsing lib found on the interwebs
# URL : http://lorance.freeshell.org/csv/

function csv_parse(string,csv,sep,quote,escape,newline,trim, fields,pos,strtrim) {
    if (length(string) == 0) return 0
    string = sep string
    fields = 0
    while (length(string) > 0) {
        if (trim && substr(string, 2, 1) == " ") {
            if (length(string) == 1) return fields
            string = substr(string, 2)
            continue
        }
        strtrim = 0
        if (substr(string, 2, 1) == quote) {
            pos = 2
            do {
                pos++
                if (pos != length(string) &&
                    substr(string, pos, 1) == escape &&
                    index(quote escape, substr(string, pos + 1, 1)) != 0) {
                    string = substr(string, 1, pos - 1) substr(string, pos + 1)
                } else if (substr(string, pos, 1) == quote) {
                    strtrim = 1
                } else if (pos >= length(string)) {
                    if (newline == -1) {
                        return -1
                    } else if (newline) {
                        if (getline == -1) return -4
                        string = string newline $0
                    }
                }
            } while (pos < length(string) && strtrim == 0)
            if (strtrim == 0) {
                return -3
            }
        } else {
            if (length(string) == 1 || substr(string, 2, 1) == sep) {
                fields++
                csv[fields] = ""
                if (length(string) == 1) return fields
                string = substr(string, 2)
                continue
            }
            pos = index(substr(string, 2), sep)
            if (pos == 0) {
                fields++
                csv[fields] = substr(string, 2)
				if (length(csv[fields]) && csv[fields]+0 == csv[fields])
					csv[fields] = csv[fields]+0
                return fields
            }
        }
        if (trim && pos != (length(string) + strtrim) && substr(string, pos + strtrim, 1) == " ") {
            trim = strtrim
            while (pos < length(string) && substr(string, pos + trim, 1) == " ") {
                trim++
            }
            string = substr(string, 1, pos + strtrim - 1) substr(string,  pos + trim)
            if (!strtrim) {
                pos -= trim
            }
        }
        if ((pos != length(string) && substr(string, pos + 1, 1) != sep)) {
            return -4
        }
        fields++
        csv[fields] = substr(string, 2 + strtrim, pos - (1 + strtrim * 2))
		if (!strtrim && length(csv[fields]) && csv[fields]+0 == csv[fields])
			csv[fields] = csv[fields]+0
        if (pos == length(string)) {
            return fields
        } else {
            string = substr(string, pos + 1)
        }
    }
    return fields
}
function csv_create (csv,fields,sep,quote,escape,level, field,pos,string) {
    sep     = (sep ? sep : ",")
    quote   = (quote ? quote : "\"")
    escape  = (escape ? escape : "\"")
    level   = (level ? level : 0)
    string = ""
    for (pos = 1; pos <= fields; pos++) {
        field = csv[pos]
        if (field) {
            if (level == 0) {
                string = string csv_escape_string(field, quote, escape, quote escape)
            } else if ((level >= 2) ||
                       (level == 1 && field !~ /^-*[0-9.][0-9.]*$/)) {
                string = string quote csv_escape_string(field, "", escape, quote escape) quote
            } else {
                string = string field
            }
        } else if (level == 3) {
            string = string quote quote
        }
        if (pos < fields) string = string sep
    }
    return string
}
function csv_err (number) {
    if (number == -1) {
        return "More data expected."
    } else if (number == -2) {
        return "Unable to read the next line."
    } else if (number == -3) {
        return "Missing end quote."
    } else if (number == -4) {
        return "Missing separator."
    }
}
function csv_escape_string (string,quote,escape,special, pos,prev,char,csv) {
    prev = 1
    csv = ""
    for (pos = 1; pos < length(string) + 1; pos++) {
        char = substr(string, pos, 1)
        if (index(special, char) > 0) {
            if (pos == 1) {
                csv = escape char
            } else {
                csv = csv substr(string, prev, (pos - prev)) escape char
            }
            prev = pos + 1
        }
    }
    if (prev != pos) {
        csv = csv substr(string, prev)
    }
    if (quote && string != csv) {
        return quote csv quote
    } else {
        return csv
    }
}
