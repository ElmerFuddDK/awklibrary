# File : json.awk
# --------------------
#
# JSON utility functions
#
# Functions:
#
#  json_initparser(parser)
#  json_closeparser(parser)
#  json_parsefrominput(parser)
#  json_parsefromstring(parser,str)
#  json_parsefromfile(parser,file)
#  json_parsefromcommand(parser,cmd)
#  json_serialize(arr)
#  json_deserialize(data,arr)
#
# References:
#   JSON parser found here:
#   https://gist.github.com/calraith/5c85d17b28e96f49e067f9b054a6fdbb
#   Modified by prefixing function names
#   Modified by adding idxOrder to deserialize

function json_initparser(_p) {
	split("",_p,"")
	_p["OLDRS"]=RS
	_p["mode"]=""
	_p["skipdata"]=0
	
	_p["func.beginlevel"] = "" # Set this to a function name of @beginlevel(_p,level,mode) - will be called when entering an object or array
	_p["func.dataparsed"] = "" # Set this to a function name of dataparsed(_p,level,mode,key,data) - will be called when a data node is parsed
	_p["func.endlevel"]   = "" # Set this to a function name of @endlevel(_p,level,mode) - will be called when done parsing an object or array
}

function json_closeparser(_p) {
	if (_p["command"]) {
		close(_p["command"])
		_p["command"] = ""
	}
	RS=_p["OLDRS"]
}

function json_parsefrominput(_p) {
	_p["command"] = ""
	if ("data" in _p) { delete _p["data"] }
	if (!_p["skipdata"]) { _p["data"][0]; delete _p["data"][0]; split("",_p["data"],"") }
	json_parseinputinternal(_p,0,_p["data"])
}

function json_parsefromstring(_p, data) {
	gsub(/\\/,"\\\\",data)
	gsub(/"/,"\\\"",data)
	_p["command"] = sprintf("echo \"%s\"", data)
	if ("data" in _p) { delete _p["data"] }
	if (!_p["skipdata"]) { _p["data"][0]; delete _p["data"][0]; split("",_p["data"],"") }
	json_parseinputinternal(_p,0,_p["data"])
}

function json_parsefromfile(_p, file) {
	gsub(/\\/,"\\\\",file)
	gsub(/"/,"\\\"",file)
	_p["command"] = sprintf("cat \"%s\"", file)
	if ("data" in _p) { delete _p["data"] }
	if (!_p["skipdata"]) { _p["data"][0]; delete _p["data"][0]; split("",_p["data"],"") }
	json_parseinputinternal(_p,0,_p["data"])
}

function json_parsefromcommand(_p, cmd) {
	_p["command"] = cmd
	if ("data" in _p) { delete _p["data"] }
	if (!_p["skipdata"]) { _p["data"][0]; delete _p["data"][0]; split("",_p["data"],"") }
	json_parseinputinternal(_p,0,_p["data"])
}

