# File : util.awk
# --------------------
#
# Base utility functions
#
# Functions:
#
#  Validation:
#    isnum(x)          Returns true if x is a number
#    isxmldatetime(dt) Returns true if dt is an xml datetime (YYYY-MM-DDTHH:MM:SS)
#
#  String functions:
#    trim(str)
#    compact(str)
#
#  Array functions:
#    array_init(arr)
#      Initializes arr as an empty array
#    array_subinit(arr,idx)
#      Initializes and index in arr as an empty array
#    array_flatten(arrIn,arrOut)
#      Copies all values in the arrIn structure into arrOut
#    array_copy(arrIn,arrOut)
#      Copies arrIn into arrOut
#
#  Value escaping:
#    escape_tosh(str)
#      Escapes a value as a parameter for shell commands - eg system("echo " escape_tosh(value))
#    escape_toregex(str)
#      Escapes a value for use as a regex - eg "\\^-^/" ~ escape_toregex("^-^")
#      Ensures user input can be used with special regex chars

function isnum(x){return(x==x+0)}
function isxmldatetime(dt){return (dt ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{3})?$/)}

function trim(str) {
	gsub(/^[ \t\r\n]+|[ \t\r\n]+$/,"",str)
	return str
}

function compact(str) {
	gsub(/[ \t\r\n]+/," ",str)
	return str
}


function array_init(arr){
	split("",arr,"")
}

function array_subinit(arr,idx) {
	if (idx in arr)
		delete arr[idx]
	arr[idx][0]; delete arr[idx][0]
}

function array_flatten(arrIn,arrOut) {
  array_init(arrOut)
	if (!isarray(arrIn))
		arrOut[length(arrOut)+1] = arrIn
	else
		_array_flatten_recursive(arrIn,arrOut)
}
function _array_flatten_recursive(arrIn,arrOut,  _k) {
	if (isarray(arrIn)) {
		for (_k in arrIn) {
			if (isarray(arrIn[_k]))
				_array_flatten_recursive(arrIn[_k],arrOut)
			else
				arrOut[length(arrOut)+1] = arrIn[_k]
		}
	}
}

function array_copy(arrSrc,arrTarget,  i)
{
	delete arrTarget
	for (i in arrSrc) {
		if (isarray(arrSrc[i])) {
			arrTarget[i][1]
			array_copy(arrSrc[i],arrTarget[i])
		}
		else {
			arrTarget[i] = arrSrc[i]
		}
	}
}

function escape_tosh(str) {
	gsub(/\\/,"\\\\",str)
	gsub(/"/,"\\\"",str)
	return "\"" str "\""
}

function escape_toregex(str) {
	gsub(/[-[\]{}()*+?.,\\^$|#]/,"\\\\&",str)
	return str
}
