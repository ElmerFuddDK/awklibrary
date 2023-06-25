# File : sql.awk
# --------------------
#
# SQL utility functions
#
# Functions:
#
#  Value escaping:
#    escape_tosql(str,<maxlen>,<allowblank>,<notrim>)
#    escape_tosqlnewline(str,<maxlen>,<allowblank>,<notrim>)
#    escape_tosqlnum(str,<maxlen>,<allowblank>)
#      returns string escaped as SQL value, including ' if it is a string
#      if maxlen set, then trims to this len
#      if allowblank is set then empty str is '', not null
#      unless notrim is set then the string is trimmed

function escape_tosql(str,maxlen,allowblank,notrim) {
	if (!notrim)
		gsub(/^[ \t]+|[ \t]+$/,"",str)
	if (str == "" || str == "NULL")
		return (allowblank == 1 ? "''" : "NULL");
	gsub(/[\r]*\n|\r/," ",str)
	if (maxlen > 0)
		str = substr(str,1,maxlen)
	gsub(/'/,"''",str)
	return "'" str "'"
}

function escape_tosqlnewline(str,maxlen,allowblank) {
	if (!notrim)
		gsub(/^[ \t]+|[ \t]+$/,"",str)
	if (str == "" || str == "NULL")
		return (allowblank == 1 ? "''" : "NULL");
	gsub(/[\r]*\n|\r/,"\r\n",str)
	if (maxlen > 0)
		str = substr(str,1,maxlen)
	gsub(/'/,"''",str)
	return "'" str "'"
}

function escape_tosqlnum(num,maxlen,allowblank) {
	gsub(/,/,".",num)
	return escape_tosql(num,maxlen,allowblank)
}

function escape_sqlcolname(idx, name, baseName, i) {
	gsub(/[-\n]/,"_",name)
	gsub(/[^a-zA-Z0-9_]/,"",name)
	if (name ~ /^[0-9]/)
		name = "_" name
	if (length(name) == 0)
		name=sprintf("Col%d",idx)

	if (length(name) > 120)
		name=substr(name,1,120)

	baseName=name
	i=1
	while (name in sql_headerNamesInUse) {
		name=sprintf("%s_%d", baseName, i++)
	}
	sql_headerNamesInUse[name] = 1

	return name
}