function json_parseinputinternal(_p,level,arr,parentMode,   data,key,mode,oldRs,s,nullData,_func,_datafunc,_nextdata)
{
	if (_p["func.beginlevel"])
		_func=_p["func.beginlevel"]
	if (_p["func.dataparsed"])
		_datafunc=_p["func.dataparsed"]
	oldRs=RS
	switch (parentMode) {
		case "{":
			RS="[ \t\r\n]*[\"}]"; break
		case "[":
			RS="[ \t\r\n]*[{0-9tfn\"\\]]"; break
		default:
			RS="[ \t\r\n]*[\"{\\[]"; break
	}
	while (length(_nextdata) ||(_p["command"] ? (_p["command"] | getline data) : ((getline data) > 0))) {
		if (length(_nextdata)) { data = _nextdata; _nextdata="" }
		if (!mode) { # Scanning for start of data
			mode=substr(RT,length(RT),1)
			switch (mode) {
				case "\"":
					RS="(\\`|[^\\\\])((\\\\\\\\)*)?\"" # Find a " with an even number of \'s in front, no \'s or beginning of buffer
					break
				case /[0-9tfn]/:
					RS="[^0-9.ruefalsnu]" # Search for the rest of true/false/null or number
					break
				case "{":
				case "[":
					if (_func)
						@_func(_p,level,mode,key)
					if (level == 0) {
						json_parseinputinternal(_p,level+1,arr,mode)
					}
					else {
						if (isarray(arr)) {
							if (key in arr) { delete arr[key] }; arr[key][0]; delete arr[key][0]
							json_parseinputinternal(_p,level+1,arr[key],mode)
						}
						else {
							json_parseinputinternal(_p,level+1,arr,mode)
						}
						key=""
						RS="[ \t\r\n]*[," (parentMode == "{" ? "}" : "\\]" ) "]"
					}
					mode=""
					break
				case ",":
				case ":":
					RS="[ \t\r\n]*[0-9tfn\"[{]"
					mode=""
					break
			}
			if (mode == "]" || mode == "}")
				break
		}
		else
		{
			if (mode == "\"") {
				s=json_unquote(mode data RT)
			}
			else if (mode ~ /[0-9]/) {
				s=(mode data) + 0
				_nextdata=RT
			}
			else if (mode ~ /[tf]/) {
				s=mode data
				_nextdata=RT
			}
			else if (mode == "n") { # Assume null
				s=nullData
				_nextdata=RT
			}
			
			if (level == 0) {
				delete _p["data"]
				_p["data"] = s
				if (_datafunc)
					@_datafunc(_p,level,parentMode,"",s)
				break
			}
			else if (parentMode == "[") {
				if (isarray(arr)) arr[length(arr)+1] = s
				if (_datafunc)
					@_datafunc(_p,level,parentMode,"",s)
				RS="[ \t\r\n]*[,\\]]"
			}
			else if (parentMode == "{") {
				if (length(key)) {
					if (isarray(arr)) {
						if (key in arr) { delete arr[key] }
						arr[key] = s
					}
					if (_datafunc)
						@_datafunc(_p,level,parentMode,key,s)
					key=""
					RS="[ \t\r\n]*[,}]"
				}
				else {
					key = s
					RS="[ \t\r\n]*[:,}]"
				}
			}
			else {
				break
			}
			
			if (length(_nextdata) && !(_nextdata ~ RS)) {
				_nextdata = ""
			}
			
			mode=""
		}
	}
	if (level == 0) {
		RS=oldRs
		json_closeparser(_p)
	}
	else if (level && _p["func.endlevel"]) {
		_func=_p["func.endlevel"]
		@_func(_p,level,parentMode)
	}

}

function json_join(arr, sep, _p, i) {
	# syntax: join(array, string separator)
	# returns a string
	
	if (isarray(arr)) {
		for (i in arr) {
			_p["result"] = _p["result"] ~ "[[:print:]]" ? _p["result"] sep arr[i] : arr[i]
		}
	}
	return _p["result"]
}

function json_quote(str) {
	gsub(/\\/, "\\\\", str)
	gsub(/"/, "\\\"", str)
	gsub(/\r/, "\\r", str)
	gsub(/\n/, "\\n", str)
	gsub(/\t/, "\\t", str)
	return "\"" str "\""
}

