# File : xml.awk
# --------------------
#
# XML utility functions
#
# Functions:
#
#  xml_initparser(parser)
#  xml_closeparser(parser)
#  xml_parsefrominput(parser)
#  xml_parsedata(parser,data)
#  xml_parseattributes(attributestr,arr)
#
# Value escaping:
# 
#  escape_toxml(val)
#  escape_fromxml(val)

function xml_initparser(_p) {
	split("",_p,"")
	_p["OLDRS"]=RS

	_p["path"]="/"
	_p["parsevalue"]=0
	_p["value"]=""
	
	if ("parents" in _p)    {delete _p["parents"]   }; _p["parents"][0];    delete _p["parents"][0]
	if ("attributes" in _p) {delete _p["attributes"]}; _p["attributes"][0]; delete _p["attributes"][0]
	_p["parentcount"]=0
	_p["xmlissinglenode"]=0

	_p["func.begindoc"] = "" # Set this to a function name of @begindoc(_p)
	_p["func.enddoc"] = "" # Set this to a function name of @enddoc(_p)
	_p["func.nodestart"] = "" # Set this to a function name of @nodestart(_p)
	_p["func.nodeend"] = "" # Set this to a function name of @nodeend(_p)
}

function xml_closeparser(_p) {
	RS=_p["OLDRS"]
}

function xml_parsefrominput(_p,  data) {
	RS="<"
	while ((getline data)>0) {
		xml_parsedata(_p,data)
	}
}

function xml_parsedata(_p,data,  _func,nodename) {
	if (_p["func.begindoc"]) {
		_func=_p["func.begindoc"]; @_func(_p)
		_p["func.begindoc"]=""
	}
	
	if (RS == "<") {
		if (_p["parsevalue"])
		_p["value"]=escape_fromxml(data)
		RS=">"
		return
	}

	if (RS == ">") { RS = "<" }

	# Ignore comments
	if (data ~ /^\?/) { _p["value"]=""; _p["parsevalue"]=0; return }

	# Is this an end node?
	if (data ~ /^\//) {
		if (_p["func.nodeend"]) {
			_func=_p["func.nodeend"]; @_func(_p)
		}
		if (_p["parsevalue"]) {
			_p["value"]=""
			_p["parsevalue"]=0
		}
		_p["path"]=substr(_p["path"],1,length(_p["path"])-length(_p["parents"][_p["parentcount"]])-1)
		delete _p["parents"][_p["parentcount"]]
		delete _p["attributes"][_p["parentcount"]]
		_p["parentcount"]--
		if (_p["parentcount"] == 0 && _p["func.enddoc"]) {
			_func=_p["func.enddoc"]; @_func(_p)
		}
	}

	# Is this a start node?
	if (!(data ~ /^\//)) {
		if (data ~ /\/$/) {
			_p["xmlissinglenode"]=1
			sub(/[ \t]*\/$/,"",data)
		}
		match(data,/^([\t\r\n ]*)([^\t\r\n ]+)/,nodename)
		_p["parsevalue"]=1
		_p["path"]=_p["path"] "/" nodename[2]
		_p["parentcount"]++
		_p["parents"][_p["parentcount"]] = nodename[2]
		_p["attributes"][_p["parentcount"]][0]; delete _p["attributes"][_p["parentcount"]][0]
		xml_parseattributes(substr(data,length(nodename[2])+2),_p["attributes"][_p["parentcount"]])
		if (_p["func.nodestart"]) {
			_func=_p["func.nodestart"]; @_func(_p)
		}
		if (_p["xmlissinglenode"]) {
			if (_p["func.nodeend"]) {
				_func=_p["func.nodeend"]; @_func(_p)
			}
			if (_p["parsevalue"]) {
				_p["value"]=""
				_p["parsevalue"]=0
			}
			_p["path"]=substr(_p["path"],1,length(_p["path"])-length(_p["parents"][_p["parentcount"]])-1)
			delete _p["parents"][_p["parentcount"]]
			delete _p["attributes"][_p["parentcount"]]
			_p["parentcount"]--
			if (_p["parentcount"] == 0 && _p["func.enddoc"]) {
				_func=_p["func.enddoc"]; @_func(_p)
			}
		}
		_p["xmlissinglenode"]=0
	}
}

function xml_parseattributes(data,attrArr,   arr,c,i) {
	gsub(/^[ \t\r\n]+|[ \t\r\n]+$/,"",data)
	c=split(data,arr,"\"")
	for (i=1; i<c; i+=2) {
		gsub(/^[ ]+|=$/,"",arr[i])
		if (arr[i])
			attrArr[arr[i]] = escape_fromxml(arr[i+1])
	}
}

function escape_toxml(val) {
	gsub(/&/,"\\&amp;",val)
	gsub(/</,"\\&lt;",val)
	gsub(/>/,"\\&gt;",val)
	gsub(/\t/,"\\&#x9;",val)
	gsub(/\r\n|\n/,"\\&#xA;",val)
	gsub(/\r/,"\\&#xA;",val)
	gsub(/"/,"\\&quot;",val)
	gsub(/'/,"\\&apos;",val)
	return val
}

function escape_fromxml(val) {
	gsub(/&amp;/,"\\&",val)
	gsub(/&lt;/,"<",val)
	gsub(/&gt;/,">",val)
	gsub(/&apos;/,"'",val)
	gsub(/&quot;/,"\"",val)
	gsub(/&#xA;/,"\n",val)
	gsub(/&#x9;/,"\t",val)
	return val
}


