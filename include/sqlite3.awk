# File : sqlite3.awk
# --------------------
#
# SQLite3 utility functions
# This file requires including utils.awk, xml.awk and sql.awk
#
#  Functions:
#
#  Initialization:
#    sqlite3_init(dbfile)
#      Sets up the sqlite3_cmd parameter for operating on the dbfile
#      Must be called prior to the others
#
#  Executing a statement:
#    sqlite3_exec(sqlstring,<result>,<params>)
#    sqlite3_execfile(sqlfile,<result>,<params>)
#      Executes SQL from string or file on the initialized db.
#      If result is an array it will contain the result as 2dim array: result[rownum][paramname] = value
#      If params is an array then it is expected to contain parameters for the SQL in the format @paramname:
#        select * from tbl where col = @1 -- First value of a list in params: split("parmValue",params,",")
#        select * from tbl where col = @colName -- First value of a key in params: params["colName"] = parmValue

function sqlite3_init(dbfile) {
	if (!sqlite3_nullvalue) {
		sqlite3_nullvalue = "NULLVALUE"
	}
	if (!sqlite3_path) {
		sqlite3_path = "sqlite3"
	}
	sqlite3_cmd = escape_tosh(sqlite3_path) " -bail -batch -html -header -nullvalue " escape_tosh(nullvalue) " " escape_tosh(dbfile)
}

function sqlite3_exec(sqlstring,result,params,   oldRs,oldFs,oldORs,row,var,i,sqlarr) {

	if (isarray(result))
		array_init(result)

	# If not initialized, return
	if (!sqlite3_cmd)
		return

	oldRs=RS
	oldFs=FS
	oldORs=ORS

	split(sqlstring,sqlarr,"@")
	row=1
	while (row <= length(sqlarr)) {
		if (row==1) {
			print sqlarr[row] |& sqlite3_cmd
		} else {
			i=match(sqlarr[row], /[^A-Za-z0-9_]/) # find the first char that is not alphanumeric
			if (i==0) { i=length(sqlarr[row]) }
			var = substr(sqlarr[row],1,i-1)
			if (isarray(params) && var in params) {
				var = escape_tosql(params[var])
			} else {
				var = "NULL"
			}

			print var substr(sqlarr[row],i) |& sqlite3_cmd
		}
		row++
	}

	sqlite3_parseresult(result)

	RS=oldRs
	FS=oldFs
	ORS=oldORs

	if (isarray(result))
		return length(result)
}

function sqlite3_execfile(sqlfile,result,params,   oldRs,oldFs,oldORs,nextIsVar,var,i) {

	if (isarray(result))
		array_init(result)

	# If not initialized, return
	if (!sqlite3_cmd)
		return

	oldRs=RS
	oldFs=FS
	oldORs=ORS

	RS="@"
	FS="@"
	ORS=""
	nextIsVar=0
	while ((getline < sqlfile) > 0) {
		if (nextIsVar == 0) {
			print |& sqlite3_cmd
			nextIsVar = 1
		} else {
			i=match($0, /[^A-Z|a-z|_]/) # find the first char that is not alphanumeric
			if (i==0) { i=length($0) }
			var = substr($0,1,i-1)
			if (isarray(params) && var in params) {
				var = escape_tosql(params[var])
			} else {
				var = "NULL"
			}

			print var substr($0,i) |& sqlite3_cmd
		}
	}
	close(sqlfile)

	sqlite3_parseresult(result)

	RS=oldRs
	FS=oldFs
	ORS=oldORs

	if (isarray(result))
		return length(result)
}

function sqlite3_parseresult(result,   oldRs,oldFs,oldORs,header,len,level,hasData,i,unassigned) {

	oldRs=RS
	oldFs=FS
	oldORs=ORS

	# If not initialized, return
	if (!sqlite3_cmd)
		return

	# Close the statement
	print ";" |& sqlite3_cmd
	close(sqlite3_cmd, "to")

	#while ((sqlite3_cmd |& getline) > 0) { print }; close(sqlite3_cmd); return

	# Parse the output
	RS=">"
	FS="<"
	ORS="\n"

	level=0
	len=0
	hasData=0

	while ((sqlite3_cmd |& getline) > 0) {
		if (substr($2,1,1) == "/") {
			level--
		} else {
			level++
		}

		gsub(/\n/,"",$1)

		if ($2 == "/TH") {
			if (hasData == 0) {
				hasData=1
			}
			if (!len) delete header
			header[++len] = escape_fromxml($1)
		}
		else if ($2 == "/TD") {
			if (isarray(result)) {
				if (len == 0)
					array_subinit(result,length(result)+1)
				if ($1 != nullvalue)
					result[length(result)][header[++len]] = escape_fromxml($1)
				else
					result[length(result)][header[++len]] = unassigned
			}
		}
		else if ($2 == "/TR") {
			len=0
		}
	}
	close(sqlite3_cmd)

	RS=oldRs
	FS=oldFs
	ORS=oldORs
}