function json_serialize(arr, indent_with, depth, _p, i, idx, val) {
	# syntax: serialize(array of arrays, indent string)
	# returns a JSON formatted string
	
	if (!isarray(arr)) {
		return json_quote(arr)
	}

	# sort arrays on key, ensures [...] values remain properly ordered
	if (!PROCINFO["sorted_in"]) PROCINFO["sorted_in"] = "@ind_num_asc"

	# determine whether array is indexed or associative
	for (i in arr) {
		_p["assoc"] = or(_p["assoc"], !(++_p["idx"] in arr))
	}

	# if associative, indent
	if (_p["assoc"]) {
		for (i = ++depth; i--;) {
			_p["end"] = _p["indent"]; _p["indent"] = _p["indent"] indent_with
		}
	}

	for (i in arr) {
		# If key length is 0, assume its an empty object
		if (!length(i)) return "{}"

		# quote key
		_p["key"] = json_quote(i)

		if (isarray(arr[i])) {
			if (_p["assoc"]) {
				_p["json"][++idx] = _p["indent"] _p["key"] ": " \
					json_serialize(arr[i], indent_with, depth)
			} else {
				# if indexed array, dont print keys
				_p["json"][++idx] = json_serialize(arr[i], indent_with, depth)
			}
		} else {
			# quote if not numeric, boolean, null, or too big for match()
			if (typeof(arr[i]) == "unassigned")
				val = "null"
			else if (!(typeof(arr[i]) == "number") &&
				(length(arr[i]) > 1000 || !(arr[i] ~ /^true$|^false$|^null$/)))
				val = json_quote(arr[i])
			else
				val = arr[i]

			_p["json"][++idx] = _p["assoc"] ? _p["indent"] _p["key"] ": " val : val
		}
	}

	# I trial and errored the hell out of this. Problem is, gawk can't distinguish between
	# a value of null and no value.  I think this hack is as close as I can get, although
	# [""] will become [].
	if (!_p["assoc"] && json_join(_p["json"]) == "\"\"") return "[]"

	# surround with curly braces if object, square brackets if array
	return _p["assoc"] ? "{\n" json_join(_p["json"], ",\n") "\n" _p["end"] "}" \
		: "[" json_join(_p["json"], ", ") "]"
}

function json_trim(str) { gsub(/^\s+|\s+$/, "", str); return str }

function json_unquote(str,  arr,c,i) {
	if (typeof(str) == "number")
		return str
	if (str == "null")
		return i
	gsub(/^'|'$/, "", str)
	gsub(/^"|"$/, "", str)
	
	c=split(str,arr,"\\\\\\\\")
	for (i=1;i<=c;i++)
	{
	  gsub(/\\r/, "\r", arr[i])
	  gsub(/\\n/, "\n", arr[i])
	  gsub(/\\t/, "\t", arr[i])
	  gsub(/\\"/, "\"", arr[i])
	  while (match(arr[i],/\\u00[0-9a-fA-F]{2}/))
	  {
	    arr[i] = substr(arr[i],1,RSTART-1) sprintf("%c", strtonum("0x" substr(arr[i],RSTART+2,RLENGTH))) substr(arr[i],RSTART+RLENGTH)
	  }
	  if (i>1) str = str "\\" arr[i]
	  else str = arr[i]
	}
	return json_trim(str)
}

function json_tokenize(str, arr, splitchar, _p, _testnum, _quot) {
	# syntax: tokenize(JSON-formatted string, array to populate, char to split on)
	# arr populates with matches split on unbracketed, unquoted splitchar
	# returns length of arr
	# This function supplants fpat / patsplit since those methods cannot reliably group
	# mated bracket pairs
	_testnum = 1; _quot = 0

	while (++_p["pos"] <= length(str)) {

		_p["char"] = substr(str, _p["pos"], 1)

		switch (_p["char"]) {
			case "[": if (!_p["\""] && !_p["\\"]) _p["["]++; _p["\\"] = false; _testnum = 0; break
			case "{": if (!_p["\""] && !_p["\\"]) _p["{"]++; _p["\\"] = false; _testnum = 0; break
			case "}": if (!_p["\""] && !_p["\\"]) _p["{"]--; _p["\\"] = false; break
			case "]": if (!_p["\""] && !_p["\\"]) _p["["]--; _p["\\"] = false; break
			case "\"": if (!_p["\\"]) _p["\""] = !_p["\""]; _p["\\"] = false; _quot = 1; break
			case "\\": _p["\\"] = !_p["\\"]; break
			default: _p["\\"] = false
		}

		if (_p["char"] == splitchar && !_p["["] && !_p["{"] && !_p["\""] && !_p["\\"]) {
			arr[++_p["idx"]] = json_trim(_p["segment"])
			if (!_quot && _testnum && length(arr[_p["idx"]]) && length(arr[_p["idx"]]) < 100 && arr[_p["idx"]]+0 == arr[_p["idx"]])
				arr[_p["idx"]] = arr[_p["idx"]]+0
			delete _p["segment"]
			_quot = 0
		} else {
			_p["segment"] = _p["segment"] _p["char"]
		}
	}
	arr[++_p["idx"]] = json_trim(_p["segment"])
	if (!_quot && _testnum && length(arr[_p["idx"]]) && length(arr[_p["idx"]]) < 100 && arr[_p["idx"]]+0 == arr[_p["idx"]])
		arr[_p["idx"]] = arr[_p["idx"]]+0
	return _p["idx"]
}

