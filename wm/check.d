module ws.check;

void check(alias T)(){
	if(!T)
		throw new Exception(T.stringof ~ " failed");
}

