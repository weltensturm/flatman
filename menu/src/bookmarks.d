module menu.bookmarks;


import menu;



string[] readBookmarks(){
	auto path = "~/.config/flatman/bookmarks".expandTilde;
	if(!path.exists)
		std.file.write(path, "/\n~\n");
	string[] res;
	foreach(line; File(path).byLine)
		res ~= line.idup.expandTilde.buildNormalizedPath;
	return res;
}