function json_deserialize(json,arr,idxOrder,  level, _keypath, _key , _p, _parts, _values, _keyval, i, j) {
	# syntax: deserialize (JSON-formatted string, array to populate)
	# Resulting array is true multidimensional (arr[idx][idx][etc...])
	# ... not concatenated index (arr[idx,idx,etc...])

	# consume outer brackets / braces
	# note: match() failed here with very large JSON data
	json = json_trim(json)
	_parts[1] = substr(json, 1, 1)
	_parts[2] = substr(json, 2, length(json) - 2)

	# split on unbracketed, unquoted commas
	_p["outie"] = json_tokenize(json_trim(_parts[2]), _values, ",")

	level = level + 1

	for (i = 1; i <= _p["outie"]; i++) {

		# build associative array
		if (_parts[1] ~ "{") {

			# split on unbracketed, unquoted colons
			_p["innie"] = json_tokenize(json_trim(_values[i]), _keyval, ":")

			for (j=1; j<=_p["innie"]; j+=2) {
                _key = json_unquote(_keyval[j])
				if (isarray(idxOrder)) {
					idxOrder[length(idxOrder)+1]["level"] = level
					idxOrder[length(idxOrder)]["key"] = _key ""
					idxOrder[length(idxOrder)]["path"] = _keypath
					idxOrder[length(idxOrder)]["isarray"] = 0
				}

				# if value begins with a bracket or brace, recurse
				if (json_trim(_keyval[j+1]) ~ /^[\[\{]/) {
					# init array element as explicit array (defaults to scalar without this)
					arr[_key][0]; delete arr[_key][0]
					if (isarray(idxOrder))
						idxOrder[length(idxOrder)]["isarray"] = 1

					# do recurse
					json_deserialize(_keyval[j+1], arr[_key], idxOrder, level, _keypath "|" _key)
				} else {
					arr[_key] = json_unquote(_keyval[j+1])
				}
			}

		# build numerically indexed array
		} else {

			while (++_p["idx"] in arr) {}
			if (isarray(idxOrder)) {
				idxOrder[length(idxOrder)+1]["level"] = level
				idxOrder[length(idxOrder)]["key"] = _p["idx"]+0
				idxOrder[length(idxOrder)]["path"] = _keypath
				idxOrder[length(idxOrder)]["isarray"] = 0
			}

			# if value begins with a bracket or brace, recurse
			if (json_trim(_values[i]) ~ /^[\[\{]/) {

				# init array element as explicit array (defaults to scalar without this)
				arr[_p["idx"]][0]; delete arr[_p["idx"]][0]
				if (isarray(idxOrder))
					idxOrder[length(idxOrder)]["isarray"] = 1

				# do recurse
				json_deserialize(json_trim(_values[i]), arr[_p["idx"]], idxOrder, level, _keypath "|" _p["idx"])
			} else {
				arr[_p["idx"]] = json_unquote(_values[i])
			}
		}
	}
}
