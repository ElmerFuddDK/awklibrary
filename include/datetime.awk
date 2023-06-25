# File : datetime.awk
# --------------------
#
# Date/time utility functions
#
# Functions:
#
#  date_exceltounixtime(ex)
#    Converts an excel date to unix timestamp
#  date_tounixtime(dt,<utc>)
#    Converts a date string to unix timestamp
#    If utc is set then it converts from local to utc
#  date_format(dt,<format>)
#    Formats a unix timestamp or date string according to format string, or default
#    Override default by setting DATETIMEFORMAT variable
#  date_toarray(dt,arr)
#    Splits a date string into a time array in arr
#  date_arraytounixtime(arr,<utc>)
#    Converts a time array to unix timestamp
#    If utc is set then it converts from local to utc

function date_exceltounixtime(ex,   unixStamp) {
	sub(/,/,".",ex)
	unixStamp=(ex-25569.0)*86400.0
	return unixStamp
}

function date_tounixtime(dt,utc,  _arr,_nul) {
	if (date_toarray(dt,_arr))
		return date_arraytounixtime(_arr,utc)
	return _nul
}

function date_format(dt,format,  _arr) {
  if (isnum(dt))
    return strftime(format ? format : ( DATETIMEFORMAT ? DATETIMEFORMAT : "%Y-%m-%d %H:%M" ), dt)
  if (date_toarray(dt,_arr))
    return strftime(format ? format : ( DATETIMEFORMAT ? DATETIMEFORMAT : "%Y-%m-%d %H:%M" ), date_arraytounixtime(_arr))
  return dt
}

# Assumes dt is in one of the formats:
# YYYY-MM-DD(THH:MM:SS)?
# DD-MM-YYYY( HH:MM:SS)?
# DD mon YYYY( HH:MM:SS)?
function date_toarray(dt,arr,  _t,_mon) {
	dt=tolower(dt)
	gsub(/^[ \t\r\n]+|[ \t\r\n]+$/,"",dt)
	if (dt ~ /^[0-9]{4}[- ][0-9]{2}[- ][0-9]{2}([- Tt][0-9]{2}[- :][0-9]{2}([- :][0-9]{2})?(\.[0-9]{3})?)?$/) {
		split(dt "T00:00:00",arr,"[-Tt :]")
	}
	# dd-mm-yyyy
	else if (dt ~ /^[0-9]{2}[- /][0-9]{2}[- /][0-9]{4}([- T][0-9]{2}[- :][0-9]{2}([- :][0-9]{2})?)?$/) {
		split(dt " 00:00:00",arr,"[-Tt :/]")
		_t=arr[1]; arr[1]=arr[3]; arr[3]=_t # Switch day and year
	}
	# dd mon yyyy
	else if (dt ~ /^[0-9]{2}[- /][a-z]{3}[- /][0-9]{4}([- T][0-9]{2}[- :][0-9]{2}([- :][0-9]{2})?)?$/) {
		split(dt " 00:00:00",arr,"[- :/]")
		_t=arr[1]; arr[1]=arr[3]; arr[3]=_t # Switch day and year
		# lookup month
		switch (arr[2]) {
			case "jan": arr[2]=1; break
			case "feb": arr[2]=2; break
			case "mar": arr[2]=3; break
			case "apr": arr[2]=4; break
			case /ma[yj]/: arr[2]=5; break
			case "jun": arr[2]=6; break
			case "jul": arr[2]=7; break
			case "aug": arr[2]=8; break
			case "sep": arr[2]=9; break
			case /o[kc]t/: arr[2]=10; break
			case "nov": arr[2]=11; break
			case "dec": arr[2]=12; break
			default:
				return 0
		}
	}
	else {
		split("",arr,"")
	}
	return length(arr) >= 6
}

function date_arraytounixtime(arr,utc)
{
  return mktime(sprintf("%04d %02d %02d %02d %02d %02d", arr[1], arr[2], arr[3], arr[4], arr[5], arr[6]), utc?1:0)
}
